import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../local_db/isar_service.dart';
import '../local_db/collections/settings_local.dart';

class ApiVersionInfo {
  final String version;
  final bool deprecated;
  final String minFlutterVersion;
  final String? latestVersion;

  ApiVersionInfo({
    required this.version,
    required this.deprecated,
    required this.minFlutterVersion,
    this.latestVersion,
  });

  factory ApiVersionInfo.fromJson(Map<String, dynamic> json) {
    return ApiVersionInfo(
      version: json['version'] as String? ?? '1',
      deprecated: json['deprecated'] as bool? ?? false,
      minFlutterVersion: json['min_flutter_version'] as String? ?? '3.44.0',
      latestVersion: json['latest_version'] as String?,
    );
  }
}

class ApiVersionService {
  static final ApiVersionService instance = ApiVersionService._();
  ApiVersionService._();

  ApiVersionInfo? _cachedInfo;
  ApiVersionInfo? get cachedInfo => _cachedInfo;

  Future<ApiVersionInfo?> checkVersion() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final isar = await IsarService.getInstance();
      final settings = await isar.settingsLocals.get(1);

      if (settings != null && settings.lastApiVersionCheck != null) {
        final lastCheck = settings.lastApiVersionCheck!;
        if (now - lastCheck < 86400) {
          return _cachedInfo;
        }
      }

      final res = await Supabase.instance.client.functions.invoke('api_version');
      final data = res.data as Map<String, dynamic>?;
      if (data == null) return _cachedInfo;

      _cachedInfo = ApiVersionInfo.fromJson(data);

      await isar.writeTxn(() async {
        final s = await isar.settingsLocals.get(1) ?? SettingsLocal();
        s.lastApiVersionCheck = now;
        await isar.settingsLocals.put(s);
      });

      return _cachedInfo;
    } catch (e) {
      debugPrint('ApiVersionService.checkVersion error: $e');
      return _cachedInfo;
    }
  }

  bool isVersionDeprecated(ApiVersionInfo info) => info.deprecated;

  bool isMinFlutterVersionExceeded(ApiVersionInfo info, String currentVersion) {
    return compareVersions(currentVersion, info.minFlutterVersion) < 0;
  }

  int compareVersions(String a, String b) {
    final partsA = a.split('.').map(int.parse).toList();
    final partsB = b.split('.').map(int.parse).toList();
    for (int i = 0; i < 3; i++) {
      final va = i < partsA.length ? partsA[i] : 0;
      final vb = i < partsB.length ? partsB[i] : 0;
      if (va != vb) return va.compareTo(vb);
    }
    return 0;
  }
}
