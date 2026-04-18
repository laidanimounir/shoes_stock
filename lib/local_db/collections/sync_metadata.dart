import 'package:isar/isar.dart';

part 'sync_metadata.g.dart';

/// Singleton metadata record — always stored at isarId = 1.
/// Tracks global sync state for the SyncEngine.
@Collection()
class SyncMetadata {
  Id isarId = 1; // singleton — always ID 1

  DateTime? lastSyncAt;

  /// 'online' or 'offline'
  String mode = 'online';

  /// Number of pending items in SyncQueueItem
  int pendingCount = 0;
}
