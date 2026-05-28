import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:isar/isar.dart';
import '../core/app_session.dart';
import '../core/sync_engine.dart';
import '../local_db/isar_service.dart';
import '../local_db/enums/local_enums.dart';
import '../local_db/collections/invoice_local.dart';
import '../local_db/collections/transaction_local.dart';
import '../local_db/collections/inventory_local.dart';
import '../local_db/collections/customer_local.dart';

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
    String notes = '',
    double discountPercent = 0,
    double discountAmount = 0,
  }) async {
    // Check credit limit if this is a credit sale (partial or unpaid)
    if (customerId != null && paidAmount < totalAmount) {
      final debtAmount = totalAmount - paidAmount;
      if (!AppSession.isOfflineMode) {
        final custRes = await Supabase.instance.client
            .from('customers')
            .select('balance, credit_limit')
            .eq('id', customerId)
            .single();
        final balance = (custRes['balance'] as num?)?.toDouble() ?? 0;
        final creditLimit = (custRes['credit_limit'] as num?)?.toDouble() ?? 0;
        if (creditLimit > 0 && (balance + debtAmount) > creditLimit) {
          throw Exception('CREDIT_LIMIT_EXCEEDED|$balance|$creditLimit');
        }
      }
    }

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
        'p_discount_percent': discountPercent,
        'p_discount_amount': discountAmount,
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

    final calculatedDiscount = discountAmount > 0
        ? discountAmount
        : (discountPercent > 0 ? totalAmount * discountPercent / 100 : 0);
    final finalAmount = totalAmount - calculatedDiscount;

    String status;
    if (paidAmount == 0) {
      status = InvoiceStatusExt.fromString('unpaid').toSupabaseString();
    } else if (paidAmount < finalAmount) {
      status = InvoiceStatusExt.fromString('partial').toSupabaseString();
    } else {
      status = InvoiceStatusExt.fromString('paid').toSupabaseString();
    }

    final invoice = InvoiceLocal()
      ..supabaseId = ''
      ..invoiceNumber = invoiceNumber
      ..storeId = storeId
      ..userId = AppSession.currentUserId ?? ''
      ..customerId = customerId
      ..type = InvoiceTypeExt.fromString('out').toSupabaseString()
      ..totalAmount = finalAmount
      ..paidAmount = paidAmount
      ..discount = calculatedDiscount.toDouble()
      ..status = status
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now()
      ..synced = false;

    late int localInvoiceId;

    await isar.writeTxn(() async {
      localInvoiceId = await isar.invoiceLocals.put(invoice);

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
        await isar.transactionLocals.put(tx);

        final inv = await isar.inventoryLocals
            .filter()
            .variantIdEqualTo(item['variant_id'] as String)
            .and()
            .storeIdEqualTo(storeId)
            .findFirst();
        if (inv != null) {
          inv.quantity -= (item['quantity'] as int);
          inv.updatedAt = DateTime.now();
          await isar.inventoryLocals.put(inv);
        }
      }

      await SyncEngine.instance.enqueueInTransaction(
        isar,
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
          'p_discount_percent': discountPercent,
          'p_discount_amount': discountAmount,
        },
      );
    });

    return {'success': true, 'invoice_id': 'local_$localInvoiceId'};
  }
}
