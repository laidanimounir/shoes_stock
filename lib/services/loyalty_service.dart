import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_session.dart';
import '../core/sync_engine.dart';
import '../local_db/enums/local_enums.dart';

/// Manages customer loyalty points — award and redeem operations.
/// Online path → Supabase RPCs directly.
/// Offline path → enqueues for SyncEngine replay.
class LoyaltyService {
  LoyaltyService._();
  static final instance = LoyaltyService._();

  final _client = Supabase.instance.client;

  /// Awards loyalty points to a customer after a purchase.
  /// Fire-and-forget — does not block the payment flow.
  Future<void> award({
    required String customerId,
    required double amountSpent,
  }) async {
    if (AppSession.isOfflineMode) {
      await SyncEngine.instance.enqueue(
        SyncOperationType.createLogDiscount,
        {
          'p_customer_id': customerId,
          'p_amount_spent': amountSpent,
        },
      );
      return;
    }
    try {
      await _client.rpc('award_loyalty_points', params: {
        'p_customer_id': customerId,
        'p_amount_spent': amountSpent,
      });
    } catch (e) {
      debugPrint('[LoyaltyService] Award error: $e');
    }
  }

  /// Redeems loyalty points for a discount.
  /// Returns the discount amount (double) or 0 on failure.
  Future<double> redeem({
    required String customerId,
    required int points,
  }) async {
    try {
      final discount = await _client.rpc('redeem_loyalty_points', params: {
        'p_customer_id': customerId,
        'p_points': points,
      });
      if (discount is num) return discount.toDouble();
      return 0;
    } catch (e) {
      debugPrint('[LoyaltyService] Redeem error: $e');
      return 0;
    }
  }
}
