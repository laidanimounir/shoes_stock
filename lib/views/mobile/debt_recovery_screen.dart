import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_session.dart';
import '../../core/app_strings.dart';
import '../../services/debt_recovery_service.dart';
import '../../shared/utils/contact_utils.dart';

class DebtRecoveryScreen extends StatefulWidget {
  const DebtRecoveryScreen({super.key});
  @override
  State<DebtRecoveryScreen> createState() => _DebtRecoveryScreenState();
}

class _DebtRecoveryScreenState extends State<DebtRecoveryScreen> {
  List<Map<String, dynamic>> _debts = [];
  List<Map<String, dynamic>> _allDebts = [];
  List<Map<String, dynamic>> _overdueCustomers = [];
  bool _isLoading = true;
  String? _bucketFilter;
  final Map<String, double> _bucketTotals = {};
  final Map<String, String> _customerBuckets = {};
  final Map<String, int> _customerDaysOverdue = {};
  final _searchCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _fetch(); }
  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      final data = await DebtRecoveryService.instance.fetchCustomersWithDebt(AppSession.currentStoreId!);
      List<Map<String, dynamic>> overdue = [];
      try {
        final res = await Supabase.instance.client.rpc('get_overdue_customers', params: {
          'p_store_id': AppSession.currentStoreId,
        });
        overdue = List<Map<String, dynamic>>.from(res ?? []);
      } catch (_) {}

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

      if (mounted) setState(() {
        _allDebts = data;
        _debts = data;
        _overdueCustomers = overdue;
        _bucketTotals..clear()..addAll(bucketTotals);
        _customerBuckets..clear()..addAll(customerBuckets);
        _customerDaysOverdue..clear()..addAll(customerDaysOverdue);
        _isLoading = false;
      });
    } catch (_) { if (mounted) setState(() => _isLoading = false); }
  }

  void _applyFilters() {
    final q = _searchCtrl.text.toLowerCase();
    final bucket = _bucketFilter;
    setState(() {
      _debts = _allDebts.where((d) {
        if (q.isNotEmpty) {
          final name = (d['full_name'] ?? '').toString().toLowerCase();
          final phone = (d['phone'] ?? '').toString();
          if (!name.contains(q) && !phone.contains(q)) return false;
        }
        if (bucket != null) {
          final cid = d['id'] as String;
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

  void _recordPayment(Map<String, dynamic> debtor) async {
    final amountCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(S.t('cust_receive_payment')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${S.t('pos_credit')}: ${(debtor['balance'] as num?)?.toDouble() ?? 0} ${S.t('misc_currency')}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
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
            await DebtRecoveryService.instance.recordDebtPayment(
              customerId: debtor['id'] as String, amount: amount,
              paymentMethod: 'cash', storeId: AppSession.currentStoreId!, notes: 'Recouvrement dette',
            );
            _fetch();
          } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red)); }
        }, child: Text(S.t('action_confirm'))),
      ],
    ));
  }

  Widget _buildBucketCards() {
    if (_overdueCustomers.isEmpty) return const SizedBox.shrink();
    final buckets = [
      ('0-30', Colors.amber.shade600, _bucketTotals['0-30'] ?? 0),
      ('31-60', Colors.orange.shade600, _bucketTotals['31-60'] ?? 0),
      ('61-90', Colors.red.shade600, _bucketTotals['61-90'] ?? 0),
      ('90+', Colors.red.shade900, _bucketTotals['90+'] ?? 0),
    ];
    return Column(
      children: [
        SizedBox(
          height: 60,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: buckets.map((b) {
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Container(
                  width: 120,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: b.$2.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: b.$2.withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(b.$1, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: b.$2)),
                      Text('${b.$3.toStringAsFixed(0)} DA',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Tous', style: TextStyle(fontSize: 11)),
                selected: _bucketFilter == null,
                onSelected: (_) => _setBucketFilter(null),
              ),
              const SizedBox(width: 4),
              ChoiceChip(
                label: const Text('0-30', style: TextStyle(fontSize: 11)),
                selected: _bucketFilter == '0-30',
                onSelected: (_) => _setBucketFilter('0-30'),
              ),
              const SizedBox(width: 4),
              ChoiceChip(
                label: const Text('31-60', style: TextStyle(fontSize: 11)),
                selected: _bucketFilter == '31-60',
                onSelected: (_) => _setBucketFilter('31-60'),
              ),
              const SizedBox(width: 4),
              ChoiceChip(
                label: const Text('61-90', style: TextStyle(fontSize: 11)),
                selected: _bucketFilter == '61-90',
                onSelected: (_) => _setBucketFilter('61-90'),
              ),
              const SizedBox(width: 4),
              ChoiceChip(
                label: const Text('90+', style: TextStyle(fontSize: 11)),
                selected: _bucketFilter == '90+',
                onSelected: (_) => _setBucketFilter('90+'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.t('nav_debt_recovery')), backgroundColor: Colors.indigo[900], foregroundColor: Colors.white),
      body: Column(children: [
        _buildBucketCards(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(hintText: S.t('cust_search_hint'), prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
            onChanged: (_) => _applyFilters(),
          ),
        ),
        Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator()) : _debts.isEmpty
            ? Center(child: Text(S.t('label_no_data')))
            : RefreshIndicator(onRefresh: _fetch, child: ListView.builder(padding: const EdgeInsets.all(8), itemCount: _debts.length, itemBuilder: (_, i) {
                final d = _debts[i];
                final bal = (d['balance'] as num?)?.toDouble() ?? 0;
                final cid = d['id'] as String;
                final daysOverdue = _customerDaysOverdue[cid];
                final isOverdue = daysOverdue != null && daysOverdue > 0;
                final tileColor = isOverdue ? Colors.red.withOpacity(0.05) : null;
                return Card(margin: const EdgeInsets.only(bottom: 8), color: tileColor, child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isOverdue ? Colors.red[100] : null,
                    child: Text(((d['full_name'] as String?)?[0] ?? '?').toUpperCase()),
                  ),
                  title: Text(d['full_name'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: isOverdue ? Colors.red[800] : null)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${S.t('pos_credit')}: ${bal.toStringAsFixed(0)} ${S.t('misc_currency')}', style: TextStyle(color: isOverdue ? Colors.red : Colors.red, fontWeight: FontWeight.bold)),
                      if (isOverdue)
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 12, color: Colors.red[600]),
                            const SizedBox(width: 4),
                            Text('$daysOverdue ${S.t('debt_days')}',
                                style: TextStyle(color: Colors.red[700], fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chat, color: Colors.green, size: 20),
                        tooltip: 'WhatsApp',
                        onPressed: () => ContactUtils.sendWhatsApp(context, d['phone'] ?? '', d['full_name'], bal, days: daysOverdue),
                      ),
                      IconButton(
                        icon: const Icon(Icons.sms, color: Colors.blue, size: 20),
                        tooltip: 'SMS',
                        onPressed: () => ContactUtils.sendSMS(context, d['phone'] ?? '', d['full_name'], bal),
                      ),
                      IconButton(
                        icon: const Icon(Icons.payments, color: Colors.green, size: 20),
                        onPressed: () => _recordPayment(d),
                      ),
                    ],
                  ),
                ));
              }),
        ),
        ),
      ]),
    );
  }
}
