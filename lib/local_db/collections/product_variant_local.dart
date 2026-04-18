import 'package:isar/isar.dart';

part 'product_variant_local.g.dart';

@Collection()
class ProductVariantLocal {
  Id isarId = Isar.autoIncrement;

  late String supabaseId;
  late String productId;
  late String size;
  late String color;

  @Index()
  String? barcode;

  double sellPrice = 0.0;
  double buyPrice = 0.0;
  bool isActive = true;
  DateTime? createdAt;
  DateTime? updatedAt;
}
