import 'package:isar/isar.dart';

part 'customer_local.g.dart';

@Collection()
class CustomerLocal {
  Id isarId = Isar.autoIncrement;

  late String supabaseId;
  late String fullName;
  String? phone;
  String? email;
  String? address;
  String? imageUrl;
  bool isActive = true;
  double balance = 0.0;
  DateTime? createdAt;
  DateTime? updatedAt;
}
