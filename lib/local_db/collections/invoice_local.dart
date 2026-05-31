import 'package:isar/isar.dart';

part 'invoice_local.g.dart';

@Collection()
class InvoiceLocal {
  Id isarId = Isar.autoIncrement;

  late String supabaseId;
  late String invoiceNumber;
  String? storeId;
  String? userId;
  String? customerId;
  String? supplierId;
  late String type;        // InvoiceType: 'in' | 'out' | 'return'
  double totalAmount = 0.0;
  double paidAmount = 0.0;
  double discount = 0.0;
  String? notes;
  late String status;      // InvoiceStatus: 'paid' | 'partial' | 'unpaid' | ...
  DateTime? createdAt;
  DateTime? updatedAt;
  DateTime? dueDate;

  /// false = created offline, not yet pushed to Supabase
  bool synced = false;
}
