import 'package:isar/isar.dart';

part 'supplier_local.g.dart';

@Collection()
class SupplierLocal {
  Id isarId = Isar.autoIncrement;

  String supabaseId = '';
  String companyName = '';
  String? contactName;
  String? phone;
  String? imageUrl;
  bool isActive = true;
  double balance = 0.0;
  DateTime? createdAt;
  DateTime? updatedAt;
}
