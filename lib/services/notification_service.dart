import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_session.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final ValueNotifier<int> unreadCount = ValueNotifier(0);
  List<Map<String, dynamic>> _notifications = [];
  Timer? _pollTimer;

  void startPolling() {
    _poll();
    _pollTimer = Timer.periodic(const Duration(minutes: 5), (_) => _poll());
  }

  void stopPolling() {
    _pollTimer?.cancel();
  }

  Future<void> _poll() async {
    try {
      final res = await Supabase.instance.client.rpc(
        'get_unread_notifications',
        params: {
          'p_store_id': AppSession.currentStoreId,
          'p_user_id': AppSession.currentUserId,
        },
      );
      unreadCount.value = (res['unread_count'] as num?)?.toInt() ?? 0;
      _notifications = List<Map<String, dynamic>>.from(res['notifications'] ?? []);
    } catch (_) {}
  }

  List<Map<String, dynamic>> get notifications => _notifications;

  Future<void> markRead(List<String> ids) async {
    await Supabase.instance.client.rpc(
      'mark_notifications_read',
      params: {'p_notification_ids': ids},
    );
    await _poll();
  }

  Future<void> markAllRead() async {
    final ids = _notifications
        .where((n) => n['is_read'] == false)
        .map((n) => n['id'] as String)
        .toList();
    if (ids.isNotEmpty) await markRead(ids);
  }
}
