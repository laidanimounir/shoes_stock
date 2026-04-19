import 'package:isar/isar.dart';

part 'expense_category_local.g.dart';

@Collection()
class ExpenseCategoryLocal {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true)
  late String supabaseId;
  
  late String name;
  late String storeId;
  DateTime? createdAt;
}
