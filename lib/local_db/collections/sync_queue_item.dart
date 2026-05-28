import 'package:isar/isar.dart';

part 'sync_queue_item.g.dart';

/// Offline operation queue — each row is one pending RPC call to replay
/// when connectivity is restored.
@Collection()
class SyncQueueItem {
  Id isarId = Isar.autoIncrement;

  /// SyncOperationType.toSupabaseString()
  late String operationType;

  /// jsonEncode of the RPC params map
  late String payloadJson;

  /// SyncStatus: 'pending' | 'synced' | 'failed' | 'conflict'
  late String status;

  /// Unique UUID per operation for idempotent replay
  late String idempotencyKey;

  /// Sync order priority (1=highest, default by operationType)
  int priority = 3;

  int retryCount = 0;
  String? errorMessage;
  late DateTime createdAt;
  DateTime? lastAttemptAt;
}
