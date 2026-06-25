import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shared POS utility methods used by both mobile and desktop POS screens.
class PosUtils {
  PosUtils._();

  /// Fire-and-forget discount activity logging.
  /// Used by both POS platforms to ensure identical logging behavior.
  static void logDiscountActivity({
    required String storeId,
    required String userId,
    required String invoiceNumber,
    required double discountAmount,
    required double discountPercent,
    required double totalAmount,
  }) {
    if (discountAmount <= 0 && discountPercent <= 0) return;

    unawaited(
      Supabase.instance.client.from('activity_logs').insert({
        'user_id': userId,
        'action_type': 'discount_applied',
        'description': 'Remise: ${discountPercent > 0 ? "$discountPercent%" : "$discountAmount DA"} '
            'sur facture $invoiceNumber (total: $totalAmount DA)',
        'store_id': storeId,
        'amount': discountAmount > 0 ? discountAmount : 0,
        'created_at': DateTime.now().toIso8601String(),
      }).then(
        (_) {},
        onError: (e) => debugPrint('[PosUtils] Discount log failed: $e'),
      ),
    );
  }
}
