import 'package:isar/isar.dart';

part 'transaction_local.g.dart';

@Collection()
class TransactionLocal {
  Id isarId = Isar.autoIncrement;

  String supabaseId = '';
  String? invoiceNumber;
  String type = '';         // TransactionType: 'in' | 'out' | 'return'
  String variantId = '';
  int quantity = 0;
  double unitPrice = 0.0;
  double totalPrice = 0.0;
  String storeId = '';
  String userId = '';
  String? customerId;
  String? supplierId;
  String? invoiceId;
  double? profitMargin;
  DateTime? createdAt;
  DateTime? updatedAt;

  /// false = created offline, not yet pushed to Supabase
  bool synced = false;
}
