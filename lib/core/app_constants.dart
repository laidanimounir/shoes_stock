class AppConstants {
  AppConstants._();

  /// Sync Engine
  static const int syncMaxRetries = 5;
  static const int syncMaxQueueSize = 500;

  /// UI
  static const int paginationPageSize = 50;
  static const int searchDebounceMs = 300;
  static const int inactivityTimeoutMinutes = 30;
  static const int dashboardCacheDurationMinutes = 5;

  /// Business
  static const double defaultCreditLimit = 0.0;
  static const int maxDiscount = 100;
  static const int minLowStockThreshold = 1;
}
