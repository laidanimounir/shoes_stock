import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:isar/isar.dart';
import '../core/app_session.dart';
import '../core/sync_engine.dart';
import '../local_db/isar_service.dart';
import '../local_db/enums/local_enums.dart';
import '../local_db/collections/customer_local.dart';
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
    String notes = '',
    double discountPercent = 0,
    double discountAmount = 0,
    DateTime? dueDate,
  }) async {
    // Check credit limit if this is a credit sale (partial or unpaid)
    if (customerId != null && paidAmount < totalAmount) {
      final debtAmount = totalAmount - paidAmount;
      late double balance;
      late double creditLimit;

      if (!AppSession.isOfflineMode) {
        final custRes = await Supabase.instance.client
            .from('customers')
            .select('balance, credit_limit')
            .eq('id', customerId)
            .maybeSingle();
        balance = (custRes?['balance'] as num?)?.toDouble() ?? 0;
        creditLimit = (custRes?['credit_limit'] as num?)?.toDouble() ?? 0;
      } else {
        final isar = await IsarService.getInstance();
        final allCust = await isar.customerLocals.where().findAll();
        final cust = allCust.cast<CustomerLocal?>().firstWhere(
              (c) => c!.supabaseId == customerId,
              orElse: () => null,
            );
        balance = cust?.balance ?? 0;
        creditLimit = cust?.creditLimit ?? 0;
      }

      if (creditLimit > 0 && (balance + debtAmount) > creditLimit) {
        throw Exception('CREDIT_LIMIT_EXCEEDED|$balance|$creditLimit');
      }
    }

    // ════════════════════════════════════
    // ONLINE PATH — call Supabase RPC
    // ════════════════════════════════════
    if (!AppSession.isOfflineMode) {
      try {
        final params = <String, dynamic>{
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
        };
        if (dueDate != null) {
          params['p_due_date'] = dueDate.toIso8601String().substring(0, 10);
        }
        final result =
            await Supabase.instance.client.rpc('process_sale', params: params);

        if (result == null) {
          return {'success': false, 'error': 'process_sale returned null'};
        }

        if (result is! Map) {
          return {
            'success': false,
            'error': 'Unexpected response type: ${result.runtimeType}'
          };
        }

        final response = Map<String, dynamic>.from(result);

        if (response['success'] == false || response.containsKey('error')) {
          return response;
        }

        return response;
      } on PostgrestException catch (e) {
        debugPrint('[InvoiceService] PostgrestException: ${e.message}');
        return {'success': false, 'error': e.message};
      } catch (e, stackTrace) {
        debugPrint('[InvoiceService] Unexpected error: $e');
        debugPrint('[InvoiceService] StackTrace: $stackTrace');
        return {'success': false, 'error': e.toString()};
      }
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
      ..notes = notes
      ..status = status
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now()
      ..dueDate = dueDate
      ..synced = false;

    late int localInvoiceId;

    await isar.writeTxn(() async {
      localInvoiceId = await isar.invoiceLocals.put(invoice);

      for (final item in items) {
        final unitPrice = (item['unit_price'] as num).toDouble();
        final qty = item['quantity'] as int;
        final tx = TransactionLocal()
          ..supabaseId = ''
          ..invoiceNumber = invoiceNumber
          ..type = TransactionTypeExt.fromString('out').toSupabaseString()
          ..variantId = item['variant_id'] as String
          ..quantity = qty
          ..unitPrice = unitPrice
          ..totalPrice = (item['total_price'] as num).toDouble()
          ..storeId = storeId
          ..userId = AppSession.currentUserId ?? ''
          ..customerId = customerId
          ..invoiceId = ''
          ..profitMargin = null
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

      final syncParams = <String, dynamic>{
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
      };
      if (dueDate != null) {
        syncParams['p_due_date'] = dueDate.toIso8601String().substring(0, 10);
      }
      await SyncEngine.instance.enqueueInTransaction(
        isar,
        SyncOperationType.createInvoice,
        syncParams,
      );
    });

    return {'success': true, 'invoice_id': 'local_$localInvoiceId'};
  }
}
