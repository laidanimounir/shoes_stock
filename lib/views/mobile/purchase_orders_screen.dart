import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_strings.dart';

class PurchaseOrdersScreen extends StatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  final supabase = Supabase.instance.client;
  List<dynamic> _orders = [];
  List<dynamic> _filtered = [];
  bool _isLoading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }
  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    try {
      final res = await supabase
          .from('purchase_orders')
          .select('id, order_number, status, total_amount, notes, created_at, supplier_id:suppliers(company_name), stores(name), purchase_order_items(variant_id, quantity, unit_price, total_price)')
          .order('created_at', ascending: false);
      if (mounted) setState(() { _orders = res; _applyFilter(); _isLoading = false; });
    } catch (_) { if (mounted) setState(() => _isLoading = false); }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.from(_orders)
          : _orders.where((o) =>
              (o['order_number'] ?? '').toString().toLowerCase().contains(q) ||
              (o['supplier_id']?['company_name'] ?? '').toString().toLowerCase().contains(q) ||
              (o['status'] ?? '').toString().toLowerCase().contains(q)).toList();
    });
  }

  Future<void> _approveOrder(String orderId) async {
    try {
      await supabase.rpc('approve_purchase_order', params: {'p_order_id': orderId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Commande approuvée'), backgroundColor: Colors.green));
        _fetchOrders();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  Widget _statusChip(String status) {
    Color c;
    String l;
    switch (status) {
      case 'pending': c = Colors.orange; l = S.t('order_status_pending'); break;
      case 'approved': c = Colors.green; l = S.t('order_status_approved'); break;
      case 'cancelled': c = Colors.red; l = S.t('order_status_cancelled'); break;
      default: c = Colors.grey; l = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: c)),
      child: Text(l, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.t('order_title')), backgroundColor: Colors.indigo[900], foregroundColor: Colors.white),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: S.t('search_hint'),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  onChanged: (_) => _applyFilter(),
                ),
              ),
              Expanded(child: _filtered.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 12), Text(S.t('order_no_orders')),
                    ]))
                  : RefreshIndicator(onRefresh: _fetchOrders, child: ListView.builder(padding: const EdgeInsets.all(8), itemCount: _filtered.length, itemBuilder: (_, i) {
                      final o = _filtered[i];
                  final status = o['status'] as String? ?? '';
                  final items = o['purchase_order_items'] as List? ?? [];
                  return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(o['order_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                        _statusChip(status),
                      ]),
                      const SizedBox(height: 4),
                      Text('${o['supplier_id']?['company_name'] ?? '—'}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                      const SizedBox(height: 4),
                      Row(children: [
                        Text('${items.length} ${S.t('order_items')}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        const Spacer(),
                        Text('${o['total_amount'] ?? 0} ${S.t('misc_currency')}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                      ]),
                      if (status == 'pending') ...[
                        const SizedBox(height: 8),
                        SizedBox(width: double.infinity, child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle, size: 16),
                          label: Text(S.t('order_approve')),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                          onPressed: () async {
                            final c = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                              title: Text(S.t('order_approve')), content: Text(S.t('order_approve_confirm').replaceAll('{order}', o['order_number'] ?? '')),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.t('no'))),
                                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), child: Text(S.t('yes'))),
                              ],
                            ));
                            if (c == true) _approveOrder(o['id']);
                          },
                        )),
                      ],
                    ]),
                  ));
                }),
              ),
            ),
          ],
        ),
    );
  }
}
