import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_strings.dart';
import '../../core/app_session.dart';

class PurchaseOrdersScreen extends StatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  final supabase = Supabase.instance.client;
  List<dynamic> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    try {
      final res = await supabase
          .from('purchase_orders')
          .select('id, order_number, status, total_amount, notes, created_at, supplier_id:suppliers(company_name), stores(name), purchase_order_items(variant_id, quantity, unit_price, total_price)')
          .order('created_at', ascending: false);
      if (mounted) setState(() { _orders = res; _isLoading = false; });
    } catch (_) { if (mounted) setState(() => _isLoading = false); }
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
      case 'pending': c = Colors.orange; l = 'En attente'; break;
      case 'approved': c = Colors.green; l = 'Approuvée'; break;
      case 'cancelled': c = Colors.red; l = 'Annulée'; break;
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
      appBar: AppBar(title: const Text('Bons de Commande'), backgroundColor: Colors.indigo[900], foregroundColor: Colors.white),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 12), const Text('Aucun bon de commande'),
                ]))
              : ListView.builder(padding: const EdgeInsets.all(8), itemCount: _orders.length, itemBuilder: (_, i) {
                  final o = _orders[i];
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
                        Text('${items.length} articles', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        const Spacer(),
                        Text('${o['total_amount'] ?? 0} ${S.t('misc_currency')}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                      ]),
                      if (status == 'pending') ...[
                        const SizedBox(height: 8),
                        SizedBox(width: double.infinity, child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle, size: 16),
                          label: const Text('Approuver'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                          onPressed: () async {
                            final c = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                              title: const Text('Approuver'), content: Text('Valider ${o['order_number']} ?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
                                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), child: const Text('Oui')),
                              ],
                            ));
                            if (c == true) _approveOrder(o['id']);
                          },
                        )),
                      ],
                    ]),
                  ));
                }),
    );
  }
}
