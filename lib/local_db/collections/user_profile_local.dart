import 'package:isar/isar.dart';

part 'user_profile_local.g.dart';

@Collection()
class UserProfileLocal {
  Id isarId = Isar.autoIncrement;

  late String supabaseId;
  late String fullName;
  late String role;
  String? storeId;
  bool isActive = true;
  DateTime? createdAt;
  DateTime? updatedAt;

  String? firstName;
  String? lastName;
  String? phone;
  String? address;
  String? jobTitle;
  DateTime? hiredAt;
  bool isPermanentlyDeleted = false;
  double commissionRate = 0;
}
