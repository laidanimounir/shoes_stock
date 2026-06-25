import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_session.dart';
import '../services/invoice_service.dart';

/// Extracts payment processing logic from the POS screen.
/// One instance per POS session.
class PosPaymentController {
  final void Function(Map<String, dynamic> result) onPaymentComplete;

  PosPaymentController({required this.onPaymentComplete});

  /// Generates a unique invoice number based on timestamp.
  String generateInvoiceNumber() {
    return 'INV-${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Calculates discount amount based on mode (percent or fixed).
  double calculateDiscount({
    required double totalAmount,
    required int discountMode,
    required double discountInput,
    required double discountFixed,
  }) {
    if (discountMode == 0 && discountInput > 0) {
      return totalAmount * discountInput / 100;
    } else if (discountMode == 1 && discountFixed > 0) {
      return discountFixed;
    }
    return 0;
  }

  /// Validates customer credit limit for partial/unpaid sales.
  /// Returns null if OK, or error map if limit exceeded.
  Future<Map<String, dynamic>?> validateCreditLimit({
    required String customerId,
    required double totalAmount,
    required double paidAmount,
  }) async {
    final debtAmount = totalAmount - paidAmount;
    if (debtAmount <= 0) return null;

    try {
      final custRes = await Supabase.instance.client
          .from('customers')
          .select('balance, credit_limit')
          .eq('id', customerId)
          .maybeSingle();

      final balance = (custRes?['balance'] as num?)?.toDouble() ?? 0;
      final creditLimit = (custRes?['credit_limit'] as num?)?.toDouble() ?? 0;

      if (creditLimit > 0 && (balance + debtAmount) > creditLimit) {
        return {
          'success': false,
          'error': 'CREDIT_LIMIT_EXCEEDED|$balance|$creditLimit'
        };
      }
    } catch (e) {
      debugPrint('[PosPaymentController] Credit limit check error: $e');
    }
    return null;
  }

  /// Processes a sale via InvoiceService (handles online + offline).
  Future<void> processPayment({
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
    final result = await InvoiceService.instance.processSale(
      storeId: storeId,
      customerId: customerId,
      invoiceNumber: invoiceNumber,
      items: items,
      totalAmount: totalAmount,
      paidAmount: paidAmount,
      paymentMethod: paymentMethod,
      notes: notes,
      discountPercent: discountPercent,
      discountAmount: discountAmount,
      dueDate: dueDate,
    );
    onPaymentComplete(result);
  }
}
