import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/app_strings.dart';
import '../../core/app_session.dart';

// ─────────────────────────────────────────────
//  Période rapide
// ─────────────────────────────────────────────
enum QuickPeriod {
  none,
  lastHour,
  last6Hours,
  today,
  thisWeek,
  thisMonth,
}

extension QuickPeriodLabel on QuickPeriod {
  String label() {
    switch (this) {
      case QuickPeriod.none:
        return 'Toutes les périodes';
      case QuickPeriod.lastHour:
        return 'Dernière heure';
      case QuickPeriod.last6Hours:
        return 'Dernières 6 heures';
      case QuickPeriod.today:
        return "Aujourd'hui";
      case QuickPeriod.thisWeek:
        return 'Cette semaine';
      case QuickPeriod.thisMonth:
        return 'Ce mois';
    }
  }

  /// Returns [from, to] based on now. `to` is always null (open-ended).
  DateTime? get fromDate {
    final now = DateTime.now();
    switch (this) {
      case QuickPeriod.none:
        return null;
      case QuickPeriod.lastHour:
        return now.subtract(const Duration(hours: 1));
      case QuickPeriod.last6Hours:
        return now.subtract(const Duration(hours: 6));
      case QuickPeriod.today:
        return DateTime(now.year, now.month, now.day);
      case QuickPeriod.thisWeek:
        return now.subtract(Duration(days: now.weekday - 1));
      case QuickPeriod.thisMonth:
        return DateTime(now.year, now.month, 1);
    }
  }
}

// ─────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────
class ActivityLogsScreen extends StatefulWidget {
  const ActivityLogsScreen({super.key});

  @override
  State<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends State<ActivityLogsScreen> {
  // ── data ──────────────────────────────────
  List<dynamic> _logs = [];
  bool _isLoading = false;
  int _totalCount = 0;

  // ── pagination ────────────────────────────
  int _currentPage = 0;
  int _rowsPerPage = 20;
  final List<int> _rowsPerPageOptions = [10, 20, 30, 50];

  // ── filters ───────────────────────────────
  String? _selectedActionType;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  QuickPeriod _quickPeriod = QuickPeriod.none;

  // ── theme ─────────────────────────────────
  static const Color _primary = Color(0xFF37474F);   // blue-grey 800
  static const Color _accent  = Color(0xFF1976D2);   // blue 700
  static const Color _bg      = Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('fr', timeago.FrMessages());
    timeago.setLocaleMessages('ar', timeago.ArMessages());
    _fetchLogs();
  }

  // ─────────────────────────────────────────
  //  Helpers
  // ─────────────────────────────────────────
  bool get _hasActiveFilters =>
      _selectedActionType != null ||
      _dateFrom != null ||
      _dateTo != null ||
      _quickPeriod != QuickPeriod.none;

  String _getActionLabel(String actionType) {
    switch (actionType) {
      case 'SALE':            return S.t('label_sale');
      case 'SUPPLY':          return S.t('label_supply');
      case 'RETURN':
      case 'REFUND_PROCESSED':return S.t('label_refund');
      case 'create_employee': return S.t('label_create_employee');
      case 'update_employee': return S.t('label_update_employee');
      case 'suspend_employee':return S.t('label_suspend_employee');
      case 'reactivate_employee': return S.t('label_reactivate_employee');
      case 'permanent_delete_employee': return S.t('label_permanent_delete_employee');
      case 'delete_employee': return S.t('label_delete_employee');
      case 'add_expense':     return S.t('label_add_expense');
      case 'add_debt_recovery': return S.t('label_add_debt_recovery');
      default:                return actionType;
    }
  }

  IconData _getIconForAction(String action) {
    switch (action.toUpperCase()) {
      case 'SALE':
      case 'OUT':                      return Icons.shopping_cart_checkout;
      case 'SUPPLY':
      case 'IN':                       return Icons.inventory;
      case 'UPDATE_TRANSACTION':       return Icons.edit;
      case 'DELETE_TRANSACTION':       return Icons.delete_forever;
      case 'RETURN':
      case 'REFUND_PROCESSED':         return Icons.keyboard_return;
      case 'CREATE_EMPLOYEE':          return Icons.person_add;
      case 'UPDATE_EMPLOYEE':          return Icons.edit;
      case 'SUSPEND_EMPLOYEE':         return Icons.pause_circle;
      case 'REACTIVATE_EMPLOYEE':      return Icons.play_circle;
      case 'PERMANENT_DELETE_EMPLOYEE':return Icons.delete_forever;
      case 'DELETE_EMPLOYEE':          return Icons.no_accounts;
      case 'ADD_EXPENSE':              return Icons.receipt;
      case 'ADD_DEBT_RECOVERY':        return Icons.payments;
      default:                         return Icons.history;
    }
  }

