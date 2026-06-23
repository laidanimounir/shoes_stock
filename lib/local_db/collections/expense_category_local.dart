import 'package:isar/isar.dart';

part 'expense_category_local.g.dart';

@Collection()
class ExpenseCategoryLocal {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true)
  String supabaseId = '';
  
  String name = '';
  String storeId = '';
  DateTime? createdAt;
  DateTime? updatedAt;
}
