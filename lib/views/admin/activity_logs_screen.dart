import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/app_session.dart';
import '../../core/app_strings.dart';

class _T {
  _T._();
  static const bgPage = Color(0xFF0A0A14);
  static const bgAppBar = Color(0xFF0F0F1C);
  static const bgCard = Color(0xFF13131F);
  static const bgTable = Color(0xFF0D0D1A);
  static const bgTableHeader = Color(0xFF1A1400);
  static const bgTableRowAlt = Color(0xFF111120);
  static const bgTableHover = Color(0xFF1E1E35);
  static const accentGold = Color(0xFFFFC107);
  static const accentBlue = Color(0xFF58A6FF);
  static const textPrimary = Color(0xFFEEEEFF);
  static const textSecondary = Color(0xFF8888AA);
  static const textMuted = Color(0xFF555570);
  static const borderColor = Color(0xFF1E1E35);
  static const statusPaidBg = Color(0xFF0D2B1A);
  static const statusPaidText = Color(0xFF4ADE80);
  static const statusRefundedBg = Color(0xFF2B1A0D);
  static const statusRefundedText = Color(0xFFFBBF24);
  static const statusUnpaidBg = Color(0xFF2B0D0D);
  static const statusUnpaidText = Color(0xFFF87171);
  static const statusPartialBg = Color(0xFF1A1A0D);
  static const statusPartialText = Color(0xFFFDE68A);
  static const shimmerColor = Color(0xFF252538);
}

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
  bool _isExporting = false;
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
      case 'REACTIVATE_EMPLOYEE':     return _T.statusPaidText;
      case 'SUPPLY':
      case 'IN':
      case 'UPDATE_EMPLOYEE':
      case 'ADD_DEBT_RECOVERY':       return _T.accentBlue;
      case 'UPDATE_TRANSACTION':
      case 'SUSPEND_EMPLOYEE':
      case 'ADD_EXPENSE':             return _T.statusPartialText;
      case 'DELETE_TRANSACTION':
      case 'PERMANENT_DELETE_EMPLOYEE':
      case 'DELETE_EMPLOYEE':         return _T.statusUnpaidText;
      case 'RETURN':
      case 'REFUND_PROCESSED':        return const Color(0xFFC084FC);
      default:                        return _T.textMuted;
    }
  }

  /// Formats activity log description JSON into a readable string.
  String _formatDescription(String raw) {
    if (raw.isEmpty) return '';
    try {
      final d = jsonDecode(raw) as Map<String, dynamic>;
      final actionType = d['action_type'] as String?;
      if (actionType == null) return raw;

      final buf = StringBuffer();
      if (d['products'] != null) buf.write(d['products']);
      if (d['total'] != null) {
        if (buf.isNotEmpty) buf.write(' | ');
        buf.write('${d['total']} DA');
      }
      if (d['payment_method'] != null && d['payment_method'] != '') {
        if (buf.isNotEmpty) buf.write(' | ');
        buf.write(d['payment_method']);
      }
      if (d['remaining_balance'] != null && (d['remaining_balance'] as num) > 0) {
        if (buf.isNotEmpty) buf.write(' | ');
        buf.write('${S.t('label_remaining')}: ${d['remaining_balance']} DA');
      }
      if (d['invoice_number'] != null) {
        buf.write(' (#${d['invoice_number']})');
      }
      if (buf.isEmpty) return raw;
      return buf.toString();
    } catch (_) {
      return raw.length > 60 ? '${raw.substring(0, 60)}…' : raw;
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _T.accentGold,
              onPrimary: _T.bgPage,
              surface: _T.bgCard,
              onSurface: _T.textPrimary,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: _T.bgCard),
          ),
          child: child!,
        );
      },
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

  void _onExport() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final buffer = StringBuffer();
      buffer.writeln('Date,Utilisateur,Action,Description');
      for (final log in _logs) {
        final date = log['created_at']?.toString() ?? '';
        final user = log['user_profiles']?['full_name']?.toString() ?? '';
        final action = log['action_type']?.toString() ?? '';
        final desc = (log['description']?.toString() ?? '').replaceAll('"', '""');
        buffer.writeln('"$date","$user","$action","$desc"');
      }

      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/activity_logs_$timestamp.csv');
      await file.writeAsString(buffer.toString(), encoding: utf8);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: S.t('activity_log_export'),
      );
    } catch (e) {
      debugPrint('[ActivityLogs] Export error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.t('error_export_failed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ─────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bgPage,
      appBar: AppBar(
        title: Text(
          S.t('nav_activity'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _T.textPrimary,
          ),
        ),
        backgroundColor: _T.bgAppBar,
        foregroundColor: _T.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _T.textMuted),
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
      color: _T.bgCard,
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
              style: TextButton.styleFrom(foregroundColor: _T.statusUnpaidText),
            ),

          // Spacer + count + export
          const SizedBox(width: 20),
          Text(
            '$_totalCount ${S.t('log_results_count')}',
            style: const TextStyle(color: _T.textSecondary, fontSize: 13),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _isExporting ? null : _onExport,
            icon: const Icon(Icons.file_download_outlined, size: 16),
            label: Text(_isExporting ? '...' : 'Exporter'),
            style: FilledButton.styleFrom(
              backgroundColor: _T.accentGold,
              foregroundColor: _T.bgPage,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _T.bgTableHeader,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _T.borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _selectedActionType,
          isExpanded: true,
          isDense: true,
          dropdownColor: _T.bgTableHeader,
          icon: const Icon(Icons.unfold_more_rounded,
              color: _T.textMuted, size: 16),
          items: actionTypes.map((type) => DropdownMenuItem<String?>(
            value: type,
            child: Text(
              type == null ? S.t('log_all_actions') : _getActionLabel(type),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: _T.textPrimary),
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
            color: active ? _T.accentGold : _T.borderColor,
          ),
          color: active ? _T.accentGold.withValues(alpha: 0.08) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today, size: 14,
                color: active ? _T.accentGold : _T.textMuted),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: active ? _T.accentGold : _T.textSecondary)),
            if (onClear != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close, size: 14,
                    color: active ? _T.accentGold : _T.textMuted),
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
              ? _T.accentGold
              : _T.borderColor,
        ),
        color: _quickPeriod != QuickPeriod.none
            ? _T.accentGold.withValues(alpha: 0.08)
            : null,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<QuickPeriod>(
          value: _quickPeriod,
          isDense: true,
          dropdownColor: _T.bgTableHeader,
          icon: Icon(Icons.schedule, size: 16,
              color: _quickPeriod != QuickPeriod.none
                  ? _T.accentGold
                  : _T.textMuted),
          style: TextStyle(
            fontSize: 13,
            color: _quickPeriod != QuickPeriod.none
                ? _T.accentGold
                : _T.textSecondary,
          ),
          items: QuickPeriod.values.map((p) => DropdownMenuItem(
            value: p,
            child: Text(p.label(), style: const TextStyle(color: _T.textPrimary)),
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
      return const Center(
        child: CircularProgressIndicator(color: _T.accentGold),
      );
    }
    if (_logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history, size: 48, color: _T.textMuted),
            const SizedBox(height: 14),
            Text(S.t('log_no_results'),
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _T.textSecondary)),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _T.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _T.borderColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
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
      headingRowColor: WidgetStateProperty.all(_T.bgTableHeader),
      headingTextStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 12,
        color: _T.accentGold,
        letterSpacing: 1.0,
      ),
      dataRowMinHeight: 52,
      dataRowMaxHeight: 64,
      columnSpacing: 24,
      horizontalMargin: 20,
      dividerThickness: 0.8,
      border: TableBorder(
        horizontalInside: BorderSide(color: _T.borderColor),
      ),
      columns: const [
        DataColumn(label: Text('DATE / HEURE')),
        DataColumn(label: Text('UTILISATEUR')),
        DataColumn(label: Text('RÔLE')),
        DataColumn(label: Text('ACTION')),
        DataColumn(label: Text('DÉTAILS')),
      ],
      rows: _logs.asMap().entries.map((e) => _buildDataRow(e.value, e.key)).toList(),
    );
  }

  DataRow _buildDataRow(dynamic log, int index) {
    final date     = DateTime.parse(log['created_at']).toLocal();
    final userName = log['user_profiles']?['full_name'] ?? S.t('misc_unknown');
    final role     = log['user_profiles']?['role'] ?? '—';
    final action   = log['action_type'] as String;
    final color    = _getColorForAction(action);
    final icon     = _getIconForAction(action);
    final label    = _getActionLabel(action);

    // Parse description JSON / format for display
    final raw = log['description'] as String? ?? '';
    final shortDesc = _formatDescription(raw);
    final isEven = index.isEven;

    return DataRow(
      color: WidgetStateProperty.all(
        isEven ? _T.bgTable : _T.bgTableRowAlt,
      ),
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
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _T.textPrimary),
              ),
              Text(
                timeago.format(date, locale: AppSession.locale.value),
                style: const TextStyle(fontSize: 11, color: _T.textMuted),
              ),
            ],
          ),
        ),

        // ── User ──────────────────────────
        DataCell(
          Text(userName,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _T.textPrimary)),
        ),

        // ── Role ──────────────────────────
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _T.bgTableHeader,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _T.borderColor),
            ),
            child: Text(role,
                style: const TextStyle(
                    fontSize: 11,
                    color: _T.textSecondary,
                    fontWeight: FontWeight.w500)),
          ),
        ),

        // ── Action chip ───────────────────
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.35)),
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
              style: const TextStyle(fontSize: 12, color: _T.textSecondary),
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
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: _T.bgCard,
        border: Border(top: BorderSide(color: _T.borderColor)),
      ),
      child: Row(
        children: [
          // Rows per page
          const Text('Lignes / page :',
              style: TextStyle(fontSize: 13, color: _T.textSecondary)),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _rowsPerPage,
              isDense: true,
              dropdownColor: _T.bgTableHeader,
              items: _rowsPerPageOptions
                  .map((n) => DropdownMenuItem(
                      value: n,
                      child: Text('$n',
                          style: const TextStyle(
                              fontSize: 13, color: _T.textPrimary))))
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
            style: const TextStyle(fontSize: 13, color: _T.textSecondary),
          ),

          const Spacer(),

          // Prev button
          _pageButton(
            icon: Icons.chevron_left_rounded,
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
            icon: Icons.chevron_right_rounded,
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
          child: Text('…',
              style: TextStyle(
                  color: _T.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
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
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isSelected ? _T.accentGold : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? _T.accentGold : _T.borderColor,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '${p + 1}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? _T.bgPage : _T.textSecondary,
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
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _T.borderColor),
        ),
        child: Opacity(
          opacity: enabled ? 1.0 : 0.3,
          child: Icon(icon, size: 18, color: _T.textPrimary),
        ),
      ),
    );
  }
}