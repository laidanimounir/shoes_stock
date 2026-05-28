import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_session.dart';
import '../../core/app_strings.dart';
import '../../local_db/isar_service.dart';
import '../../local_db/collections/customer_local.dart';
import '../../local_db/collections/invoice_local.dart';
import '../../local_db/collections/payment_local.dart';
import '../../services/debt_recovery_service.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});
  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  List<dynamic> _customers = [];
  bool _isLoading = true;
  bool _debtFilter = false;
  Map<String, dynamic>? _selected;
  late TabController _tabCtrl;
  List<dynamic> _invoices = [], _payments = [];
  bool _loadingHistory = false;
  double _balance = 0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _fetch();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch([String q = '']) async {
    setState(() => _isLoading = true);
    if (AppSession.isOfflineMode) {
      try {
        final isar = await IsarService.getInstance();
        var customers = await isar.customerLocals.where().findAll();
        if (q.isNotEmpty) customers = customers.where((c) => c.fullName.toLowerCase().contains(q.toLowerCase()) || (c.phone?.toLowerCase().contains(q.toLowerCase()) ?? false)).toList();
        final mapped = customers.where((c) => c.isActive).map((c) => {'id': c.supabaseId, 'full_name': c.fullName, 'phone': c.phone, 'email': c.email, 'address': c.address, 'balance': c.balance, 'is_active': c.isActive}).toList();
        if (mounted) setState(() { _customers = _debtFilter ? mapped.where((c) => (c['balance'] as num? ?? 0) > 0).toList() : mapped; _isLoading = false; });
      } catch (_) { if (mounted) setState(() => _isLoading = false); }
      return;
    }
    try {
      var qb = Supabase.instance.client.from('customers').select().eq('is_active', true);
      if (q.isNotEmpty) qb = qb.or('full_name.ilike.%$q%,phone.ilike.%$q%');
      final res = await qb.order('full_name');
      if (mounted) setState(() { _customers = _debtFilter ? (res as List).where((c) => (c['balance'] as num? ?? 0) > 0).toList() : res; _isLoading = false; });
    } catch (_) { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _fetchHistory(String id) async {
    setState(() => _loadingHistory = true);
    if (AppSession.isOfflineMode) {
      try {
        final isar = await IsarService.getInstance();
        final invs = await isar.invoiceLocals.where().findAll();
        final invsFiltered = invs.where((i) => i.customerId == id && i.type == 'out').toList();
        final pays = await isar.paymentLocals.where().findAll();
        final paysFiltered = pays.where((p) => p.customerId == id).toList();
        if (mounted) setState(() {
          _invoices = invsFiltered.map((i) => {'id': i.supabaseId, 'invoice_number': i.invoiceNumber, 'total_amount': i.totalAmount, 'paid_amount': i.paidAmount, 'status': i.status, 'created_at': i.createdAt?.toIso8601String()}).toList();
          _payments = paysFiltered.map((p) => {'id': p.supabaseId, 'amount': p.amount, 'payment_method': p.paymentMethod, 'created_at': p.createdAt?.toIso8601String()}).toList();
          _balance = _invoices.fold(0.0, (s, i) => s + ((i['total_amount'] as num?)?.toDouble() ?? 0)) - _payments.fold(0.0, (s, p) => s + ((p['amount'] as num?)?.toDouble() ?? 0));
          _loadingHistory = false;
        });
      } catch (_) { if (mounted) setState(() => _loadingHistory = false); }
      return;
    }
    try {
      var iq = Supabase.instance.client.from('invoices').select().eq('customer_id', id).eq('type', 'out');
      var pq = Supabase.instance.client.from('payments').select().eq('customer_id', id);
      if (AppSession.isEmployee && AppSession.currentStoreId != null) {
        iq = iq.eq('store_id', AppSession.currentStoreId!);
        pq = pq.eq('store_id', AppSession.currentStoreId!);
      }
      final invs = await iq.order('created_at', ascending: false);
      final pays = await pq.order('payment_date', ascending: false);
      if (mounted) setState(() { _invoices = invs; _payments = pays; _loadingHistory = false; });
      final balRes = await Supabase.instance.client.rpc('get_customer_balance', params: {'p_customer_id': id});
      if (mounted) setState(() { _balance = (balRes as num?)?.toDouble() ?? 0; });
    } catch (_) { if (mounted) setState(() => _loadingHistory = false); }
  }

  void _addCustomer() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(S.t('cust_add')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Téléphone', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.t('action_cancel'))),
        ElevatedButton(onPressed: () async {
          if (nameCtrl.text.isEmpty) return;
          Navigator.pop(ctx);
          try {
            await Supabase.instance.client.from('customers').insert({'full_name': nameCtrl.text.trim(), 'phone': phoneCtrl.text.trim(), 'email': emailCtrl.text.trim(), 'balance': 0, 'is_active': true});
            _fetch(_searchCtrl.text);
          } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red)); }
        }, child: Text(S.t('action_save'))),
      ],
    ));
  }

  void _editCustomer() {
    if (!AppSession.isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.t('msg_access_denied')), backgroundColor: Colors.red));
      return;
    }
    final c = _selected!;
    final nameCtrl = TextEditingController(text: c['full_name']);
    final phoneCtrl = TextEditingController(text: c['phone']);
    final emailCtrl = TextEditingController(text: c['email']);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(S.t('cust_edit')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Téléphone', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.t('action_cancel'))),
        ElevatedButton(onPressed: () async {
          Navigator.pop(ctx);
          try {
            await Supabase.instance.client.from('customers').update({'full_name': nameCtrl.text.trim(), 'phone': phoneCtrl.text.trim(), 'email': emailCtrl.text.trim()}).eq('id', c['id']);
            if (_selected?['id'] == c['id']) setState(() { _selected!['full_name'] = nameCtrl.text; _selected!['phone'] = phoneCtrl.text; _selected!['email'] = emailCtrl.text; });
            _fetch(_searchCtrl.text);
          } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red)); }
        }, child: Text(S.t('action_save'))),
      ],
    ));
  }

  void _deleteCustomer() async {
    if (!AppSession.isOwner) return;
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(S.t('cust_archive_title')), content: Text(S.t('cust_archive_msg')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.t('action_cancel'))),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white), child: Text(S.t('action_archive'))),
      ],
    ));
    if (confirm != true) return;
    try {
      await Supabase.instance.client.from('customers').update({'is_active': false}).eq('id', _selected!['id']);
      setState(() => _selected = null);
      _fetch(_searchCtrl.text);
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red)); }
  }

  void _recordPayment() async {
    final amountCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(S.t('cust_receive_payment')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${S.t('pos_credit')}: ${_balance.toStringAsFixed(0)} ${S.t('misc_currency')}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        const SizedBox(height: 12),
        TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Montant', border: OutlineInputBorder())),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.t('action_cancel'))),
        ElevatedButton(onPressed: () async {
          final amount = double.tryParse(amountCtrl.text);
          if (amount == null || amount <= 0) return;
          Navigator.pop(ctx);
          try {
            await DebtRecoveryService.instance.recordDebtPayment(customerId: _selected!['id'], amount: amount, paymentMethod: 'cash', storeId: AppSession.currentStoreId ?? '');
            _fetchHistory(_selected!['id']);
          } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red)); }
        }, child: Text(S.t('action_confirm'))),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.t('nav_clients')),
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_debtFilter ? Icons.filter_list_off : Icons.filter_list),
            tooltip: S.t('cust_filter_debt'),
            onPressed: () => setState(() { _debtFilter = !_debtFilter; _fetch(_searchCtrl.text); }),
          ),
          IconButton(icon: const Icon(Icons.person_add), onPressed: _addCustomer),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // Customer list
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.4,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: S.t('cust_search_hint'), prefixIcon: const Icon(Icons.search, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onChanged: (v) => _fetch(v),
                        ),
                      ),
                      Expanded(
                        child: _customers.isEmpty
                            ? Center(child: Text(S.t('cust_no_results')))
                            : ListView.builder(
                                itemCount: _customers.length,
                                itemBuilder: (_, i) {
                                  final c = _customers[i];
                                  final sel = _selected?['id'] == c['id'];
                                  final bal = (c['balance'] as num?)?.toDouble() ?? 0;
                                  return ListTile(
                                    dense: true,
                                    selected: sel,
                                    selectedTileColor: Colors.indigo.withOpacity(0.1),
                                    leading: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: sel ? Colors.indigo : Colors.grey[200],
                                      child: Icon(Icons.person, size: 16, color: sel ? Colors.white : Colors.grey[700]),
                                    ),
                                    title: Text(c['full_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    subtitle: Text(c['phone'] ?? '', style: const TextStyle(fontSize: 10)),
                                    trailing: bal > 0
                                        ? Text('${bal.toStringAsFixed(0)} ${S.t('misc_currency')}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10))
                                        : const Icon(Icons.check_circle, color: Colors.green, size: 14),
                                    onTap: () { setState(() => _selected = c); _fetchHistory(c['id']); },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, color: Colors.grey[300]),
                // Detail panel
                Expanded(
                  child: _selected == null
                      ? Center(child: Text(S.t('cust_no_client_selected'), style: const TextStyle(color: Colors.grey)))
                      : _loadingHistory
                          ? const Center(child: CircularProgressIndicator())
                          : Column(
                              children: [
                                // Header
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  color: Colors.indigo.withOpacity(0.05),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(_selected!['full_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.indigo)),
                                            const SizedBox(height: 4),
                                            Text(_selected!['phone'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(S.t('pos_credit'), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                          Text('${_balance.toStringAsFixed(0)} ${S.t('misc_currency')}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _balance > 0 ? Colors.red : Colors.green)),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (AppSession.isOwner) ...[
                                                IconButton(icon: const Icon(Icons.edit, size: 16, color: Colors.orange), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: _editCustomer),
                                                const SizedBox(width: 8),
                                                IconButton(icon: const Icon(Icons.archive, size: 16, color: Colors.red), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: _deleteCustomer),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Tabs
                                TabBar(
                                  controller: _tabCtrl,
                                  labelColor: Colors.indigo[900],
                                  unselectedLabelColor: Colors.grey,
                                  tabs: [
                                    Tab(text: '${S.t('nav_invoices')} (${_invoices.length})'),
                                    Tab(text: '${S.t('nav_payments')} (${_payments.length})'),
                                  ],
                                ),
                                Expanded(
                                  child: TabBarView(
                                    controller: _tabCtrl,
                                    children: [
                                      _buildInvoiceList(),
                                      _buildPaymentList(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                ),
              ],
            ),
      floatingActionButton: _selected != null
          ? FloatingActionButton(
              mini: true,
              onPressed: _recordPayment,
              backgroundColor: Colors.green,
              child: const Icon(Icons.payments, color: Colors.white, size: 20),
            )
          : null,
    );
  }

  Widget _buildInvoiceList() {
    if (_invoices.isEmpty) return Center(child: Text(S.t('label_no_data')));
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _invoices.length,
      itemBuilder: (_, i) {
        final inv = _invoices[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 4),
          child: ListTile(
            dense: true,
            title: Text('${S.t('nav_invoices')} ${inv['invoice_number'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            subtitle: Text('${inv['created_at']?.toString().substring(0, 10) ?? ''} • ${inv['status'] ?? ''}', style: const TextStyle(fontSize: 10)),
            trailing: Text('${(inv['total_amount'] as num?)?.toDouble() ?? 0} ${S.t('misc_currency')}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        );
      },
    );
  }

  Widget _buildPaymentList() {
    if (_payments.isEmpty) return Center(child: Text(S.t('label_no_data')));
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _payments.length,
      itemBuilder: (_, i) {
        final p = _payments[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 4),
          child: ListTile(
            dense: true,
            title: Text('${p['created_at']?.toString().substring(0, 10) ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            subtitle: Text('${p['payment_method'] ?? ''}', style: const TextStyle(fontSize: 10)),
            trailing: Text('+${(p['amount'] as num?)?.toDouble() ?? 0} ${S.t('misc_currency')}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 12)),
          ),
        );
      },
    );
  }
}
