import 'package:isar/isar.dart';

part 'product_local.g.dart';

@Collection()
class ProductLocal {
  Id isarId = Isar.autoIncrement;

  String supabaseId = '';
  String name = '';
  String? description;
  String? imageUrl;
  String? supplierId;
  String? category;
  bool isActive = true;
  DateTime? createdAt;
  DateTime? updatedAt;
}
