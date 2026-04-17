import 'package:supabase_flutter/supabase_flutter.dart';

class RefundService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<String> processRefund(String invoiceId, List<Map<String, dynamic>> items, double refundAmount, {String? reason}) async {
    try {
      final response = await _supabase.rpc('process_refund', params: {
        'p_invoice_id': invoiceId,
        'p_items': items,
        'p_refund_amount': refundAmount,
        'p_reason': reason,
      });
      return response as String;
    } catch (e) {
      // Handle all PostgrestExceptions gracefully
      if (e is PostgrestException) {
         throw 'فشلت عملية الإرجاع: ${e.message}';
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getRefundableInvoices(String storeId) async {
    try {
      final response = await _supabase
          .from('invoices')
          .select('''
            *,
            transactions (*),
            customers (full_name, phone)
          ''')
          .eq('store_id', storeId)
          .eq('status', 'paid')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (e is PostgrestException) {
         throw 'تعذر جلب الفواتير المكتملة: ${e.message}';
      }
      rethrow;
    }
  }
}
