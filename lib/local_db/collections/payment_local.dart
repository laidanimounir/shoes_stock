import 'package:isar/isar.dart';

part 'payment_local.g.dart';

@Collection()
class PaymentLocal {
  Id isarId = Isar.autoIncrement;

  late String supabaseId;
  String? invoiceId;
  String? customerId;
  String? supplierId;
  String? storeId;
  String? userId;
  late double amount;
  String paymentMethod = 'cash';
  DateTime? paymentDate;
  String? notes;
  String paymentType = 'invoice'; // 'invoice' | 'debt_recovery'
  DateTime? createdAt;
  DateTime? updatedAt;

  /// false = created offline, not yet pushed to Supabase
  bool synced = false;
}
