import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_session.dart';
import '../core/sync_engine.dart';
import '../local_db/enums/local_enums.dart';
import '../local_db/isar_service.dart';
import '../local_db/collections/invoice_local.dart';
import '../local_db/collections/inventory_local.dart';

class RefundService {
  RefundService._();
  static final instance = RefundService._();

  static bool isValidUuid(String value) {
    if (value.isEmpty) return false;
    if (value.startsWith('local_')) return false;
    final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
    return uuidRegex.hasMatch(value);
  }

  Future<Map<String, dynamic>> processRefund({
    required String invoiceId,
    required List<Map<String, dynamic>> items,
    required double refundAmount,
    required String reason,
    required String storeId,
  }) async {
    if (AppSession.isOfflineMode) {
      return _processRefundOffline(
        invoiceId: invoiceId,
        items: items,
        refundAmount: refundAmount,
        reason: reason,
        storeId: storeId,
      );
    }
    if (!isValidUuid(invoiceId)) {
      throw Exception('Cette facture n\'est pas encore synchronisée. Veuillez patienter.');
    }
    return _processRefundOnline(
      invoiceId: invoiceId,
      items: items,
      refundAmount: refundAmount,
      reason: reason,
    );
  }

  Future<Map<String, dynamic>> _processRefundOnline({
    required String invoiceId,
    required List<Map<String, dynamic>> items,
    required double refundAmount,
    required String reason,
  }) async {
    try {
      final result = await Supabase.instance.client.rpc('process_refund', params: {
        'p_invoice_id': invoiceId,
        'p_items': items,
        'p_refund_amount': refundAmount,
        'p_reason': reason,
        'p_user_id': AppSession.currentUserId,
      });
      return Map<String, dynamic>.from(result as Map);
    } on PostgrestException catch (e) {
      debugPrint('[RefundService] PostgrestException: ${e.message}');
      return {'success': false, 'error': e.message};
    } catch (e, stackTrace) {
      debugPrint('[RefundService] Unexpected error: $e');
      debugPrint('[RefundService] StackTrace: $stackTrace');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _processRefundOffline({
    required String invoiceId,
    required List<Map<String, dynamic>> items,
    required double refundAmount,
    required String reason,
    required String storeId,
  }) async {
    final isar = await IsarService.getInstance();

    await isar.writeTxn(() async {
      final allInvoices = await isar.invoiceLocals.where().findAll();
      final invoice = allInvoices.cast<InvoiceLocal?>().firstWhere((i) =>
          i!.supabaseId == invoiceId || 'local_${i.isarId}' == invoiceId, orElse: () => null);
      if (invoice != null) {
        invoice.status = refundAmount >= invoice.totalAmount
            ? 'refunded'
            : 'partial_refund';
        invoice.paidAmount =
            (invoice.paidAmount - refundAmount).clamp(0, double.infinity);
        invoice.synced = false;
        await isar.invoiceLocals.put(invoice);
      }

      for (final item in items) {
        final variantId = item['variant_id'] as String;
        final qty = item['quantity'] as int;
        final allInv = await isar.inventoryLocals.where().findAll();
        final inv = allInv.cast<InventoryLocal?>().firstWhere((i) =>
            i!.variantId == variantId && i.storeId == storeId, orElse: () => null);
        if (inv != null) {
          inv.quantity += qty;
          await isar.inventoryLocals.put(inv);
        }
      }

      await SyncEngine.instance.enqueueInTransaction(
        isar,
        SyncOperationType.processRefund,
        {
          'p_invoice_id': invoiceId,
          'p_items': items,
          'p_refund_amount': refundAmount,
          'p_reason': reason,
          'p_user_id': AppSession.currentUserId,
        },
      );
    });

    return {'success': true, 'new_status': 'refunded', 'offline': true};
  }
}
