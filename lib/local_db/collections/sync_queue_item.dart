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

  /// SyncStatus: 'pending' | 'synced' | 'failed'
  late String status;

  int retryCount = 0;
  String? errorMessage;
  late DateTime createdAt;
  DateTime? lastAttemptAt;
}
