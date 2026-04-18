import 'package:isar/isar.dart';

part 'inventory_local.g.dart';

@Collection()
class InventoryLocal {
  Id isarId = Isar.autoIncrement;

  late String supabaseId;

  @Index()
  late String variantId;

  @Index()
  late String storeId;
  int quantity = 0;
  DateTime? createdAt;
  DateTime? updatedAt;
}
