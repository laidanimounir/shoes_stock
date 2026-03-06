import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

class ActivityLogsScreen extends StatefulWidget {
  const ActivityLogsScreen({super.key});

  @override
  State<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends State<ActivityLogsScreen> {
  List<dynamic> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('fr', timeago.FrMessages());
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('activity_logs')
          .select('*, user_profiles(full_name, role)')
          .order('created_at', ascending: false)
          .limit(100);

      if (mounted) {
        setState(() {
          _logs = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching logs: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _getIconForAction(String action) {
    switch (action.toUpperCase()) {
      case 'SALE':
      case 'OUT':
        return Icons.shopping_cart_checkout;
      case 'SUPPLY':
      case 'IN':
        return Icons.inventory;
      case 'UPDATE_TRANSACTION':
        return Icons.edit;
      case 'DELETE_TRANSACTION':
        return Icons.delete_forever;
      case 'RETURN':
        return Icons.keyboard_return;
      default:
        return Icons.history;
    }
  }

  Color _getColorForAction(String action) {
     switch (action.toUpperCase()) {
      case 'SALE':
      case 'OUT':
        return Colors.green;
      case 'SUPPLY':
      case 'IN':
        return Colors.blue;
      case 'UPDATE_TRANSACTION':
        return Colors.orange;
      case 'DELETE_TRANSACTION':
        return Colors.red;
      case 'RETURN':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Journaux d\'activité'),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchLogs),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(child: Text('Aucune activité enregistrée.', style: TextStyle(fontSize: 18, color: Colors.grey)))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  itemCount: _logs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    final date = DateTime.parse(log['created_at']);
                    final userName = log['user_profiles']?['full_name'] ?? 'Inconnu';
                    final role = log['user_profiles']?['role'] ?? '';
                    final action = log['action_type'];
                    
                    final icon = _getIconForAction(action);
                    final color = _getColorForAction(action);

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.1),
                          child: Icon(icon, color: color),
                        ),
                        title: RichText(
                          text: TextSpan(
                            style: const TextStyle(color: Colors.black87, fontSize: 16),
                            children: [
                              TextSpan(text: userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              TextSpan(text: ' ($role) ', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                              const TextSpan(text: 'a effectué une action: '),
                              TextSpan(text: action, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(log['description'], style: const TextStyle(fontSize: 14, color: Colors.black87)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.access_time, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    timeago.format(date, locale: 'fr'),
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '(${date.toLocal().toString().split('.')[0]})',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  )
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
