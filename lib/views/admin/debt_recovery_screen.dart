import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_session.dart';
import '../../core/app_strings.dart';
import '../../services/debt_recovery_service.dart';

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
  bool _isLoading = true;

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

    if (mounted) {
      setState(() {
        _allCustomers = customers;
        _customers = customers;
        _isLoading = false;
      });
    }
  }

  void _filterCustomers(String query) {
    if (query.isEmpty) {
      setState(() => _customers = _allCustomers);
      return;
    }
    final q = query.toLowerCase();
    setState(() {
      _customers = _allCustomers
          .where((c) =>
              (c['full_name'] as String? ?? '').toLowerCase().contains(q) ||
              (c['phone'] as String? ?? '').contains(q))
          .toList();
    });
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

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final amount = double.tryParse(amountCtrl.text) ?? 0;
          final newBalance = currentBalance - amount;

          return AlertDialog(
            title: Text(S.t('debt_receive_payment'), style: GoogleFonts.raleway(fontWeight: FontWeight.bold)),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Balance preview
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(S.t('debt_current_balance'), style: GoogleFonts.raleway(color: Colors.grey[600], fontSize: 12)),
                            Text('${currentBalance.toStringAsFixed(2)} DA',
                                style: GoogleFonts.raleway(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 18)),
                          ],
                        ),
                        if (amount > 0) ...[
                          const Icon(Icons.arrow_forward, color: Colors.grey),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(S.t('debt_new_balance'), style: GoogleFonts.raleway(color: Colors.grey[600], fontSize: 12)),
                              Text('${newBalance.toStringAsFixed(2)} DA',
                                  style: GoogleFonts.raleway(
                                    fontWeight: FontWeight.bold,
                                    color: newBalance <= 0 ? Colors.green : Colors.orange,
                                    fontSize: 18,
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
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: S.t('debt_amount_received'),
                      prefixIcon: const Icon(Icons.attach_money),
                      border: const OutlineInputBorder(),
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
                    decoration: InputDecoration(
                      labelText: S.t('label_method'),
                      prefixIcon: const Icon(Icons.payment),
                      border: const OutlineInputBorder(),
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
                    decoration: InputDecoration(
                      labelText: S.t('debt_notes'),
                      prefixIcon: const Icon(Icons.note),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.t('action_cancel'))),
              ElevatedButton(
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
                        SnackBar(content: Text(S.t('debt_recorded')), backgroundColor: Colors.green),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${S.t('msg_error')}: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                child: Text(S.t('debt_confirm_payment')),
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(S.t('debt_title'), style: GoogleFonts.raleway(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo[800],
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${S.t('debt_total_debt')}: ${totalDebt.toStringAsFixed(2)} DA',
                  style: GoogleFonts.raleway(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          // ── LEFT PANEL: Customer List ──
          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: S.t('debt_search_hint'),
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: _filterCustomers,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(Icons.people, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text('${_customers.length} ${S.t('debt_clients_count')}',
                            style: GoogleFonts.raleway(color: Colors.grey[600], fontSize: 13)),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _customers.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_outline, size: 48, color: Colors.green[300]),
                                    const SizedBox(height: 8),
                                    Text(S.t('debt_no_debt'),
                                        style: GoogleFonts.raleway(color: Colors.grey, fontSize: 16)),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                itemCount: _customers.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final c = _customers[index];
                                  final balance = (c['balance'] as num?)?.toDouble() ?? 0;
                                  final isSelected = _selectedCustomer?['id'] == c['id'];

                                  return ListTile(
                                    selected: isSelected,
                                    selectedTileColor: Colors.indigo.withOpacity(0.08),
                                    leading: CircleAvatar(
                                      backgroundColor: isSelected ? Colors.indigo : Colors.grey[200],
                                      child: Icon(Icons.person, color: isSelected ? Colors.white : Colors.grey[700]),
                                    ),
                                    title: Text(c['full_name'] ?? S.t('misc_unknown'),
                                        style: GoogleFonts.raleway(fontWeight: FontWeight.bold)),
                                    subtitle: Text(c['phone'] ?? S.t('misc_no_phone'),
                                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.red[50],
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.red.shade200),
                                      ),
                                      child: Text(
                                        '${balance.toStringAsFixed(2)} DA',
                                        style: GoogleFonts.raleway(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red[700],
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    onTap: () => _selectCustomer(c),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: _selectedCustomer == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.account_balance_wallet, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text(S.t('debt_select_client'),
                              style: GoogleFonts.raleway(color: Colors.grey, fontSize: 16)),
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Header ──
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.indigo.withOpacity(0.05),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
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
                                      style: GoogleFonts.playfairDisplay(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.indigo[800],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.phone, size: 16, color: Colors.grey),
                                        const SizedBox(width: 8),
                                        Text(_selectedCustomer!['phone'] ?? S.t('misc_not_specified'),
                                            style: GoogleFonts.raleway()),
                                        const SizedBox(width: 24),
                                        const Icon(Icons.email, size: 16, color: Colors.grey),
                                        const SizedBox(width: 8),
                                        Text(_selectedCustomer!['email'] ?? S.t('misc_not_specified'),
                                            style: GoogleFonts.raleway()),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(S.t('cust_debt'), style: GoogleFonts.raleway(color: Colors.grey[600])),
                                  Text(
                                    '${((_selectedCustomer!['balance'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} DA',
                                    style: GoogleFonts.raleway(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // ── Tabs ──
                        TabBar(
                          controller: _tabController,
                          labelColor: Colors.indigo,
                          indicatorColor: Colors.indigo,
                          tabs: [
                            Tab(icon: const Icon(Icons.history), text: S.t('debt_payment_history')),
                            Tab(icon: const Icon(Icons.info_outline), text: S.t('debt_client_info')),
                          ],
                        ),

                        // ── Tab Content ──
                        Expanded(
                          child: _isLoadingPayments
                              ? const Center(child: CircularProgressIndicator())
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
                                style: GoogleFonts.raleway(fontSize: 16, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
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
    );
  }

  Widget _buildPaymentsTab() {
    if (_payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 8),
            Text(S.t('debt_no_payments'), style: GoogleFonts.raleway(color: Colors.grey)),
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

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green[50],
              child: const Icon(Icons.check_circle, color: Colors.green),
            ),
            title: Text(
              '${amount.toStringAsFixed(2)} DA',
              style: GoogleFonts.raleway(fontWeight: FontWeight.bold, color: Colors.green[700]),
            ),
            subtitle: Text(
              '${_methodLabel(method)} ${notes.isNotEmpty ? '· $notes' : ''}',
              style: GoogleFonts.raleway(fontSize: 12, color: Colors.grey[600]),
            ),
            trailing: date != null
                ? Text('${date.day}/${date.month}/${date.year}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12))
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
          const Divider(),
          _infoRow(Icons.phone, S.t('label_phone'), c['phone'] ?? S.t('misc_not_specified')),
          const Divider(),
          _infoRow(Icons.email, S.t('label_email'), c['email'] ?? S.t('misc_not_specified')),
          const Divider(),
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
          Icon(icon, color: Colors.indigo, size: 20),
          const SizedBox(width: 12),
          Text('$label:', style: GoogleFonts.raleway(color: Colors.grey[600], fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: GoogleFonts.raleway(fontSize: 15))),
        ],
      ),
    );
  }
}
