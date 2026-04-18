class AppSession {
  static String? currentShiftId;

  /// v3 offline-first: tracks current connectivity mode
  static bool isOfflineMode = false;

  /// v3 offline-first: number of pending sync operations in queue
  static int pendingSync = 0;

  /// Store ID resolved from user_profiles on login
  static String? currentStoreId;

  /// Auth user ID from Supabase
  static String? currentUserId;
}

