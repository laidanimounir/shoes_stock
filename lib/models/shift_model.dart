class ShiftModel {
  final String id;
  final String storeId;
  final String cashierId;
  final double openingAmount;
  final double? closingAmount;
  final double? expectedAmount;
  final double? discrepancy;
  final String? notes;
  final DateTime openedAt;
  final DateTime? closedAt;
  final String status;

  ShiftModel({
    required this.id,
    required this.storeId,
    required this.cashierId,
    required this.openingAmount,
    this.closingAmount,
    this.expectedAmount,
    this.discrepancy,
    this.notes,
    required this.openedAt,
    this.closedAt,
    required this.status,
  });

  factory ShiftModel.fromJson(Map<String, dynamic> json) {
    return ShiftModel(
      id: json['id'] as String,
      storeId: json['store_id'] as String,
      cashierId: json['cashier_id'] as String,
      openingAmount: (json['opening_amount'] as num).toDouble(),
      closingAmount: json['closing_amount'] != null ? (json['closing_amount'] as num).toDouble() : null,
      expectedAmount: json['expected_amount'] != null ? (json['expected_amount'] as num).toDouble() : null,
      discrepancy: json['discrepancy'] != null ? (json['discrepancy'] as num).toDouble() : null,
      notes: json['notes'] as String?,
      openedAt: DateTime.parse(json['opened_at'] as String),
      closedAt: json['closed_at'] != null ? DateTime.parse(json['closed_at'] as String) : null,
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'store_id': storeId,
      'cashier_id': cashierId,
      'opening_amount': openingAmount,
      'closing_amount': closingAmount,
      'expected_amount': expectedAmount,
      'discrepancy': discrepancy,
      'notes': notes,
      'opened_at': openedAt.toIso8601String(),
      'closed_at': closedAt?.toIso8601String(),
      'status': status,
    };
  }
}

class ShiftSummary {
  final double opening;
  final double sales;
  final double expected;
  final double closing;
  final double discrepancy;

  ShiftSummary({
    required this.opening,
    required this.sales,
    required this.expected,
    required this.closing,
    required this.discrepancy,
  });

  factory ShiftSummary.fromJson(Map<String, dynamic> json) {
    return ShiftSummary(
      opening: (json['opening'] as num).toDouble(),
      sales: (json['sales'] as num).toDouble(),
      expected: (json['expected'] as num).toDouble(),
      closing: (json['closing'] as num).toDouble(),
      discrepancy: (json['discrepancy'] as num).toDouble(),
    );
  }
}
