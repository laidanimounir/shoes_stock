import 'package:isar/isar.dart';

part 'inventory_local.g.dart';

@Collection()
class InventoryLocal {
  Id isarId = Isar.autoIncrement;

  late String supabaseId;

  @Index(composite: [CompositeIndex('storeId')], unique: true)
  late String variantId;

  late String storeId;
  int quantity = 0;
  DateTime? createdAt;
  DateTime? updatedAt;
}
