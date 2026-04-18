import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:isar/isar.dart';
import '../core/app_session.dart';
import '../core/sync_engine.dart';
import '../local_db/isar_service.dart';
import '../local_db/enums/local_enums.dart';
import '../local_db/collections/invoice_local.dart';
import '../local_db/collections/transaction_local.dart';
import '../local_db/collections/inventory_local.dart';

/// Offline-aware invoice service.
/// Online path → Supabase RPC directly.
/// Offline path → write to Isar + enqueue for later sync.
class InvoiceService {
  static final instance = InvoiceService._();
  InvoiceService._();

  Future<Map<String, dynamic>> processSale({
    required String storeId,
    required String invoiceNumber,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required double paidAmount,
    required String paymentMethod,
    String? customerId,
    String? shiftId,
    String notes = '',
  }) async {
    // ════════════════════════════════════
    // ONLINE PATH — call Supabase RPC
    // ════════════════════════════════════
    if (!AppSession.isOfflineMode) {
      final result =
          await Supabase.instance.client.rpc('process_sale', params: {
        'p_store_id': storeId,
        'p_customer_id': customerId,
        'p_invoice_number': invoiceNumber,
        'p_items': items,
        'p_total_amount': totalAmount,
        'p_paid_amount': paidAmount,
        'p_payment_method': paymentMethod,
        'p_notes': notes,
        'p_shift_id': shiftId,
      });
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
      return {'success': true};
    }

    // ════════════════════════════════════
    // OFFLINE PATH — write Isar + enqueue
    // ════════════════════════════════════
    final isar = await IsarService.getInstance();

    // 1. Determine status
    String status;
    if (paidAmount == 0) {
      status = InvoiceStatusExt.fromString('unpaid').toSupabaseString();
    } else if (paidAmount < totalAmount) {
      status = InvoiceStatusExt.fromString('partial').toSupabaseString();
    } else {
      status = InvoiceStatusExt.fromString('paid').toSupabaseString();
    }

    // 2. Create InvoiceLocal
    final invoice = InvoiceLocal()
      ..supabaseId = ''
      ..invoiceNumber = invoiceNumber
      ..storeId = storeId
      ..userId = AppSession.currentUserId ?? ''
      ..customerId = customerId
      ..type = InvoiceTypeExt.fromString('out').toSupabaseString()
      ..totalAmount = totalAmount
      ..paidAmount = paidAmount
      ..discount = 0
      ..status = status
      ..shiftId = shiftId
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now()
      ..synced = false;

    late int localInvoiceId;
    await isar.writeTxn(() async {
      localInvoiceId = await isar.invoiceLocals.put(invoice);
    });

    // 3. Create TransactionLocal per item + deduct inventory
    for (final item in items) {
      final tx = TransactionLocal()
        ..supabaseId = ''
        ..type = TransactionTypeExt.fromString('out').toSupabaseString()
        ..variantId = item['variant_id'] as String
        ..quantity = item['quantity'] as int
        ..unitPrice = (item['unit_price'] as num).toDouble()
        ..totalPrice = (item['total_price'] as num).toDouble()
        ..storeId = storeId
        ..userId = AppSession.currentUserId ?? ''
        ..customerId = customerId
        ..invoiceId = ''
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now()
        ..synced = false;

      await isar.writeTxn(() async {
        await isar.transactionLocals.put(tx);
      });

      // Deduct from local inventory
      final inv = await isar.inventoryLocals
          .filter()
          .variantIdEqualTo(item['variant_id'] as String)
          .and()
          .storeIdEqualTo(storeId)
          .findFirst();
      if (inv != null) {
        await isar.writeTxn(() async {
          inv.quantity -= (item['quantity'] as int);
          inv.updatedAt = DateTime.now();
          await isar.inventoryLocals.put(inv);
        });
      }
    }

    // 4. Enqueue for sync when back online
    await SyncEngine.instance.enqueue(
      SyncOperationType.createInvoice,
      {
        'p_store_id': storeId,
        'p_customer_id': customerId,
        'p_invoice_number': invoiceNumber,
        'p_items': items,
        'p_total_amount': totalAmount,
        'p_paid_amount': paidAmount,
        'p_payment_method': paymentMethod,
        'p_notes': notes,
        'p_shift_id': shiftId,
      },
    );

    return {'success': true, 'invoice_id': 'local_$localInvoiceId'};
  }
}