  Color _getColorForAction(String action) {
    switch (action.toUpperCase()) {
      case 'SALE':
      case 'OUT':
      case 'CREATE_EMPLOYEE':
      case 'REACTIVATE_EMPLOYEE':     return Colors.green;
      case 'SUPPLY':
      case 'IN':
      case 'UPDATE_EMPLOYEE':
      case 'ADD_DEBT_RECOVERY':       return Colors.blue;
      case 'UPDATE_TRANSACTION':
      case 'SUSPEND_EMPLOYEE':
      case 'ADD_EXPENSE':             return Colors.orange;
      case 'DELETE_TRANSACTION':
      case 'PERMANENT_DELETE_EMPLOYEE':
      case 'DELETE_EMPLOYEE':         return Colors.red;
      case 'RETURN':
      case 'REFUND_PROCESSED':        return Colors.purple;
      default:                        return Colors.grey;
    }
  }

  // ─────────────────────────────────────────
  //  Data fetching
  // ─────────────────────────────────────────

  /// Resolves effective dateFrom considering QuickPeriod.
  DateTime? get _effectiveDateFrom =>
      _quickPeriod != QuickPeriod.none ? _quickPeriod.fromDate : _dateFrom;

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);

    try {
      // ── count query ──────────────────────
      var countQuery = Supabase.instance.client
          .from('activity_logs')
          .select('id');

      countQuery = _applyFilters(countQuery);
      final countRes = await countQuery;
      final total = (countRes as List).length;

      // ── data query ───────────────────────
      var dataQuery = Supabase.instance.client
          .from('activity_logs')
          .select('*, user_profiles(full_name, role)');

      dataQuery = _applyFilters(dataQuery);

      final from = _currentPage * _rowsPerPage;
      final to   = from + _rowsPerPage - 1;

      final response = await dataQuery
          .order('created_at', ascending: false)
          .range(from, to);

      if (mounted) {
        setState(() {
          _logs = response;
          _totalCount = total;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching logs: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.t('msg_load_error'))),
        );
      }
    }
  }

  dynamic _applyFilters(dynamic query) {
    if (_selectedActionType != null) {
      query = query.eq('action_type', _selectedActionType!);
    }
    final from = _effectiveDateFrom;
    if (from != null) {
      query = query.gte('created_at', from.toIso8601String());
    }
    if (_dateTo != null && _quickPeriod == QuickPeriod.none) {
      final endOfDay = _dateTo!.add(const Duration(days: 1));
      query = query.lt('created_at', endOfDay.toIso8601String());
    }
    return query;
  }

  void _resetFilters() {
    setState(() {
      _selectedActionType = null;
      _dateFrom = null;
      _dateTo = null;
      _quickPeriod = QuickPeriod.none;
      _currentPage = 0;
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
          _quickPeriod = QuickPeriod.none;
        } else {
          _dateTo = picked;
          _quickPeriod = QuickPeriod.none;
        }
        _currentPage = 0;
      });
      _fetchLogs();
    }
  }

  void _onExport() {
    // TODO: implement export logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export — à implémenter')),
    );
  }

  // ─────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(S.t('nav_activity')),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchLogs,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          const SizedBox(height: 8),
          Expanded(child: _buildTableSection()),
          _buildPaginationBar(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  //  Filter bar
  // ─────────────────────────────────────────
  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Action type
          SizedBox(width: 200, child: _buildActionDropdown()),

          // Date from
          _buildDateChip(
            label: _dateFrom != null
                ? 'Du: ${DateFormat('dd/MM/yy').format(_dateFrom!)}'
                : 'Du: ...',
            active: _dateFrom != null,
            onTap: () => _pickDate(isFrom: true),
            onClear: _dateFrom != null
                ? () { setState(() { _dateFrom = null; _currentPage = 0; }); _fetchLogs(); }
                : null,
          ),

          // Date to
          _buildDateChip(
            label: _dateTo != null
                ? 'Au: ${DateFormat('dd/MM/yy').format(_dateTo!)}'
                : 'Au: ...',
            active: _dateTo != null,
            onTap: () => _pickDate(isFrom: false),
            onClear: _dateTo != null
                ? () { setState(() { _dateTo = null; _currentPage = 0; }); _fetchLogs(); }
                : null,
          ),

          // Quick period
          _buildPeriodDropdown(),

          // Reset
          if (_hasActiveFilters)
            TextButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.clear_all, size: 16),
              label: const Text('Réinitialiser'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),

          // Spacer + count + export
          const SizedBox(width: 20),
          Text(
            '$_totalCount ${S.t('log_results_count')}',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _onExport,
            icon: const Icon(Icons.file_download_outlined, size: 16),
            label: const Text('Exporter'),
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionDropdown() {
    final actionTypes = [
      null,
      'SALE', 'SUPPLY', 'RETURN',
      'create_employee', 'update_employee', 'suspend_employee',
      'reactivate_employee', 'permanent_delete_employee',
      'delete_employee', 'add_expense', 'add_debt_recovery',
      'REFUND_PROCESSED',
    ];
    return InputDecorator(
      decoration: InputDecoration(
        labelText: S.t('log_filter_action'),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _selectedActionType,
          isExpanded: true,
          isDense: true,
          items: actionTypes.map((type) => DropdownMenuItem<String?>(
            value: type,
            child: Text(
              type == null ? S.t('log_all_actions') : _getActionLabel(type),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          )).toList(),
          onChanged: (val) {
            setState(() { _selectedActionType = val; _currentPage = 0; });
            _fetchLogs();
          },
        ),
      ),
    );
  }

  Widget _buildDateChip({
    required String label,
    required bool active,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? _accent : Colors.grey.shade300,
          ),
          color: active ? _accent.withOpacity(0.08) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today, size: 14,
                color: active ? _accent : Colors.grey),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: active ? _accent : Colors.grey.shade700)),
            if (onClear != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close, size: 14,
                    color: active ? _accent : Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _quickPeriod != QuickPeriod.none
              ? _accent
              : Colors.grey.shade300,
        ),
        color: _quickPeriod != QuickPeriod.none
            ? _accent.withOpacity(0.08)
            : null,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<QuickPeriod>(
          value: _quickPeriod,
          isDense: true,
          icon: Icon(Icons.schedule, size: 16,
              color: _quickPeriod != QuickPeriod.none ? _accent : Colors.grey),
          style: TextStyle(
            fontSize: 13,
            color: _quickPeriod != QuickPeriod.none
                ? _accent
                : Colors.grey.shade700,
          ),
          items: QuickPeriod.values.map((p) => DropdownMenuItem(
            value: p,
            child: Text(p.label()),
          )).toList(),
          onChanged: (val) {
            if (val == null) return;
            setState(() {
              _quickPeriod = val;
              // clear manual dates when using quick period
              if (val != QuickPeriod.none) {
                _dateFrom = null;
                _dateTo = null;
              }
              _currentPage = 0;
            });
            _fetchLogs();
          },
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  //  Table section
  // ─────────────────────────────────────────
  Widget _buildTableSection() {
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
            Text(S.t('log_no_results'),
                style: const TextStyle(fontSize: 18, color: Colors.grey)),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _buildDataTable(),
          ),
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    return DataTable(
      headingRowColor: WidgetStateProperty.all(
        const Color(0xFFF0F4F8),
      ),
      headingTextStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: Color(0xFF37474F),
      ),
      dataRowMinHeight: 52,
      dataRowMaxHeight: 64,
      columnSpacing: 24,
      horizontalMargin: 20,
      dividerThickness: 0.8,
      columns: const [
        DataColumn(label: Text('Date / Heure')),
        DataColumn(label: Text('Utilisateur')),
        DataColumn(label: Text('Rôle')),
        DataColumn(label: Text('Action')),
        DataColumn(label: Text('Détails')),
      ],
      rows: _logs.map((log) => _buildDataRow(log)).toList(),
    );
  }

  DataRow _buildDataRow(dynamic log) {
    final date     = DateTime.parse(log['created_at']).toLocal();
    final userName = log['user_profiles']?['full_name'] ?? S.t('misc_unknown');
    final role     = log['user_profiles']?['role'] ?? '—';
    final action   = log['action_type'] as String;
    final color    = _getColorForAction(action);
    final icon     = _getIconForAction(action);
    final label    = _getActionLabel(action);

    // Shorten description / JSON for table display
    final raw = log['description'] as String? ?? '';
    final shortDesc = raw.length > 60 ? '${raw.substring(0, 60)}…' : raw;

    return DataRow(
      cells: [
        // ── Date ──────────────────────────
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('dd/MM/yy HH:mm').format(date),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Text(
                timeago.format(date, locale: AppSession.locale.value),
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),

        // ── User ──────────────────────────
        DataCell(
          Text(userName,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500)),
        ),

        // ── Role ──────────────────────────
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blueGrey.shade100),
            ),
            child: Text(role,
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.blueGrey.shade600,
                    fontWeight: FontWeight.w500)),
          ),
        ),

        // ── Action chip ───────────────────
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 5),
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),

        // ── Details ───────────────────────
        DataCell(
          Tooltip(
            message: raw,
            child: Text(
              shortDesc.isEmpty ? '—' : shortDesc,
              style: TextStyle(
                  fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────
  //  Pagination bar
  // ─────────────────────────────────────────
  Widget _buildPaginationBar() {
    final totalPages =
        (_totalCount / _rowsPerPage).ceil().clamp(1, 99999);
    final firstItem = _totalCount == 0 ? 0 : _currentPage * _rowsPerPage + 1;
    final lastItem  =
        ((_currentPage + 1) * _rowsPerPage).clamp(0, _totalCount);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          // Rows per page
          const Text('Lignes / page :',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _rowsPerPage,
              isDense: true,
              items: _rowsPerPageOptions
                  .map((n) => DropdownMenuItem(
                      value: n,
                      child: Text('$n',
                          style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (val) {
                if (val == null) return;
                setState(() {
                  _rowsPerPage = val;
                  _currentPage = 0;
                });
                _fetchLogs();
              },
            ),
          ),

          const SizedBox(width: 24),
          Text(
            'Affichage $firstItem–$lastItem sur $_totalCount',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),

          const Spacer(),

          // Prev button
          _pageButton(
            icon: Icons.chevron_left,
            enabled: _currentPage > 0,
            onTap: () {
              setState(() => _currentPage--);
              _fetchLogs();
            },
          ),

          // Page numbers
          ..._buildPageNumbers(totalPages),

          // Next button
          _pageButton(
            icon: Icons.chevron_right,
            enabled: _currentPage < totalPages - 1,
            onTap: () {
              setState(() => _currentPage++);
              _fetchLogs();
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers(int totalPages) {
    // Show at most 5 page buttons around current page
    final pages = <int>[];

    if (totalPages <= 7) {
      pages.addAll(List.generate(totalPages, (i) => i));
    } else {
      pages.add(0);
      final start = (_currentPage - 1).clamp(1, totalPages - 3);
      final end   = (_currentPage + 1).clamp(2, totalPages - 2);

      if (start > 1) pages.add(-1); // ellipsis
      for (var i = start; i <= end; i++) pages.add(i);
      if (end < totalPages - 2) pages.add(-1); // ellipsis
      pages.add(totalPages - 1);
    }

    return pages.map((p) {
      if (p == -1) {
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('…', style: TextStyle(color: Colors.grey)),
        );
      }
      final isSelected = p == _currentPage;
      return GestureDetector(
        onTap: isSelected
            ? null
            : () {
                setState(() => _currentPage = p);
                _fetchLogs();
              },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: isSelected ? _accent : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? _accent : Colors.grey.shade300,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '${p + 1}',
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _pageButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
          color: enabled ? null : Colors.grey.shade100,
        ),
        alignment: Alignment.center,
        child: Icon(icon,
            size: 18,
            color: enabled ? Colors.grey.shade700 : Colors.grey.shade400),
      ),
    );
  }
}