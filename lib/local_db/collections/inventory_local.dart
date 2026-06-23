import 'package:isar/isar.dart';

part 'inventory_local.g.dart';

@Collection()
class InventoryLocal {
  Id isarId = Isar.autoIncrement;

  String supabaseId = '';

  @Index()
  String variantId = '';

  @Index()
  String storeId = '';
  int quantity = 0;
  String? arrivageId;
  DateTime? arrivageDate;
  double? purchasePrice;
  DateTime? createdAt;
  DateTime? updatedAt;
}
