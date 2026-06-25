import '../core/app_session.dart';

/// Validates store_id presence for RPC calls.
class StoreGuard {
  StoreGuard._();

  /// Returns current store ID or throws [StateError] if not set.
  static String requireStoreId() {
    final storeId = AppSession.currentStoreId;
    if (storeId == null) {
      throw StateError('No store selected for current session');
    }
    return storeId;
  }

  /// Returns [params] with 'p_store_id' added using current session.
  static Map<String, dynamic> withStoreId(Map<String, dynamic> params) {
    return {...params, 'p_store_id': requireStoreId()};
  }
}
