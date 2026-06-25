import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:isar/isar.dart';
import '../core/app_session.dart';
import '../core/sync_engine.dart';
import '../local_db/isar_service.dart';
import '../local_db/enums/local_enums.dart';
import '../local_db/collections/invoice_local.dart';
import '../local_db/collections/transaction_local.dart';
import '../local_db/collections/inventory_local.dart';

class PurchaseService {
  static final instance = PurchaseService._();
  PurchaseService._();

  Future<Map<String, dynamic>> processPurchase({
    required String storeId,
    required String supplierId,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required double paidAmount,
    required String paymentMethod,
    String notes = '',
  }) async {
    final invoiceNumber = 'ACH-${DateTime.now().millisecondsSinceEpoch}';

    if (!AppSession.isOfflineMode) {
      try {
        final result = await Supabase.instance.client.rpc('process_purchase', params: {
          'p_store_id': storeId,
          'p_supplier_id': supplierId,
          'p_invoice_number': invoiceNumber,
          'p_items': items,
          'p_total_amount': totalAmount,
          'p_paid_amount': paidAmount,
          'p_payment_method': paymentMethod,
          'p_notes': notes,
          'p_idempotency_key': 'purchase-${DateTime.now().microsecondsSinceEpoch}',
        });
        if (result is Map) {
          return Map<String, dynamic>.from(result);
        }
        return {'success': true};
      } on PostgrestException catch (e) {
        debugPrint('[PurchaseService] PostgrestException: ${e.message}');
        return {'success': false, 'error': e.message};
      } catch (e, stackTrace) {
        debugPrint('[PurchaseService] Unexpected error: $e');
        debugPrint('[PurchaseService] StackTrace: $stackTrace');
        return {'success': false, 'error': e.toString()};
      }
    }

    final isar = await IsarService.getInstance();

    String status;
    if (paidAmount == 0) {
      status = InvoiceStatusExt.fromString('unpaid').toSupabaseString();
    } else if (paidAmount < totalAmount) {
      status = InvoiceStatusExt.fromString('partial').toSupabaseString();
    } else {
      status = InvoiceStatusExt.fromString('paid').toSupabaseString();
    }

    final invoice = InvoiceLocal()
      ..supabaseId = ''
      ..invoiceNumber = invoiceNumber
      ..storeId = storeId
      ..userId = AppSession.currentUserId ?? ''
      ..supplierId = supplierId
      ..type = InvoiceTypeExt.fromString('in').toSupabaseString()
      ..totalAmount = totalAmount
      ..paidAmount = paidAmount
      ..discount = 0
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
          ..type = TransactionTypeExt.fromString('in').toSupabaseString()
          ..variantId = item['variant_id'] as String
          ..quantity = item['quantity'] as int
          ..unitPrice = (item['unit_price'] as num).toDouble()
          ..totalPrice = (item['total_price'] as num).toDouble()
          ..storeId = storeId
          ..userId = AppSession.currentUserId ?? ''
          ..supplierId = supplierId
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
          inv.quantity += (item['quantity'] as int);
          inv.updatedAt = DateTime.now();
          await isar.inventoryLocals.put(inv);
        }
      }

      await SyncEngine.instance.enqueueInTransaction(
        isar,
        SyncOperationType.createPurchase,
        {
          'p_store_id': storeId,
          'p_supplier_id': supplierId,
          'p_invoice_number': invoiceNumber,
          'p_items': items,
          'p_total_amount': totalAmount,
          'p_paid_amount': paidAmount,
          'p_payment_method': paymentMethod,
          'p_notes': notes,
        },
      );
    });

    await SyncEngine.instance.updatePendingCount();

    return {'success': true, 'invoice_id': 'local_$localInvoiceId'};
  }
}
