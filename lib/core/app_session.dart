import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import '../local_db/isar_service.dart';
import '../local_db/collections/settings_local.dart';
import 'app_strings.dart';

class AppSession {
  /// v3 offline-first: tracks current connectivity mode
  static bool isOfflineMode = false;

  /// v3 offline-first: number of pending sync operations in queue
  static int pendingSync = 0;

  /// Store ID resolved from user_profiles on login
  static String? currentStoreId;

  /// Auth user ID from Supabase
  static String? currentUserId;

  // ══════════════════════════════════════════
  // Locale management
  // ══════════════════════════════════════════

  /// Observable locale — UI rebuilds via ValueListenableBuilder
  static ValueNotifier<String> locale = ValueNotifier('ar');

  /// Loads persisted locale from Isar on startup.
  static Future<void> loadLocale() async {
    try {
      final isar = await IsarService.getInstance();
      final settings = await isar.settingsLocals.get(1);
      if (settings != null) {
        locale.value = settings.locale;
        S.setLocale(settings.locale);
      } else {
        // First run — write default 'ar'
        locale.value = 'ar';
        S.setLocale('ar');
        await isar.writeTxn(() async {
          await isar.settingsLocals.put(SettingsLocal()..locale = 'ar');
        });
      }
    } catch (e) {
      // Fallback to Arabic if Isar not ready
      locale.value = 'ar';
      S.setLocale('ar');
      debugPrint('AppSession.loadLocale error: $e');
    }
  }

  /// Persists locale choice and notifies listeners.
  static Future<void> setLocale(String lang) async {
    locale.value = lang;
    S.setLocale(lang);

    try {
      final isar = await IsarService.getInstance();
      await isar.writeTxn(() async {
        await isar.settingsLocals.put(SettingsLocal()..locale = lang);
      });
    } catch (e) {
      debugPrint('AppSession.setLocale error: $e');
    }
  }
}
