import 'package:isar/isar.dart';

part 'settings_local.g.dart';

@collection
class SettingsLocal {
  Id isarId = 1; // singleton — always ID 1

  String locale = 'ar';
  int debtOverdueDays = 30;
  int inactivityTimeoutMinutes = 15;
  int lowStockThreshold = 3;
  String? pinHash;
  bool biometricEnabled = false;
  int? lastApiVersionCheck;
}
