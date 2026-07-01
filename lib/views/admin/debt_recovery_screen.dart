import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_session.dart';
import '../../core/app_strings.dart';
import '../../services/debt_recovery_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../shared/utils/contact_utils.dart';

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

class DebtRecoveryScreen extends StatefulWidget {
  const DebtRecoveryScreen({super.key});

  @override
  State<DebtRecoveryScreen> createState() => _DebtRecoveryScreenState();
}

class _DebtRecoveryScreenState extends State<DebtRecoveryScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _allCustomers = [];
  List<Map<String, dynamic>> _overdueCustomers = [];
  bool _isLoading = true;
  String? _bucketFilter;
  final Map<String, double> _bucketTotals = {};
  final Map<String, String> _customerBuckets = {};
  final Map<String, int> _customerDaysOverdue = {};

  Map<String, dynamic>? _selectedCustomer;
  List<Map<String, dynamic>> _payments = [];
  bool _isLoadingPayments = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    final storeId = AppSession.currentStoreId;
    if (storeId == null) return;

    final customers = await DebtRecoveryService.instance.fetchCustomersWithDebt(storeId);

    List<Map<String, dynamic>> overdue = [];
    try {
      final res = await Supabase.instance.client.rpc('get_overdue_customers', params: {
        'p_store_id': storeId,
      });
      overdue = List<Map<String, dynamic>>.from(res ?? []);
    } catch (e, s) { debugPrint('[AdminDebtRecovery] fetchOverdue error: $e\n$s'); }

    final bucketTotals = <String, double>{'0-30': 0, '31-60': 0, '61-90': 0, '90+': 0};
    final customerBuckets = <String, String>{};
    final customerDaysOverdue = <String, int>{};
    for (final o in overdue) {
      final id = o['id'] as String;
      final bucket = o['bucket'] as String? ?? '90+';
      final days = (o['days_overdue'] as num?)?.toInt() ?? 0;
      final balance = (o['balance'] as num?)?.toDouble() ?? 0;
      bucketTotals[bucket] = (bucketTotals[bucket] ?? 0) + balance;
      customerBuckets[id] = bucket;
      customerDaysOverdue[id] = days;
    }

    if (mounted) {
      setState(() {
        _allCustomers = customers;
        _customers = customers;
        _overdueCustomers = overdue;
        _bucketTotals..clear()..addAll(bucketTotals);
        _customerBuckets..clear()..addAll(customerBuckets);
        _customerDaysOverdue..clear()..addAll(customerDaysOverdue);
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    final q = _searchController.text.toLowerCase();
    final bucket = _bucketFilter;
    setState(() {
      _customers = _allCustomers.where((c) {
        if (q.isNotEmpty) {
          final name = (c['full_name'] as String? ?? '').toLowerCase();
          final phone = (c['phone'] as String? ?? '');
          if (!name.contains(q) && !phone.contains(q)) return false;
        }
        if (bucket != null) {
          final cid = c['id'] as String;
          if (_customerBuckets[cid] != bucket) return false;
        }
        return true;
      }).toList();
    });
  }

  void _setBucketFilter(String? bucket) {
    _bucketFilter = bucket;
    _applyFilters();
  }

  void _selectCustomer(Map<String, dynamic> customer) {
    setState(() {
      _selectedCustomer = customer;
      _isLoadingPayments = true;
    });
    _loadPayments(customer['id'] as String);
  }

  Future<void> _loadPayments(String customerId) async {
    final payments = await DebtRecoveryService.instance.fetchDebtPayments(customerId);
    if (mounted) {
      setState(() {
        _payments = payments;
        _isLoadingPayments = false;
      });
    }
  }

  // ══════════════════════════════════════════
  // Debt Payment Dialog
  // ══════════════════════════════════════════

  void _showDebtPaymentDialog() {
    if (_selectedCustomer == null) return;

    final formKey = GlobalKey<FormState>();
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String selectedMethod = 'cash';
    final currentBalance = (_selectedCustomer!['balance'] as num?)?.toDouble() ?? 0;

    final fieldDecoration = InputDecoration(
      filled: true,
      fillColor: _T.bgTableHeader,
      labelStyle: const TextStyle(color: _T.textSecondary, fontSize: 13),
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

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final amount = double.tryParse(amountCtrl.text) ?? 0;
          final newBalance = currentBalance - amount;

          return AlertDialog(
            backgroundColor: _T.bgCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(S.t('debt_receive_payment'),
                style: AppTextStyles.bodyMedium(color: _T.textPrimary)),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Balance preview
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _T.statusUnpaidBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _T.statusUnpaidText.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(S.t('debt_current_balance'),
                                  style: AppTextStyles.bodyMedium(color: _T.textSecondary)),
                              Text('${currentBalance.toStringAsFixed(2)} DA',
                                  style: AppTextStyles.bodyMedium(color: _T.statusUnpaidText)),
                            ],
                          ),
                          if (amount > 0) ...[
                            const Icon(Icons.arrow_forward, color: _T.textMuted),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(S.t('debt_new_balance'),
                                    style: AppTextStyles.bodyMedium(color: _T.textSecondary)),
                                Text('${newBalance.toStringAsFixed(2)} DA',
                                    style: AppTextStyles.bodyMedium(
                                      color: newBalance <= 0
                                          ? _T.statusPaidText
                                          : _T.statusPartialText,
                                    )),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: amountCtrl,
                      style: const TextStyle(color: _T.textPrimary),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: fieldDecoration.copyWith(
                        labelText: S.t('debt_amount_received'),
                        prefixIcon: const Icon(Icons.attach_money, color: _T.textMuted),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                      validator: (v) {
                        if (v == null || v.isEmpty) return S.t('msg_required');
                        final val = double.tryParse(v);
                        if (val == null || val <= 0) return S.t('msg_invalid_amount');
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedMethod,
                      dropdownColor: _T.bgTableHeader,
                      style: const TextStyle(color: _T.textPrimary, fontSize: 14),
                      decoration: fieldDecoration.copyWith(
                        labelText: S.t('label_method'),
                        prefixIcon: const Icon(Icons.payment, color: _T.textMuted),
                      ),
                      items: [
                        DropdownMenuItem(value: 'cash', child: Text(S.t('label_cash'))),
                        DropdownMenuItem(value: 'bank', child: Text(S.t('label_bank'))),
                        DropdownMenuItem(value: 'mobile', child: Text(S.t('label_mobile'))),
                      ],
                      onChanged: (v) => setDialogState(() => selectedMethod = v ?? 'cash'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: notesCtrl,
                      style: const TextStyle(color: _T.textPrimary),
                      decoration: fieldDecoration.copyWith(
                        labelText: S.t('debt_notes'),
                        prefixIcon: const Icon(Icons.note, color: _T.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(S.t('action_cancel'),
                    style: const TextStyle(color: _T.textSecondary)),
              ),
              Container(
                margin: const EdgeInsets.only(right: 8, bottom: 4),
                child: ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.pop(ctx);

                    try {
                      await DebtRecoveryService.instance.recordDebtPayment(
                        customerId: _selectedCustomer!['id'] as String,
                        amount: double.parse(amountCtrl.text),
                        paymentMethod: selectedMethod,
                        storeId: AppSession.currentStoreId!,
                        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                      );

                      // Refresh
                      await _loadCustomers();
                      // Re-select the customer to update balance
                      final updated = _allCustomers.where((c) => c['id'] == _selectedCustomer!['id']).firstOrNull;
                      if (updated != null) {
                        _selectCustomer(updated);
                      } else {
                        // Customer balance is now 0, no longer in debt list
                        setState(() => _selectedCustomer = null);
                      }

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(S.t('debt_recorded')),
                            backgroundColor: _T.statusPaidBg,
                            behavior: SnackBarBehavior.floating,
                            margin: const EdgeInsets.all(12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${S.t('msg_error')}: $e'),
                            backgroundColor: _T.statusUnpaidText,
                            behavior: SnackBarBehavior.floating,
                            margin: const EdgeInsets.all(12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
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
                  child: Text(S.t('debt_confirm_payment')),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════
  // Helpers
  // ══════════════════════════════════════════

  String _methodLabel(String? method) {
    switch (method) {
      case 'bank':
        return 'Virement';
      case 'mobile':
        return 'Mobile';
      default:
        return S.t('label_cash');
    }
  }

  Widget _buildBucketCards() {
    if (_overdueCustomers.isEmpty) return const SizedBox.shrink();
    final buckets = [
      ('0-30', _T.accentGold, _bucketTotals['0-30'] ?? 0),
      ('31-60', _T.statusPartialText, _bucketTotals['31-60'] ?? 0),
      ('61-90', _T.statusUnpaidText, _bucketTotals['61-90'] ?? 0),
      ('90+', const Color(0xFFB91C1C), _bucketTotals['90+'] ?? 0),
    ];
    return Column(
      children: [
        SizedBox(
          height: 70,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: buckets.map((b) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildBucketCard(b.$1, b.$2, b.$3),
              );
            }).toList(),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _buildChoiceChip('Tous', _bucketFilter == null, () => _setBucketFilter(null)),
              const SizedBox(width: 6),
              _buildChoiceChip('0-30', _bucketFilter == '0-30', () => _setBucketFilter('0-30')),
              const SizedBox(width: 6),
              _buildChoiceChip('31-60', _bucketFilter == '31-60', () => _setBucketFilter('31-60')),
              const SizedBox(width: 6),
              _buildChoiceChip('61-90', _bucketFilter == '61-90', () => _setBucketFilter('61-90')),
              const SizedBox(width: 6),
              _buildChoiceChip('90+', _bucketFilter == '90+', () => _setBucketFilter('90+')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChoiceChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
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

  Widget _buildBucketCard(String label, Color color, double amount) {
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: AppTextStyles.bodyMedium(color: color)),
          const SizedBox(height: 2),
          Text('${amount.toStringAsFixed(0)} DA',
              style: AppTextStyles.bodyMedium(color: _T.textPrimary)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════
  // Build
  // ══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final totalDebt = _allCustomers.fold<double>(
        0, (sum, c) => sum + ((c['balance'] as num?)?.toDouble() ?? 0));

    return Scaffold(
      backgroundColor: _T.bgPage,
      appBar: AppBar(
        title: Text(S.t('debt_title'),
            style: AppTextStyles.bodyMedium(color: _T.textPrimary).copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            )),
        backgroundColor: _T.bgAppBar,
        foregroundColor: _T.textPrimary,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _T.statusUnpaidBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _T.statusUnpaidText.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${S.t('debt_total_debt')}: ${totalDebt.toStringAsFixed(2)} DA',
                  style: AppTextStyles.bodyMedium(color: _T.statusUnpaidText),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildBucketCards(),
          Expanded(
            child: Row(
              children: [
                // ── LEFT PANEL: Customer List ──
                Expanded(
                  flex: 4,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _T.bgCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _T.borderColor),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: _T.bgTableHeader,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _T.borderColor),
                            ),
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(color: _T.textPrimary, fontSize: 14),
                              cursorColor: _T.accentGold,
                              decoration: InputDecoration(
                                hintText: S.t('debt_search_hint'),
                                hintStyle: const TextStyle(color: _T.textMuted, fontSize: 13),
                                prefixIcon: const Icon(Icons.search_rounded,
                                    color: _T.textMuted, size: 18),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onChanged: (_) => _applyFilters(),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              const Icon(Icons.people, size: 16, color: _T.textMuted),
                              const SizedBox(width: 8),
                              Text('${_customers.length} ${S.t('debt_clients_count')}',
                                  style: AppTextStyles.bodyMedium(color: _T.textSecondary)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Divider(color: _T.borderColor, height: 1),
                        Expanded(
                          child: _isLoading
                              ? const Center(
                                  child: CircularProgressIndicator(color: _T.accentGold))
                              : _customers.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.check_circle_outline,
                                              size: 48, color: _T.statusPaidText),
                                          const SizedBox(height: 8),
                                          Text(S.t('debt_no_debt'),
                                              style: AppTextStyles.bodyMedium(
                                                  color: _T.textSecondary)),
                                        ],
                                      ),
                                    )
                                  : ListView.separated(
                                      itemCount: _customers.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(color: _T.borderColor, height: 1),
                                      itemBuilder: (context, index) {
                                        final c = _customers[index];
                                        final balance = (c['balance'] as num?)?.toDouble() ?? 0;
                                        final isSelected = _selectedCustomer?['id'] == c['id'];
                                        final cid = c['id'] as String;
                                        final daysOverdue = _customerDaysOverdue[cid];
                                        final isOverdue = daysOverdue != null && daysOverdue > 0;

                                        return Container(
                                          color: isSelected
                                              ? _T.accentGold.withValues(alpha: 0.08)
                                              : Colors.transparent,
                                          child: ListTile(
                                            selected: isSelected,
                                            leading: CircleAvatar(
                                              backgroundColor: isSelected
                                                  ? _T.accentGold
                                                  : _T.bgTableHeader,
                                              child: Icon(Icons.person,
                                                  color: isSelected
                                                      ? _T.bgPage
                                                      : _T.textMuted),
                                            ),
                                            title: Text(c['full_name'] ?? S.t('misc_unknown'),
                                                style: AppTextStyles.bodyMedium(
                                                    color: _T.textPrimary)),
                                            subtitle: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(c['phone'] ?? S.t('misc_no_phone'),
                                                    style: const TextStyle(
                                                        fontSize: 12, color: _T.textSecondary)),
                                                if (isOverdue) ...[
                                                  const SizedBox(height: 2),
                                                  Row(
                                                    children: [
                                                      Icon(Icons.warning_amber_rounded,
                                                          size: 12, color: _T.statusUnpaidText),
                                                      const SizedBox(width: 4),
                                                      Text('$daysOverdue ${S.t('debt_days')}',
                                                          style: const TextStyle(
                                                              fontSize: 11,
                                                              color: _T.statusUnpaidText)),
                                                    ],
                                                  ),
                                                ],
                                              ],
                                            ),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: _T.statusUnpaidBg,
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(
                                                        color: _T.statusUnpaidText
                                                            .withValues(alpha: 0.3)),
                                                  ),
                                                  child: Text(
                                                    '${balance.toStringAsFixed(0)} DA',
                                                    style: AppTextStyles.bodyMedium(
                                                        color: _T.statusUnpaidText),
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.chat,
                                                      color: _T.statusPaidText, size: 18),
                                                  tooltip: 'WhatsApp',
                                                  onPressed: () => ContactUtils.sendWhatsApp(
                                                    context,
                                                    c['phone'] ?? '',
                                                    c['full_name'] ?? '',
                                                    balance,
                                                    days: daysOverdue,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            onTap: () => _selectCustomer(c),
                                          ),
                                        );
                                      },
                                    ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── RIGHT PANEL: Customer Detail ──
                Expanded(
                  flex: 6,
                  child: Container(
                    margin: const EdgeInsetsDirectional.only(top: 16, bottom: 16, end: 16),
                    decoration: BoxDecoration(
                      color: _T.bgCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _T.borderColor),
                    ),
                    child: _selectedCustomer == null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.account_balance_wallet,
                                    size: 48, color: _T.textMuted),
                                const SizedBox(height: 14),
                                Text(S.t('debt_select_client'),
                                    style: AppTextStyles.bodyMedium(color: _T.textSecondary)),
                              ],
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ── Header ──
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: const BoxDecoration(
                                  color: _T.bgTableHeader,
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _selectedCustomer!['full_name'] ?? '',
                                            style: AppTextStyles.headingLarge(
                                                color: _T.accentBlue),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Icon(Icons.phone,
                                                  size: 16, color: _T.textMuted),
                                              const SizedBox(width: 8),
                                              Text(
                                                  _selectedCustomer!['phone'] ??
                                                      S.t('misc_not_specified'),
                                                  style: AppTextStyles.bodyMedium(
                                                      color: _T.textPrimary)),
                                              const SizedBox(width: 24),
                                              const Icon(Icons.email,
                                                  size: 16, color: _T.textMuted),
                                              const SizedBox(width: 8),
                                              Text(
                                                  _selectedCustomer!['email'] ??
                                                      S.t('misc_not_specified'),
                                                  style: AppTextStyles.bodyMedium(
                                                      color: _T.textPrimary)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(S.t('cust_debt'),
                                            style: AppTextStyles.bodyMedium(
                                                color: _T.textSecondary)),
                                        Text(
                                          '${((_selectedCustomer!['balance'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} DA',
                                          style: AppTextStyles.bodyMedium(
                                              color: _T.statusUnpaidText),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // ── Tabs ──
                              TabBar(
                                controller: _tabController,
                                labelColor: _T.accentGold,
                                unselectedLabelColor: _T.textMuted,
                                indicatorColor: _T.accentGold,
                                tabs: [
                                  Tab(icon: const Icon(Icons.history),
                                      text: S.t('debt_payment_history')),
                                  Tab(icon: const Icon(Icons.info_outline),
                                      text: S.t('debt_client_info')),
                                ],
                              ),
                              // ── Tab Content ──
                              Expanded(
                                child: _isLoadingPayments
                                    ? const Center(
                                        child: CircularProgressIndicator(
                                            color: _T.accentGold))
                                    : TabBarView(
                                        controller: _tabController,
                                        children: [
                                          _buildPaymentsTab(),
                                          _buildInfoTab(),
                                        ],
                                      ),
                              ),
                              // ── Payment Button ──
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: ElevatedButton.icon(
                                  onPressed: _showDebtPaymentDialog,
                                  icon: const Icon(Icons.payments),
                                  label: Text(S.t('debt_receive_payment'),
                                      style: AppTextStyles.bodyMedium(color: _T.bgPage)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _T.accentGold,
                                    foregroundColor: _T.bgPage,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsTab() {
    if (_payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long, size: 48, color: _T.textMuted),
            const SizedBox(height: 8),
            Text(S.t('debt_no_payments'),
                style: AppTextStyles.bodyMedium(color: _T.textSecondary)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _payments.length,
      itemBuilder: (context, index) {
        final p = _payments[index];
        final amount = (p['amount'] as num?)?.toDouble() ?? 0;
        final dateStr = p['created_at'] as String? ?? '';
        final date = DateTime.tryParse(dateStr);
        final notes = p['notes'] as String? ?? '';
        final method = p['payment_method'] as String? ?? 'cash';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: _T.bgTable,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _T.borderColor),
          ),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _T.statusPaidBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.check_circle, color: _T.statusPaidText),
            ),
            title: Text(
              '${amount.toStringAsFixed(2)} DA',
              style: AppTextStyles.bodyMedium(color: _T.statusPaidText),
            ),
            subtitle: Text(
              '${_methodLabel(method)} ${notes.isNotEmpty ? '· $notes' : ''}',
              style: AppTextStyles.bodyMedium(color: _T.textSecondary),
            ),
            trailing: date != null
                ? Text('${date.day}/${date.month}/${date.year}',
                    style: const TextStyle(color: _T.textMuted))
                : null,
          ),
        );
      },
    );
  }

  Widget _buildInfoTab() {
    final c = _selectedCustomer!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(Icons.person, S.t('label_name'), c['full_name'] ?? S.t('misc_unknown')),
          const Divider(color: _T.borderColor),
          _infoRow(Icons.phone, S.t('label_phone'), c['phone'] ?? S.t('misc_not_specified')),
          const Divider(color: _T.borderColor),
          _infoRow(Icons.email, S.t('label_email'), c['email'] ?? S.t('misc_not_specified')),
          const Divider(color: _T.borderColor),
          _infoRow(Icons.account_balance_wallet, S.t('label_balance'),
              '${(c['balance'] as num?)?.toStringAsFixed(2) ?? '0.00'} DA'),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: _T.accentGold, size: 20),
          const SizedBox(width: 12),
          Text('$label:', style: AppTextStyles.bodyMedium(color: _T.textSecondary)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(value, style: AppTextStyles.bodyMedium(color: _T.textPrimary))),
        ],
      ),
    );
  }
}