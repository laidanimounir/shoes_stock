import 'package:flutter/material.dart';
import '../../core/app_session.dart';
import '../../core/app_strings.dart';
import '../../services/expense_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

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

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;
  String? _filterCategoryId;

  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final storeId = AppSession.currentStoreId;
    if (storeId == null) return;

    final cats = await ExpenseService.instance.fetchCategories(storeId);
    final exps = await ExpenseService.instance.fetchExpenses(
      storeId,
      from: _dateFrom,
      to: _dateTo,
      categoryId: _filterCategoryId,
    );

    if (mounted) {
      setState(() {
        _categories = cats;
        _expenses = exps;
        _isLoading = false;
      });
    }
  }

  // ══════════════════════════════════════════
  // Stats
  // ══════════════════════════════════════════

  double get _totalMonth {
    final now = DateTime.now();
    return _expenses
        .where((e) {
          final d = DateTime.tryParse(e['expense_date'] ?? '');
          return d != null && d.month == now.month && d.year == now.year;
        })
        .fold(0.0, (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0));
  }

  int get _countMonth {
    final now = DateTime.now();
    return _expenses.where((e) {
      final d = DateTime.tryParse(e['expense_date'] ?? '');
      return d != null && d.month == now.month && d.year == now.year;
    }).length;
  }

  double get _maxExpense {
    if (_expenses.isEmpty) return 0;
    return _expenses
        .map((e) => (e['amount'] as num?)?.toDouble() ?? 0)
        .reduce((a, b) => a > b ? a : b);
  }

  // ══════════════════════════════════════════
  // Add Expense Dialog
  // ══════════════════════════════════════════

  InputDecoration _fieldDecoration({required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _T.textSecondary, fontSize: 13),
      prefixIcon: Icon(icon, color: _T.textMuted),
      filled: true,
      fillColor: _T.bgTableHeader,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _T.borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _T.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _T.accentGold),
      ),
    );
  }

  void _showAddExpenseDialog() {
    final formKey = GlobalKey<FormState>();
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? selectedCatId = _categories.isNotEmpty ? _categories.first['id'] : null;
    String selectedMethod = 'cash';
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: _T.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(S.t('exp_add'), style: AppTextStyles.bodyMedium(color: _T.textPrimary)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedCatId,
                    dropdownColor: _T.bgTableHeader,
                    style: const TextStyle(color: _T.textPrimary, fontSize: 14),
                    decoration: _fieldDecoration(label: S.t('exp_category'), icon: Icons.category),
                    items: _categories
                        .map((c) => DropdownMenuItem(
                              value: c['id'] as String,
                              child: Text(c['name'] as String),
                            ))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedCatId = v),
                    validator: (v) => v == null ? S.t('msg_required') : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: amountCtrl,
                    style: const TextStyle(color: _T.textPrimary),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _fieldDecoration(label: S.t('exp_amount'), icon: Icons.attach_money),
                    validator: (v) {
                      if (v == null || v.isEmpty) return S.t('msg_required');
                      if (double.tryParse(v) == null || double.parse(v) <= 0) return S.t('msg_invalid_amount');
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descCtrl,
                    style: const TextStyle(color: _T.textPrimary),
                    decoration: _fieldDecoration(label: S.t('label_description'), icon: Icons.description),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedMethod,
                    dropdownColor: _T.bgTableHeader,
                    style: const TextStyle(color: _T.textPrimary, fontSize: 14),
                    decoration: _fieldDecoration(label: S.t('label_method'), icon: Icons.payment),
                    items: [
                      DropdownMenuItem(value: 'cash', child: Text(S.t('label_cash'))),
                      DropdownMenuItem(value: 'bank', child: Text(S.t('label_bank'))),
                      DropdownMenuItem(value: 'mobile', child: Text(S.t('label_mobile'))),
                    ],
                    onChanged: (v) => setDialogState(() => selectedMethod = v ?? 'cash'),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: _T.bgTableHeader,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _T.borderColor),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: const Icon(Icons.calendar_today, color: _T.accentGold),
                      title: Text(
                        '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                        style: AppTextStyles.bodyMedium(color: _T.textPrimary),
                      ),
                      subtitle: Text(S.t('exp_date'),
                          style: const TextStyle(color: _T.textMuted, fontSize: 11)),
                      trailing: TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
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
                            setDialogState(() => selectedDate = picked);
                          }
                        },
                        child: Text(S.t('exp_change_date'),
                            style: const TextStyle(color: _T.accentGold)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(S.t('action_cancel'), style: const TextStyle(color: _T.textSecondary)),
            ),
            Container(
              margin: const EdgeInsets.only(right: 8, bottom: 4),
              child: ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  Navigator.pop(ctx);

                  try {
                    await ExpenseService.instance.addExpense(
                      storeId: AppSession.currentStoreId!,
                      categoryId: selectedCatId,
                      amount: double.parse(amountCtrl.text),
                      description: descCtrl.text.trim(),
                      paymentMethod: selectedMethod,
                      expenseDate: selectedDate,
                    );
                    _loadData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(S.t('exp_recorded')),
                          backgroundColor: _T.statusPaidBg,
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.all(12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Erreur: $e'),
                          backgroundColor: _T.statusUnpaidText,
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.all(12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _T.accentGold,
                  foregroundColor: _T.bgPage,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(S.t('action_save')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  // Category Manager Dialog
  // ══════════════════════════════════════════

  void _showCategoryManagerDialog() {
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: _T.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(S.t('exp_category_title'), style: AppTextStyles.bodyMedium(color: _T.textPrimary)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: _T.bgTableHeader,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _T.borderColor),
                        ),
                        child: TextField(
                          controller: nameCtrl,
                          style: const TextStyle(color: _T.textPrimary, fontSize: 14),
                          cursorColor: _T.accentGold,
                          decoration: InputDecoration(
                            hintText: S.t('exp_category_hint'),
                            hintStyle: const TextStyle(color: _T.textMuted, fontSize: 13),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty) return;
                        try {
                          await ExpenseService.instance.addCategory(
                            name: nameCtrl.text.trim(),
                            storeId: AppSession.currentStoreId!,
                          );
                          nameCtrl.clear();
                          final cats = await ExpenseService.instance.fetchCategories(AppSession.currentStoreId!);
                          setDialogState(() {});
                          setState(() => _categories = cats);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${S.t('msg_error')}: $e'),
                                backgroundColor: _T.statusUnpaidText,
                                behavior: SnackBarBehavior.floating,
                                margin: const EdgeInsets.all(12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _T.accentGold,
                        foregroundColor: _T.bgPage,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(S.t('action_add')),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: _T.borderColor),
                SizedBox(
                  height: 200,
                  child: _categories.isEmpty
                      ? Center(
                          child: Text(S.t('misc_no_results'),
                              style: const TextStyle(color: _T.textMuted)))
                      : ListView.separated(
                          itemCount: _categories.length,
                          separatorBuilder: (_, __) => const Divider(color: _T.borderColor, height: 1),
                          itemBuilder: (_, i) {
                            final cat = _categories[i];
                            return ListTile(
                              leading: const Icon(Icons.label, color: _T.accentGold),
                              title: Text(cat['name'] as String,
                                  style: const TextStyle(color: _T.textPrimary)),
                              dense: true,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(S.t('action_close'), style: const TextStyle(color: _T.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  // Date Range Picker
  // ══════════════════════════════════════════

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateFrom != null && _dateTo != null
          ? DateTimeRange(start: _dateFrom!, end: _dateTo!)
          : null,
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
        _dateFrom = picked.start;
        _dateTo = picked.end;
      });
      _loadData();
    }
  }

  // ══════════════════════════════════════════
  // Helpers
  // ══════════════════════════════════════════

  IconData _methodIcon(String? method) {
    switch (method) {
      case 'bank':
        return Icons.account_balance;
      case 'mobile':
        return Icons.phone_android;
      default:
        return Icons.money;
    }
  }

  String _methodLabel(String? method) {
    switch (method) {
      case 'bank':
        return S.t('label_bank');
      case 'mobile':
        return S.t('label_mobile');
      default:
        return S.t('label_cash');
    }
  }

  // ══════════════════════════════════════════
  // Build
  // ══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bgPage,
      appBar: AppBar(
        title: Text(
          S.t('exp_title'),
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
            icon: const Icon(Icons.category, color: _T.textMuted),
            tooltip: S.t('exp_manage_categories'),
            onPressed: _showCategoryManagerDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpenseDialog,
        backgroundColor: _T.accentGold,
        foregroundColor: _T.bgPage,
        elevation: 0,
        icon: const Icon(Icons.add),
        label: Text(S.t('exp_add'),
            style: AppTextStyles.bodyMedium(color: _T.bgPage)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _T.accentGold))
          : Column(
              children: [
                // ── Summary Cards ──
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _buildStatCard(S.t('exp_month_total'), '${_totalMonth.toStringAsFixed(2)} DA',
                          Icons.trending_down, _T.statusUnpaidText),
                      const SizedBox(width: 12),
                      _buildStatCard(S.t('exp_count'), '$_countMonth ${S.t('exp_expenses_label')}',
                          Icons.receipt_long, _T.accentBlue),
                      const SizedBox(width: 12),
                      _buildStatCard(S.t('exp_max'), '${_maxExpense.toStringAsFixed(2)} DA',
                          Icons.arrow_upward, _T.statusPartialText),
                    ],
                  ),
                ),

                // ── Filters ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickDateRange,
                        icon: const Icon(Icons.date_range, size: 18, color: _T.textSecondary),
                        label: Text(
                          _dateFrom != null
                              ? '${_dateFrom!.day}/${_dateFrom!.month} → ${_dateTo!.day}/${_dateTo!.month}'
                              : S.t('exp_period'),
                          style: AppTextStyles.bodyMedium(color: _T.textSecondary),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _T.borderColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      if (_dateFrom != null) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18, color: _T.textMuted),
                          onPressed: () {
                            setState(() { _dateFrom = null; _dateTo = null; });
                            _loadData();
                          },
                        ),
                      ],
                      const SizedBox(width: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Wrap(
                            spacing: 8,
                            children: [
                              _buildFilterChip(
                                label: S.t('exp_all_categories'),
                                selected: _filterCategoryId == null,
                                onSelected: () {
                                  setState(() => _filterCategoryId = null);
                                  _loadData();
                                },
                              ),
                              ..._categories.map((c) => _buildFilterChip(
                                    label: c['name'] as String,
                                    selected: _filterCategoryId == c['id'],
                                    onSelected: () {
                                      setState(() => _filterCategoryId =
                                          _filterCategoryId == c['id'] ? null : c['id'] as String);
                                      _loadData();
                                    },
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ── Expense List ──
                Expanded(
                  child: _expenses.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.receipt_long, size: 48, color: _T.textMuted),
                              const SizedBox(height: 14),
                              Text(S.t('exp_no_results'),
                                  style: AppTextStyles.bodyMedium(color: _T.textSecondary)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _expenses.length,
                          itemBuilder: (context, index) {
                            final e = _expenses[index];
                            final amount = (e['amount'] as num?)?.toDouble() ?? 0;
                            final catName = e['expense_categories']?['name'] as String? ?? S.t('exp_no_category');
                            final desc = e['description'] as String? ?? '';
                            final method = e['payment_method'] as String? ?? 'cash';
                            final dateStr = e['expense_date'] as String? ?? '';
                            final isEven = index.isEven;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isEven ? _T.bgTable : _T.bgTableRowAlt,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _T.borderColor),
                              ),
                              child: ListTile(
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _T.statusUnpaidBg,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Icon(_methodIcon(method), color: _T.statusUnpaidText),
                                ),
                                title: Text(
                                  desc.isNotEmpty ? desc : catName,
                                  style: AppTextStyles.bodyMedium(color: _T.textPrimary),
                                ),
                                subtitle: Text(
                                  '$catName · ${_methodLabel(method)}',
                                  style: AppTextStyles.bodyMedium(color: _T.textSecondary),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${amount.toStringAsFixed(2)} DA',
                                      style: AppTextStyles.bodyMedium(color: _T.statusUnpaidText),
                                    ),
                                    Text(dateStr, style: const TextStyle(color: _T.textMuted)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _T.accentGold : _T.bgTableHeader,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _T.accentGold : _T.borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? _T.bgPage : _T.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _T.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _T.borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.bodyMedium(color: _T.textSecondary)),
                  const SizedBox(height: 4),
                  Text(value,
                      style: AppTextStyles.bodyMedium(color: color),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}