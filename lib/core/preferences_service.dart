import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static PreferencesService? _instance;
  static PreferencesService get instance => _instance ??= PreferencesService._();
  PreferencesService._();

  SharedPreferences? _prefs;

  SharedPreferences get _safePrefs {
    if (_prefs == null) {
      throw StateError(
        'PreferencesService not initialized. Call init() before use.',
      );
    }
    return _prefs!;
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<String?> getString(String key) async => _safePrefs.getString(key);
  Future<void> setString(String key, String value) async => await _safePrefs.setString(key, value);
  Future<int?> getInt(String key) async => _safePrefs.getInt(key);
  Future<void> setInt(String key, int value) async => await _safePrefs.setInt(key, value);
  Future<bool?> getBool(String key) async => _safePrefs.getBool(key);
  Future<void> setBool(String key, bool value) async => await _safePrefs.setBool(key, value);
  Future<void> remove(String key) async => await _safePrefs.remove(key);
}
