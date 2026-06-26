import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/app_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('fr', timeago.FrMessages());
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'low_stock':
        return Icons.warning_amber_rounded;
      case 'overdue_debt':
        return Icons.money_off;
      case 'sale':
        return Icons.shopping_cart;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'low_stock':
        return Colors.orange;
      case 'overdue_debt':
        return Colors.red;
      case 'sale':
        return Colors.green;
      default:
        return AppColors.desktopPrimary;
    }
  }

  String _ago(dynamic dt) {
    if (dt == null) return '';
    final date = DateTime.tryParse(dt.toString());
    if (date == null) return '';
    return timeago.format(date, locale: 'fr');
  }

  @override
  Widget build(BuildContext context) {
    final service = NotificationService.instance;
    final notifs = service.notifications;

    return Scaffold(
      appBar: AppBar(
        title: Text(S.t('notif_title')),
        backgroundColor: AppColors.desktopSurface,
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: () async {
              await service.markAllRead();
              if (mounted) setState(() {});
            },
            icon: const Icon(Icons.done_all, color: Colors.white70),
            label: Text(
              S.t('notif_mark_all_read'),
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
      body: notifs.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_off_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    S.t('notif_no_notifications'),
                    style: TextStyle(
                        fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: notifs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final n = notifs[index];
                final type = (n['type'] as String?) ?? '';
                final isRead = n['is_read'] == true;
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _colorForType(type).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _iconForType(type),
                      color: _colorForType(type),
                      size: 22,
                    ),
                  ),
                  title: Text(
                    n['title'] ?? '',
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((n['body'] as String?)?.isNotEmpty == true)
                        Text(
                          n['body'],
                          style: TextStyle(
                              color: Colors.grey[600]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 2),
                      Text(
                        _ago(n['created_at']),
                        style: TextStyle(
                            color: Colors.grey[400]),
                      ),
                    ],
                  ),
                  trailing: isRead
                      ? null
                      : Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.blueAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                  onTap: () async {
                    if (!isRead) {
                      await service.markRead([n['id'] as String]);
                      if (mounted) setState(() {});
                    }
                  },
                );
              },
            ),
    );
  }
}
