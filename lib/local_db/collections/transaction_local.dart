import 'package:isar/isar.dart';

part 'transaction_local.g.dart';

@Collection()
class TransactionLocal {
  Id isarId = Isar.autoIncrement;

  late String supabaseId;
  String? invoiceNumber;
  late String type;        // TransactionType: 'in' | 'out' | 'return'
  late String variantId;
  int quantity = 0;
  double unitPrice = 0.0;
  double totalPrice = 0.0;
  late String storeId;
  late String userId;
  String? customerId;
  String? supplierId;
  String? invoiceId;
  DateTime? createdAt;
  DateTime? updatedAt;

  /// false = created offline, not yet pushed to Supabase
  bool synced = false;
}
