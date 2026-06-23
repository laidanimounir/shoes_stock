import 'package:isar/isar.dart';

part 'store_local.g.dart';

@Collection()
class StoreLocal {
  Id isarId = Isar.autoIncrement;

  String supabaseId = '';
  String name = '';
  String? location;
  bool isActive = true;
  DateTime? createdAt;
  DateTime? updatedAt;
}
