import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../local_db/isar_service.dart';
import '../local_db/enums/local_enums.dart';
import '../local_db/collections/invoice_local.dart';


import '../local_db/collections/shift_local.dart';
import '../local_db/collections/sync_queue_item.dart';
import '../local_db/collections/sync_metadata.dart';
import 'app_session.dart';

/// Manages the offline sync queue — enqueues operations while offline
/// and replays them against Supabase RPCs when connectivity returns.
class SyncEngine {
  SyncEngine._internal();
  static final SyncEngine instance = SyncEngine._internal();

  final _client = Supabase.instance.client;
  bool _isSyncing = false;

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
          .sortByCreatedAt()
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

  /// Creates a SyncQueueItem and increments pendingCount.
  Future<void> enqueue(
    SyncOperationType op,
    Map<String, dynamic> payload,
  ) async {
    final isar = await IsarService.getInstance();

    final item = SyncQueueItem()
      ..operationType = op.toSupabaseString()
      ..payloadJson = jsonEncode(payload)
      ..status = 'pending'
      ..retryCount = 0
      ..createdAt = DateTime.now();

    await isar.writeTxn(() async {
      await isar.syncQueueItems.put(item);
    });

    await _incrementPendingCount(isar, 1);
    AppSession.pendingSync = await getPendingCount();

    debugPrint('📥 SyncEngine: Enqueued ${op.toSupabaseString()}');
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

    debugPrint('  ▸ Processing: ${item.operationType} (retry ${item.retryCount})');

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
        case SyncOperationType.openShift:
          result = await _rpcOpenShift(payload);
          break;
        case SyncOperationType.closeShift:
          result = await _rpcCloseShift(payload);
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
      }

      // ── Success ──
      await isar.writeTxn(() async {
        item.status = 'synced';
        item.lastAttemptAt = DateTime.now();
        await isar.syncQueueItems.put(item);
      });

      // Update supabaseId on matching local record if returned
      if (result != null && result.containsKey('id')) {
        await _updateLocalSupabaseId(
          isar, opType, payload, result['id'] as String,
        );
      }

      debugPrint('    ✓ Synced successfully');
    } catch (e) {
      // ── Failure ──
      item.retryCount += 1;
      item.errorMessage = e.toString();
      item.lastAttemptAt = DateTime.now();

      if (item.retryCount >= 3) {
        item.status = 'failed';
        debugPrint('    ✗ FAILED permanently after ${item.retryCount} retries: $e');
      } else {
        item.status = 'pending';
        debugPrint('    ⟳ Will retry (attempt ${item.retryCount}/3): $e');
      }

      await isar.writeTxn(() async {
        await isar.syncQueueItems.put(item);
      });
    }
  }

  // ══════════════════════════════════════════
  // PRIVATE — RPC Calls
  // ══════════════════════════════════════════

  Future<Map<String, dynamic>?> _rpcProcessSale(
      Map<String, dynamic> p) async {
    final res = await _client.rpc('process_sale', params: p);
    if (res is Map) return Map<String, dynamic>.from(res);
    return null;
  }

  Future<Map<String, dynamic>?> _insertPayment(
      Map<String, dynamic> p) async {
    final res = await _client.from('payments').insert(p).select().single();
    return Map<String, dynamic>.from(res);
  }

  Future<Map<String, dynamic>?> _insertTransaction(
      Map<String, dynamic> p) async {
    final res =
        await _client.from('transactions').insert(p).select().single();
    return Map<String, dynamic>.from(res);
  }

  Future<Map<String, dynamic>?> _rpcOpenShift(
      Map<String, dynamic> p) async {
    final res = await _client.rpc('open_shift', params: p);
    // open_shift returns a UUID string directly
    if (res is String) return {'id': res};
    return null;
  }

  Future<Map<String, dynamic>?> _rpcCloseShift(
      Map<String, dynamic> p) async {
    final res = await _client.rpc('close_shift', params: p);
    if (res is Map) return Map<String, dynamic>.from(res);
    return null;
  }

  Future<Map<String, dynamic>?> _rpcProcessRefund(
      Map<String, dynamic> p) async {
    final res = await _client.rpc('process_refund', params: p);
    // process_refund returns a UUID string directly
    if (res is String) return {'id': res};
    return null;
  }

  Future<Map<String, dynamic>?> _rpcAddExpense(
      Map<String, dynamic> p) async {
    final res = await _client.rpc('add_expense', params: p);
    // add_expense returns a UUID string directly
    if (res is String) return {'id': res};
    return null;
  }

  Future<Map<String, dynamic>?> _rpcAddDebtRecoveryPayment(
      Map<String, dynamic> p) async {
    await _client.rpc('add_debt_recovery_payment', params: p);
    // add_debt_recovery_payment returns void
    return null;
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

        case SyncOperationType.openShift:
          // Find the local shift that is still unsynced + open
          final shift = await isar.shiftLocals
              .filter()
              .syncedEqualTo(false)
              .statusEqualTo('open')
              .findFirst();
          if (shift != null) {
            await isar.writeTxn(() async {
              shift.supabaseId = supabaseId;
              shift.synced = true;
              await isar.shiftLocals.put(shift);
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
}
