import 'package:isar/isar.dart';

part 'product_variant_local.g.dart';

@Collection()
class ProductVariantLocal {
  Id isarId = Isar.autoIncrement;

  String supabaseId = '';
  String productId = '';
  String size = '';
  String color = '';

  @Index()
  String? barcode;

  double sellPrice = 0.0;
  double buyPrice = 0.0;
  double? wholesalePrice;
  String? unitType;
  int? unitsPerCarton;
  bool isActive = true;
  DateTime? createdAt;
  DateTime? updatedAt;
}
