import 'package:isar/isar.dart';

part 'user_profile_local.g.dart';

@Collection()
class UserProfileLocal {
  Id isarId = Isar.autoIncrement;

  late String supabaseId;
  late String fullName;
  late String role; // UserRole.toSupabaseString(): 'owner' | 'employee'
  String? storeId;
  bool isActive = true;
  DateTime? createdAt;
  DateTime? updatedAt;
}
