import 'package:isar/isar.dart';

part 'customer_local.g.dart';

@Collection()
class CustomerLocal {
  Id isarId = Isar.autoIncrement;

  String supabaseId = '';
  String fullName = '';
  String? phone;
  String? email;
  String? address;
  String? imageUrl;
  bool isActive = true;
  double balance = 0.0;
  int loyaltyPoints = 0;
  double? creditLimit;
  String? customerType; // 'retail' or 'wholesale'
  DateTime? createdAt;
  DateTime? updatedAt;
}
