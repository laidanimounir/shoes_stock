import 'package:isar/isar.dart';

part 'product_local.g.dart';

@Collection()
class ProductLocal {
  Id isarId = Isar.autoIncrement;

  late String supabaseId;
  late String name;
  String? description;
  String? imageUrl;
  String? supplierId;
  String? category;
  bool isActive = true;
  DateTime? createdAt;
  DateTime? updatedAt;
}
