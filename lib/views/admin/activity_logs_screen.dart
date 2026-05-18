import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/app_strings.dart';
import '../../core/app_session.dart';

class ActivityLogsScreen extends StatefulWidget {
  const ActivityLogsScreen({super.key});

  @override
  State<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends State<ActivityLogsScreen> {
  List<dynamic> _logs = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  static const int _pageSize = 30;

  String? _selectedActionType;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('fr', timeago.FrMessages());
    timeago.setLocaleMessages('ar', timeago.ArMessages());
    _fetchLogs();
  }

  bool get _hasActiveFilters =>
      _selectedActionType != null || _dateFrom != null || _dateTo != null;

  String _getActionLabel(String actionType) {
    switch (actionType) {
      case 'SALE':
        return S.t('label_sale');
      case 'SUPPLY':
        return S.t('label_supply');
      case 'RETURN':
      case 'REFUND_PROCESSED':
        return S.t('label_refund');
      case 'create_employee':
        return S.t('label_create_employee');
      case 'update_employee':
        return S.t('label_update_employee');
      case 'suspend_employee':
        return S.t('label_suspend_employee');
      case 'reactivate_employee':
        return S.t('label_reactivate_employee');
      case 'permanent_delete_employee':
        return S.t('label_permanent_delete_employee');
      case 'delete_employee':
        return S.t('label_delete_employee');
      case 'add_expense':
        return S.t('label_add_expense');
      case 'add_debt_recovery':
        return S.t('label_add_debt_recovery');
      default:
        return actionType;
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
      case 'REFUND_PROCESSED':
        return Icons.keyboard_return;
      case 'CREATE_EMPLOYEE':
        return Icons.person_add;
      case 'UPDATE_EMPLOYEE':
        return Icons.edit;
      case 'SUSPEND_EMPLOYEE':
        return Icons.pause_circle;
      case 'REACTIVATE_EMPLOYEE':
        return Icons.play_circle;
      case 'PERMANENT_DELETE_EMPLOYEE':
        return Icons.delete_forever;
      case 'DELETE_EMPLOYEE':
        return Icons.no_accounts;
      case 'ADD_EXPENSE':
        return Icons.receipt;
      case 'ADD_DEBT_RECOVERY':
        return Icons.payments;
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
      case 'REFUND_PROCESSED':
        return Colors.purple;
      case 'CREATE_EMPLOYEE':
      case 'REACTIVATE_EMPLOYEE':
        return Colors.green;
      case 'UPDATE_EMPLOYEE':
      case 'ADD_DEBT_RECOVERY':
        return Colors.blue;
      case 'SUSPEND_EMPLOYEE':
      case 'ADD_EXPENSE':
        return Colors.orange;
      case 'PERMANENT_DELETE_EMPLOYEE':
      case 'DELETE_EMPLOYEE':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _fetchLogs({bool loadMore = false}) async {
    if (loadMore) {
      if (!_hasMore || _isLoadingMore) return;
      setState(() => _isLoadingMore = true);
      _currentPage++;
    } else {
      setState(() {
        _isLoading = true;
        _currentPage = 0;
        _hasMore = true;
        _logs = [];
      });
    }

    try {
      var query = Supabase.instance.client
          .from('activity_logs')
          .select('*, user_profiles(full_name, role)');

      if (_selectedActionType != null) {
        query = query.eq('action_type', _selectedActionType!);
      }

      if (_dateFrom != null) {
        query = query.gte('created_at', _dateFrom!.toIso8601String());
      }

      if (_dateTo != null) {
        final endOfDay = _dateTo!.add(const Duration(days: 1));
        query = query.lt('created_at', endOfDay.toIso8601String());
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(_currentPage * _pageSize,
              (_currentPage + 1) * _pageSize - 1);

      if (response.length < _pageSize) _hasMore = false;

      if (mounted) {
        setState(() {
          if (loadMore) {
            _logs.addAll(response);
          } else {
            _logs = response;
          }
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching logs: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.t('msg_load_error'))),
        );
      }
    }
  }

  void _resetFilters() {
    setState(() {
      _selectedActionType = null;
      _dateFrom = null;
      _dateTo = null;
    });
    _fetchLogs();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom
          ? (_dateFrom ?? now.subtract(const Duration(days: 30)))
          : (_dateTo ?? now),
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 1)),
      locale: Locale(AppSession.locale.value),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _dateFrom = picked;
        } else {
          _dateTo = picked;
        }
      });
      _fetchLogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(S.t('nav_activity')),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchLogs),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          const Divider(height: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 220,
            child: _buildActionTypeDropdown(),
          ),
          const SizedBox(width: 12),
          _buildDateChip(
            label: '${S.t('label_date_from')}: ${_dateFrom != null ? DateFormat('dd/MM/yyyy').format(_dateFrom!) : '...'}',
            onTap: () => _pickDate(isFrom: true),
            active: _dateFrom != null,
          ),
          const SizedBox(width: 8),
          _buildDateChip(
            label: '${S.t('label_date_to')}: ${_dateTo != null ? DateFormat('dd/MM/yyyy').format(_dateTo!) : '...'}',
            onTap: () => _pickDate(isFrom: false),
            active: _dateTo != null,
          ),
          if (_hasActiveFilters) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: _resetFilters,
              icon: const Icon(Icons.clear_all),
              tooltip: S.t('log_reset_filters'),
            ),
          ],
          const Spacer(),
          Text(
            '${_logs.length} ${S.t('log_results_count')}',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTypeDropdown() {
    final actionTypes = [
      null,
      'SALE',
      'SUPPLY',
      'RETURN',
      'create_employee',
      'update_employee',
      'suspend_employee',
      'reactivate_employee',
      'permanent_delete_employee',
      'delete_employee',
      'add_expense',
      'add_debt_recovery',
      'REFUND_PROCESSED',
    ];

    return InputDecorator(
      decoration: InputDecoration(
        labelText: S.t('log_filter_action'),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _selectedActionType,
          isExpanded: true,
          isDense: true,
          items: actionTypes.map((type) {
            return DropdownMenuItem<String?>(
              value: type,
              child: Text(
                type == null ? S.t('log_all_actions') : _getActionLabel(type),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (val) {
            setState(() => _selectedActionType = val);
            _fetchLogs();
          },
        ),
      ),
    );
  }

  Widget _buildDateChip({
    required String label,
    required VoidCallback onTap,
    required bool active,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? const Color(0xFF1976D2) : Colors.grey.shade300,
          ),
          color: active ? const Color(0xFF1976D2).withValues(alpha: 0.08) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today,
              size: 16,
              color: active ? const Color(0xFF1976D2) : Colors.grey,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: active ? const Color(0xFF1976D2) : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              S.t('log_no_results'),
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: _logs.length + (_hasMore ? 1 : 1),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == _logs.length) {
          return _buildFooter();
        }
        return _buildLogCard(_logs[index]);
      },
    );
  }

  Widget _buildFooter() {
    if (_hasMore) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: _isLoadingMore
              ? const CircularProgressIndicator()
              : OutlinedButton.icon(
                  onPressed: () => _fetchLogs(loadMore: true),
                  icon: const Icon(Icons.expand_more),
                  label: Text(S.t('log_load_more')),
                ),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          S.t('log_no_more'),
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildLogCard(dynamic log) {
    final date = DateTime.parse(log['created_at']);
    final userName = log['user_profiles']?['full_name'] ?? S.t('misc_unknown');
    final role = log['user_profiles']?['role'] ?? '';
    final action = log['action_type'];
    final actionLabel = _getActionLabel(action);

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
              TextSpan(text: ' ${S.t('label_performed_action')}'),
              TextSpan(
                text: ' $actionLabel',
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
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
                    '${timeago.format(date, locale: AppSession.locale.value)}  (${DateFormat('dd/MM/yyyy à HH:mm:ss').format(date.toLocal())})',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
