import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:isar/isar.dart';
import '../core/app_session.dart';
import '../core/sync_engine.dart';
import '../local_db/isar_service.dart';
import '../local_db/enums/local_enums.dart';
import '../local_db/collections/payment_local.dart';
import '../local_db/collections/customer_local.dart';

/// Offline-aware debt recovery service.
/// Online path → Supabase RPC.
/// Offline path → write to Isar + enqueue for later sync.
class DebtRecoveryService {
  static final instance = DebtRecoveryService._();
  DebtRecoveryService._();

  final _client = Supabase.instance.client;

  // ══════════════════════════════════════════
  // Record Debt Payment
  // ══════════════════════════════════════════

  Future<void> recordDebtPayment({
    required String customerId,
    required double amount,
    required String paymentMethod,
    required String storeId,
    String? notes,
  }) async {
    // ── ONLINE PATH ──
    if (!AppSession.isOfflineMode) {
      await _client.rpc('add_debt_recovery_payment', params: {
        'p_customer_id': customerId,
        'p_amount': amount,
        'p_payment_method': paymentMethod,
        'p_store_id': storeId,
        'p_notes': notes,
      });
      return;
    }

    // ── OFFLINE PATH ──
    final isar = await IsarService.getInstance();

    final payment = PaymentLocal()
      ..supabaseId = ''
      ..customerId = customerId
      ..amount = amount
      ..paymentMethod = paymentMethod
      ..paymentType = 'debt_recovery'
      ..storeId = storeId
      ..userId = AppSession.currentUserId
      ..notes = notes ?? 'Recouvrement de dette'
      ..paymentDate = DateTime.now()
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now()
      ..synced = false;

    await isar.writeTxn(() async {
      await isar.paymentLocals.put(payment);
    });

    // Also update local customer balance
    final customer = await isar.customerLocals
        .filter()
        .supabaseIdEqualTo(customerId)
        .findFirst();
    if (customer != null) {
      await isar.writeTxn(() async {
        customer.balance -= amount;
        await isar.customerLocals.put(customer);
      });
    }

    await SyncEngine.instance.enqueue(
      SyncOperationType.createDebtRecoveryPayment,
      {
        'p_customer_id': customerId,
        'p_amount': amount,
        'p_payment_method': paymentMethod,
        'p_store_id': storeId,
        'p_notes': notes,
      },
    );
  }

  // ══════════════════════════════════════════
  // Fetch Customers with Debt
  // ══════════════════════════════════════════

  Future<List<Map<String, dynamic>>> fetchCustomersWithDebt(String storeId) async {
    // ── ONLINE PATH ──
    if (!AppSession.isOfflineMode) {
      try {
        final res = await _client
            .from('customers')
            .select()
            .gt('balance', 0)
            .eq('is_active', true)
            .order('balance', ascending: false);
        return List<Map<String, dynamic>>.from(res);
      } catch (e) {
        debugPrint('Error fetching debtors: $e');
        return [];
      }
    }

    // ── OFFLINE PATH ──
    final isar = await IsarService.getInstance();
    final results = await isar.customerLocals
        .filter()
        .isActiveEqualTo(true)
        .balanceGreaterThan(0)
        .sortByBalanceDesc()
        .findAll();

    return results
        .map((c) => {
              'id': c.supabaseId,
              'full_name': c.fullName,
              'phone': c.phone,
              'email': c.email,
              'balance': c.balance,
            })
        .toList();
  }

  // ══════════════════════════════════════════
  // Fetch Debt Recovery Payments for a Customer
  // ══════════════════════════════════════════

  Future<List<Map<String, dynamic>>> fetchDebtPayments(String customerId) async {
    // ── ONLINE PATH ──
    if (!AppSession.isOfflineMode) {
      try {
        final res = await _client
            .from('payments')
            .select()
            .eq('customer_id', customerId)
            .eq('payment_type', 'debt_recovery')
            .order('created_at', ascending: false);
        return List<Map<String, dynamic>>.from(res);
      } catch (e) {
        debugPrint('Error fetching debt payments: $e');
        return [];
      }
    }

    // ── OFFLINE PATH ──
    final isar = await IsarService.getInstance();
    final results = await isar.paymentLocals
        .filter()
        .customerIdEqualTo(customerId)
        .paymentTypeEqualTo('debt_recovery')
        .sortByCreatedAtDesc()
        .findAll();

    return results
        .map((p) => {
              'id': p.supabaseId,
              'amount': p.amount,
              'payment_method': p.paymentMethod,
              'notes': p.notes,
              'created_at': p.createdAt?.toIso8601String(),
            })
        .toList();
  }
}
