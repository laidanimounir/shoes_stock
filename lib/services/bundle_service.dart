import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_constants.dart';

/// Caches and serves store-specific product bundles.
class BundleService {
  BundleService._();
  static final instance = BundleService._();

  final _client = Supabase.instance.client;
  final Map<String, _CacheEntry<dynamic>> _cache = {};

  Future<List<dynamic>> getStoreBundles(String storeId) async {
    final cached = _cache['bundles_$storeId'];
    if (cached != null && !cached.isStale) {
      return cached.data as List<dynamic>;
    }

    try {
      final res = await _client.rpc('get_store_bundles', params: {
        'p_store_id': storeId,
      });
      final bundles = res is List ? res : <dynamic>[];
      _cache['bundles_$storeId'] = _CacheEntry(
        data: bundles,
        fetchedAt: DateTime.now(),
      );
      return bundles;
    } catch (e) {
      debugPrint('[BundleService] Error: $e');
      return <dynamic>[];
    }
  }

  void clearCache() => _cache.clear();
}

class _CacheEntry<T> {
  final T data;
  final DateTime fetchedAt;

  _CacheEntry({required this.data, required this.fetchedAt});

  bool get isStale =>
      DateTime.now().difference(fetchedAt).inMinutes >=
      AppConstants.dashboardCacheDurationMinutes;
}
