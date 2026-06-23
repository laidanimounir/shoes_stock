import 'package:isar/isar.dart';

part 'expense_local.g.dart';

@Collection()
class ExpenseLocal {
  Id isarId = Isar.autoIncrement;

  @Index()
  String? supabaseId;

  String? categoryId;
  double amount = 0.0;
  String? description;
  String paymentMethod = '';
  String storeId = '';
  String? userId;
  DateTime expenseDate = DateTime.now();
  DateTime? createdAt;
  DateTime? updatedAt;

  /// false = created offline, not yet pushed to Supabase
  bool synced = false;
}
