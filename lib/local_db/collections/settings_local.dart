import 'package:isar/isar.dart';

part 'settings_local.g.dart';

@collection
class SettingsLocal {
  Id isarId = 1; // singleton — always ID 1

  String locale = 'ar';
}
