import 'package:isar/isar.dart';

part 'expense_local.g.dart';

@Collection()
class ExpenseLocal {
  Id isarId = Isar.autoIncrement;

  @Index()
  String? supabaseId;

  String? categoryId;
  late double amount;
  String? description;
  late String paymentMethod;
  late String storeId;
  String? userId;
  late DateTime expenseDate;
  DateTime? createdAt;

  /// false = created offline, not yet pushed to Supabase
  bool synced = false;
}
