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
  List<dynamic> _stores = [];
  bool _isLoading = true;
  String? _filterStoreId;

  @override
  void initState() {
    super.initState();
    _initAndFetch();
  }

  Future<void> _initAndFetch() async {
    try {
      if (AppSession.isOwner) {
        _stores = await supabase.from('stores').select('id, name').order('name');
      }
      await _fetchOrders();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    try {
      var query = supabase
          .from('purchase_orders')
          .select('id, order_number, status, total_amount, notes, created_at, store_id, supplier_id:suppliers(company_name), stores(name), purchase_order_items(variant_id, quantity, unit_price, total_price)');

      if (_filterStoreId != null) {
        query = query.eq('store_id', _filterStoreId!);
      }

      final res = await query.order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _orders = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approveOrder(String orderId) async {
    try {
      await supabase.rpc('approve_purchase_order', params: {'p_order_id': orderId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Commande approuvée'), backgroundColor: Colors.green),
        );
        _fetchOrders();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _cancelOrder(String orderId) async {
    try {
      await supabase
          .from('purchase_orders')
          .update({'status': 'cancelled'})
          .eq('id', orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Commande annulée'), backgroundColor: Colors.orange),
        );
        _fetchOrders();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;
    switch (status) {
      case 'pending':
        color = Colors.orange;
        label = 'En attente';
        break;
      case 'approved':
        color = Colors.green;
        label = 'Approuvée';
        break;
      case 'cancelled':
        color = Colors.red;
        label = 'Annulée';
        break;
      default:
        color = Colors.grey;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Bons de Commande'),
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
        actions: [
          if (AppSession.isOwner)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DropdownButton<String?>(
                dropdownColor: Colors.indigo[800],
                style: const TextStyle(color: Colors.white),
                underline: const SizedBox(),
                value: _filterStoreId,
                hint: const Text('Tous les magasins', style: TextStyle(color: Colors.white70)),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Tous les magasins')),
                  ..._stores.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name'] as String))),
                ],
                onChanged: (val) {
                  setState(() => _filterStoreId = val);
                  _fetchOrders();
                },
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('Aucun bon de commande', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _orders.length,
                  itemBuilder: (context, index) {
                    final o = _orders[index];
                    final items = o['purchase_order_items'] as List? ?? [];
                    final itemCount = items.length;
                    final status = o['status'] as String? ?? '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Text(o['order_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      const SizedBox(width: 8),
                                      _buildStatusChip(status),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${o['total_amount'] ?? 0} ${S.t('misc_currency')}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${o['supplier_id']?['company_name'] ?? '—'}',
                              style: TextStyle(color: Colors.grey[700], fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.store, size: 14, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Text('${o['stores']?['name'] ?? '—'}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                const Spacer(),
                                Icon(Icons.inventory_2, size: 14, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Text('$itemCount articles', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                const SizedBox(width: 12),
                                Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Text(_formatDate(o['created_at']?.toString() ?? ''), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              ],
                            ),
                            if (o['notes'] != null && (o['notes'] as String).isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text('${o['notes']}', style: TextStyle(color: Colors.grey[500], fontSize: 12, fontStyle: FontStyle.italic)),
                            ],
                            if (status == 'pending') ...[
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.close, size: 16),
                                    label: const Text('Annuler'),
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Annuler la commande'),
                                          content: Text('Annuler ${o['order_number']} ?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
                                            ElevatedButton(
                                              onPressed: () => Navigator.pop(ctx, true),
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                              child: const Text('Oui, annuler'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) _cancelOrder(o['id']);
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.check_circle, size: 16),
                                    label: const Text('Approuver'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Approuver la commande'),
                                          content: Text('Valider ${o['order_number']} et ajouter au stock ?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
                                            ElevatedButton(
                                              onPressed: () => Navigator.pop(ctx, true),
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                              child: const Text('Oui, approuver'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) _approveOrder(o['id']);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}
