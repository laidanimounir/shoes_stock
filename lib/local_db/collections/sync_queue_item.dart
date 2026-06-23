import 'package:isar/isar.dart';

part 'sync_queue_item.g.dart';

/// Offline operation queue — each row is one pending RPC call to replay
/// when connectivity is restored.
@Collection()
class SyncQueueItem {
  Id isarId = Isar.autoIncrement;

  /// SyncOperationType.toSupabaseString()
  String operationType = '';

  /// jsonEncode of the RPC params map
  String payloadJson = '';

  /// SyncStatus: 'pending' | 'synced' | 'failed' | 'conflict'
  String status = '';

  /// Unique UUID per operation for idempotent replay
  String idempotencyKey = '';

  /// Sync order priority (1=highest, default by operationType)
  int priority = 3;

  int retryCount = 0;
  String? errorMessage;
  DateTime createdAt = DateTime.now();
  DateTime? lastAttemptAt;
}
