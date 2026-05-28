import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../local_db/isar_service.dart';
import '../local_db/enums/local_enums.dart';
import '../local_db/collections/invoice_local.dart';
import '../local_db/collections/expense_category_local.dart';
import '../local_db/collections/sync_queue_item.dart';
import '../local_db/collections/sync_metadata.dart';
import 'app_session.dart';

/// Manages the offline sync queue — enqueues operations while offline
/// and replays them against Supabase RPCs when connectivity returns.
class SyncEngine {
  SyncEngine._internal() {
    _startRetryTimer();
  }
  static final SyncEngine instance = SyncEngine._internal();

  final _client = Supabase.instance.client;
  bool _isSyncing = false;

  // ── FIX 2: Periodic retry timer ──
  Timer? _retryTimer;

  // ── FIX 3: Sync-complete event stream ──
  final _syncCompleteController = StreamController<void>.broadcast();
  /// Emits after each successful item sync. UI can listen to auto-refresh.
  Stream<void> get onSyncComplete => _syncCompleteController.stream;

  // ══════════════════════════════════════════
  // PUBLIC — Sync pending queue
  // ══════════════════════════════════════════

  /// Processes all pending items in createdAt ASC order.
  /// Skips if already syncing. Safe to call multiple times.
  Future<void> syncPending() async {
    if (_isSyncing) {
      debugPrint('⏳ SyncEngine: Already syncing, skipping');
      return;
    }
    _isSyncing = true;
    debugPrint('🔄 SyncEngine: Starting sync...');

    try {
      final isar = await IsarService.getInstance();
      final pending = await isar.syncQueueItems
          .filter()
          .statusEqualTo('pending')
          .sortByPriority()
          .thenByCreatedAt()
          .findAll();

      if (pending.isEmpty) {
        debugPrint('✅ SyncEngine: Nothing to sync');
        return;
      }

      debugPrint('📋 SyncEngine: ${pending.length} pending items');

      for (final item in pending) {
        await _processItem(isar, item);
      }

      await _refreshPendingCount(isar);
      debugPrint('✅ SyncEngine: Sync pass complete');
    } catch (e) {
      debugPrint('❌ SyncEngine: Sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // ══════════════════════════════════════════
  // PUBLIC — Enqueue a new offline operation
  // ══════════════════════════════════════════

  SyncQueueItem _buildItem(SyncOperationType op, Map<String, dynamic> payload) {
    return SyncQueueItem()
      ..operationType = op.toSupabaseString()
      ..payloadJson = jsonEncode(payload)
      ..status = 'pending'
      ..idempotencyKey =
          '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}'
      ..priority = _priorityForOp(op)
      ..retryCount = 0
      ..createdAt = DateTime.now();
  }

  /// Creates a SyncQueueItem and inserts it within a caller-owned Isar writeTxn.
  /// The caller is responsible for calling [enqueuePendingCount] after the
  /// transaction commits to keep the metadata counter in sync.
  Future<SyncQueueItem> enqueueInTransaction(
    Isar isar,
    SyncOperationType op,
    Map<String, dynamic> payload,
  ) async {
    final item = _buildItem(op, payload);
    await isar.syncQueueItems.put(item);
    debugPrint('📥 SyncEngine: Enqueued ${op.toSupabaseString()} in txn');
    return item;
  }

  /// Standalone convenience — full separate transaction for callers that
  /// do not have an ongoing writeTxn.
  Future<void> enqueue(
    SyncOperationType op,
    Map<String, dynamic> payload,
  ) async {
    final isar = await IsarService.getInstance();
    await isar.writeTxn(() async {
      await enqueueInTransaction(isar, op, payload);
    });
    await _incrementPendingCount(isar, 1);
    AppSession.pendingSync = await getPendingCount();
  }

  // ══════════════════════════════════════════
  // PUBLIC — Pending count
  // ══════════════════════════════════════════

  /// Returns current pending count from Isar.
  Future<int> getPendingCount() async {
    final isar = await IsarService.getInstance();
    return isar.syncQueueItems
        .filter()
        .statusEqualTo('pending')
        .count();
  }

  /// Watches the SyncMetadata.pendingCount field for live UI updates.
  Stream<int> get pendingCountStream {
    return Stream.periodic(const Duration(seconds: 5)).asyncMap((_) async {
      return getPendingCount();
    });
  }

  // ══════════════════════════════════════════
  // PRIVATE — Process a single queue item
  // ══════════════════════════════════════════

  Future<void> _processItem(Isar isar, SyncQueueItem item) async {
    final opType = SyncOperationTypeExt.fromString(item.operationType);
    final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;

    debugPrint('  ▸ Processing: ${item.operationType} '
        '(retry ${item.retryCount}, key=${item.idempotencyKey})');

    // ── Conflict detection — check if references are stale ──
    try {
      final conflict = await _detectConflict(isar, opType, payload);
      if (conflict != null) {
        debugPrint('    ⚠ CONFLICT: ${conflict['reason']}');
        await isar.writeTxn(() async {
          item.status = 'conflict';
          item.errorMessage = conflict['reason'] as String?;
          item.lastAttemptAt = DateTime.now();
          await isar.syncQueueItems.put(item);
        });
        return;
      }
    } catch (e) {
      debugPrint('    ⚠ Conflict check error: $e (proceeding)');
    }

    try {
      Map<String, dynamic>? result;

      switch (opType) {
        case SyncOperationType.createInvoice:
          result = await _rpcProcessSale(payload);
          break;
        case SyncOperationType.createPayment:
          result = await _insertPayment(payload);
          break;
        case SyncOperationType.createTransaction:
          result = await _insertTransaction(payload);
          break;
        case SyncOperationType.processRefund:
          result = await _rpcProcessRefund(payload);
          break;
        case SyncOperationType.createExpense:
          result = await _rpcAddExpense(payload);
          break;
        case SyncOperationType.createDebtRecoveryPayment:
          result = await _rpcAddDebtRecoveryPayment(payload);
          break;
        case SyncOperationType.createLogDiscount:
          result = await _insertActivityLog(payload);
          break;
        case SyncOperationType.createPurchase:
          result = await _rpcProcessPurchase(payload);
          break;
      }

      // ── Success ──
      // Update supabaseId on matching local record before marking synced
      if (result != null && result.containsKey('id')) {
        await _updateLocalSupabaseId(
          isar, opType, payload, result['id'] as String,
        );
      }

      await isar.writeTxn(() async {
        item.status = 'synced';
        item.lastAttemptAt = DateTime.now();
        await isar.syncQueueItems.put(item);
      });

      // FIX 3: Notify listeners (e.g. POS today-sales tab)
      _syncCompleteController.add(null);

      debugPrint('    ✓ Synced successfully');
    } catch (e) {
      final errorStr = e.toString();

      // ── Detect idempotency (already processed) ──
      if (errorStr.contains('already been processed') ||
          errorStr.contains('duplicate key') ||
          errorStr.contains('unique constraint') ||
          errorStr.contains('23505')) {
        debugPrint('    ✓ Already processed (idempotent), marking synced');
        await isar.writeTxn(() async {
          item.status = 'synced';
          item.lastAttemptAt = DateTime.now();
          await isar.syncQueueItems.put(item);
        });
        _syncCompleteController.add(null);
        return;
      }

      // ── Failure ──
      item.retryCount += 1;
      item.errorMessage = errorStr;
      item.lastAttemptAt = DateTime.now();

      if (item.retryCount >= _maxRetries) {
        item.status = 'failed';
        debugPrint('    ✗ FAILED permanently after ${item.retryCount} retries: $errorStr');
      } else {
        item.status = 'pending';
        debugPrint('    ⟳ Will retry (attempt ${item.retryCount}/$_maxRetries): $errorStr');
      }

      await isar.writeTxn(() async {
        await isar.syncQueueItems.put(item);
      });
    }
  }

  /// Checks if the local record being pushed is stale compared to the server.
  /// Returns a conflict reason map if conflict detected, null otherwise.
  Future<Map<String, dynamic>?> _detectConflict(
    Isar isar,
    SyncOperationType opType,
    Map<String, dynamic> payload,
  ) async {
    switch (opType) {
      case SyncOperationType.createExpense: {
        final categoryId = payload['p_category_id'] as String?;
        final localInvoiceNumber = payload['p_invoice_number'] as String?;
        if (categoryId == null) return null;
        final serverCategory = await _client
            .from('expense_categories')
            .select('id, updated_at')
            .eq('id', categoryId)
            .maybeSingle();
        if (serverCategory == null) {
          return {'reason': 'Referenced expense category ($categoryId) no longer exists on server'};
        }
        final localCat = await isar.expenseCategoryLocals
            .filter()
            .supabaseIdEqualTo(categoryId)
            .findFirst();
        if (localCat?.updatedAt != null && serverCategory['updated_at'] != null) {
          final serverUpdated = DateTime.tryParse(serverCategory['updated_at'].toString());
          if (serverUpdated != null && localCat!.updatedAt != null &&
              serverUpdated.isAfter(localCat.updatedAt!)) {
            return {'reason': 'Expense category has been updated on server since local sync'};
          }
        }
        return null;
      }

      case SyncOperationType.createTransaction: {
        final invoiceId = payload['invoice_id'] as String?;
        if (invoiceId == null || invoiceId.isEmpty) return null;
        final serverInvoice = await _client
            .from('invoices')
            .select('id, status')
            .eq('id', invoiceId)
            .maybeSingle();
        if (serverInvoice == null) {
          return {'reason': 'Referenced invoice ($invoiceId) no longer exists on server'};
        }
        final status = serverInvoice['status'] as String?;
        if (status == 'refunded') {
          return {'reason': 'Invoice $invoiceId is refunded, cannot add transactions'};
        }
        return null;
      }

      default:
        return null;
    }
  }

  // ══════════════════════════════════════════
  // PRIVATE — Priority helper
  // ══════════════════════════════════════════

  int _priorityForOp(SyncOperationType op) {
    switch (op) {
      case SyncOperationType.createInvoice:
      case SyncOperationType.createPayment:
        return 1;
      case SyncOperationType.processRefund:
      case SyncOperationType.createTransaction:
        return 2;
      case SyncOperationType.createExpense:
      case SyncOperationType.createDebtRecoveryPayment:
      case SyncOperationType.createLogDiscount:
      case SyncOperationType.createPurchase:
        return 3;
    }
  }

  // ══════════════════════════════════════════
  // PRIVATE — RPC Calls
  // ══════════════════════════════════════════

  static const _timeout = Duration(seconds: 30);

  Future<Map<String, dynamic>?> _rpcProcessSale(
      Map<String, dynamic> p) async {
    final res = await _client.rpc('process_sale', params: p)
        .timeout(_timeout);
    if (res is Map) return Map<String, dynamic>.from(res);
    return null;
  }

  Future<Map<String, dynamic>?> _insertPayment(
      Map<String, dynamic> p) async {
    final res = await _client.from('payments').insert(p).select().single()
        .timeout(_timeout);
    return Map<String, dynamic>.from(res);
  }

  Future<Map<String, dynamic>?> _insertTransaction(
      Map<String, dynamic> p) async {
    final res = await _client.from('transactions').insert(p).select().single()
        .timeout(_timeout);
    return Map<String, dynamic>.from(res);
  }

  Future<Map<String, dynamic>?> _rpcProcessRefund(
      Map<String, dynamic> p) async {
    final res = await _client.rpc('process_refund', params: p)
        .timeout(_timeout);
    if (res is Map) return Map<String, dynamic>.from(res);
    return null;
  }

  Future<Map<String, dynamic>?> _rpcAddExpense(
      Map<String, dynamic> p) async {
    final res = await _client.rpc('add_expense', params: p)
        .timeout(_timeout);
    if (res is String) return {'id': res};
    return null;
  }

  Future<Map<String, dynamic>?> _rpcAddDebtRecoveryPayment(
      Map<String, dynamic> p) async {
    await _client.rpc('add_debt_recovery_payment', params: p)
        .timeout(_timeout);
    return null;
  }

  Future<Map<String, dynamic>?> _rpcProcessPurchase(
      Map<String, dynamic> p) async {
    final res = await _client.rpc('process_purchase', params: p)
        .timeout(_timeout);
    if (res is Map) return Map<String, dynamic>.from(res);
    return null;
  }

  Future<Map<String, dynamic>?> _insertActivityLog(
      Map<String, dynamic> p) async {
    final res = await _client.from('activity_logs').insert(p).select().single()
        .timeout(_timeout);
    return Map<String, dynamic>.from(res);
  }

  // ══════════════════════════════════════════
  // PRIVATE — Update local supabaseId after sync
  // ══════════════════════════════════════════

  Future<void> _updateLocalSupabaseId(
    Isar isar,
    SyncOperationType opType,
    Map<String, dynamic> payload,
    String supabaseId,
  ) async {
    try {
      switch (opType) {
        case SyncOperationType.createInvoice:
          // Find the local invoice by its temporary invoiceNumber
          final localInvoiceNumber = payload['p_invoice_number'] as String?;
          if (localInvoiceNumber == null) return;
          final invoice = await isar.invoiceLocals
              .filter()
              .invoiceNumberEqualTo(localInvoiceNumber)
              .findFirst();
          if (invoice != null) {
            await isar.writeTxn(() async {
              invoice.supabaseId = supabaseId;
              invoice.synced = true;
              await isar.invoiceLocals.put(invoice);
            });
          }
          break;

        case SyncOperationType.processRefund:
          // The returned ID is the transaction id, not invoice
          break;

        default:
          break;
      }
    } catch (e) {
      debugPrint('    ⚠ Could not update local supabaseId: $e');
    }
  }

  // ══════════════════════════════════════════
  // PRIVATE — Pending count management
  // ══════════════════════════════════════════

  Future<void> _incrementPendingCount(Isar isar, int delta) async {
    await isar.writeTxn(() async {
      var meta = await isar.syncMetadatas.get(1);
      if (meta == null) {
        meta = SyncMetadata()..pendingCount = delta;
      } else {
        meta.pendingCount += delta;
      }
      await isar.syncMetadatas.put(meta);
    });
  }

  Future<void> _refreshPendingCount(Isar isar) async {
    final count = await isar.syncQueueItems
        .filter()
        .statusEqualTo('pending')
        .count();

    await isar.writeTxn(() async {
      var meta = await isar.syncMetadatas.get(1);
      if (meta == null) {
        meta = SyncMetadata()..pendingCount = count;
      } else {
        meta.pendingCount = count;
      }
      await isar.syncMetadatas.put(meta);
    });

    AppSession.pendingSync = count;
  }

  // ══════════════════════════════════════════
  // FIX 2 — Exponential backoff retry timer
  // ══════════════════════════════════════════

  static const _maxRetries = 5;

  void _startRetryTimer() {
    _retryTimer?.cancel();
    _scheduleRetry(0);
  }

  void _scheduleRetry(int attempt) {
    if (attempt >= _maxRetries) {
      debugPrint('⏰ SyncEngine: Max retries ($_maxRetries) reached — giving up');
      return;
    }
    final delay = Duration(seconds: 30 * (1 << attempt)); // 30, 60, 120, 240, 480
    debugPrint('⏰ SyncEngine: Next retry in ${delay.inSeconds}s (attempt ${attempt + 1}/$_maxRetries)');
    _retryTimer = Timer(delay, () async {
      final count = await getPendingCount();
      if (count > 0) {
        debugPrint('⏰ SyncEngine: Retry timer fired — $count pending items');
        await syncPending();
        _scheduleRetry(attempt + 1);
      } else {
        _scheduleRetry(0);
      }
    });
  }

  /// Call when the engine is no longer needed (app shutdown).
  void dispose() {
    _retryTimer?.cancel();
    _syncCompleteController.close();
  }
}
