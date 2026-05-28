import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static PreferencesService? _instance;
  static PreferencesService get instance => _instance ??= PreferencesService._();
  PreferencesService._();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<String?> getString(String key) async => _prefs?.getString(key);
  Future<void> setString(String key, String value) async => await _prefs?.setString(key, value);
  Future<int?> getInt(String key) async => _prefs?.getInt(key);
  Future<void> setInt(String key, int value) async => await _prefs?.setInt(key, value);
  Future<bool?> getBool(String key) async => _prefs?.getBool(key);
  Future<void> setBool(String key, bool value) async => await _prefs?.setBool(key, value);
  Future<void> remove(String key) async => await _prefs?.remove(key);
}
