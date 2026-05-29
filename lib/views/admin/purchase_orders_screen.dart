import 'dart:convert';
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
          .select('id, order_number, status, total_amount, notes, created_at, received_at, store_id, supplier_id:suppliers(company_name), stores(name), purchase_order_items(variant_id, quantity, unit_price, total_price, received_qty)');

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

  Future<void> _confirmOrder(String orderId) async {
    try {
      await supabase.rpc('confirm_purchase_order', params: {'p_po_id': orderId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Commande confirmée'), backgroundColor: Colors.green),
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
          .update({'status': 'cancelled', 'updated_at': DateTime.now().toUtc().toIso8601String()})
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

  Future<void> _receiveStock(String orderId, String storeId, List items) async {
    final itemList = items.map((i) => {
      'variant_id': i['variant_id'] as String,
      'quantity': i['quantity'] as int? ?? 0,
      'received_qty': i['received_qty'] as int? ?? 0,
      'variant': i['variant'],
    }).toList();

    final result = await showDialog<Map<String, int>?>(
      context: context,
      builder: (ctx) => _ReceiveStockDialog(poItems: itemList),
    );

    if (result == null || !mounted) return;

    List<Map<String, dynamic>> receivedItems = [];
    for (final entry in result.entries) {
      if (entry.value > 0) {
        receivedItems.add({'variant_id': entry.key, 'received_qty': entry.value});
      }
    }

    if (receivedItems.isEmpty) return;

    try {
      await supabase.rpc('receive_purchase_order_items', params: {
        'p_po_id': orderId,
        'p_items': jsonEncode(receivedItems),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stock reçu avec succès'), backgroundColor: Colors.green),
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
    IconData icon;
    Color color;
    String label;
    switch (status) {
      case 'draft':
      case 'pending':
        icon = Icons.edit;
        color = Colors.grey;
        label = 'Brouillon';
        break;
      case 'confirmed':
      case 'approved':
        icon = Icons.check;
        color = Colors.blue;
        label = 'Confirmée';
        break;
      case 'partially_received':
        icon = Icons.hourglass_bottom;
        color = Colors.orange;
        label = 'Partiellement reçue';
        break;
      case 'received':
        icon = Icons.done_all;
        color = Colors.green;
        label = 'Reçue';
        break;
      case 'cancelled':
        icon = Icons.strikethrough_s;
        color = Colors.red;
        label = 'Annulée';
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
        onPressed: _showCreateOrderDialog,
        child: const Icon(Icons.add),
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
                    final isCancelled = status == 'cancelled';

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
                                      Text(o['order_number'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isCancelled ? Colors.grey : null)),
                                      const SizedBox(width: 8),
                                      _buildStatusChip(status),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${o['total_amount'] ?? 0} ${S.t('misc_currency')}',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isCancelled ? Colors.grey : Colors.indigo),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${o['supplier_id']?['company_name'] ?? '—'}',
                              style: TextStyle(color: isCancelled ? Colors.grey[400] : Colors.grey[700], fontSize: 14),
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
                            if (status == 'received' && o['received_at'] != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.check_circle, size: 14, color: Colors.green[400]),
                                  const SizedBox(width: 4),
                                  Text('Reçue le ${_formatDate(o['received_at'].toString())}', style: TextStyle(color: Colors.green[700], fontSize: 12)),
                                ],
                              ),
                            ],
                            if (o['notes'] != null && (o['notes'] as String).isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text('${o['notes']}', style: TextStyle(color: isCancelled ? Colors.grey[300] : Colors.grey[500], fontSize: 12, fontStyle: FontStyle.italic)),
                            ],
                            if (status == 'draft' || status == 'pending') ...[
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
                                  if (status == 'draft' || status == 'pending')
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.check_circle, size: 16),
                                      label: const Text('Confirmer'),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                                      onPressed: AppSession.isOwner
                                          ? () async {
                                              final confirm = await showDialog<bool>(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  title: const Text('Confirmer la commande'),
                                                  content: Text('Confirmer ${o['order_number']} ?'),
                                                  actions: [
                                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
                                                    ElevatedButton(
                                                      onPressed: () => Navigator.pop(ctx, true),
                                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                                                      child: const Text('Oui, confirmer'),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (confirm == true) _confirmOrder(o['id']);
                                            }
                                          : null,
                                    ),
                                ],
                              ),
                            ],
                            if (status == 'confirmed' || status == 'partially_received') ...[
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
                                  if (AppSession.isOwner)
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.inventory, size: 16),
                                      label: const Text('Recevoir le stock'),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                      onPressed: () => _receiveStock(o['id'] as String, o['store_id'] as String, items),
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

  // ── CREATE PURCHASE ORDER ─────────────────────
  void _showCreateOrderDialog() {
    final storeIdCtrl = AppSession.currentStoreId ?? (_stores.isNotEmpty ? _stores.first['id'] as String : '');
    String? selectedSupplierId;
    final notesCtrl = TextEditingController();
    final items = <Map<String, dynamic>>[];
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    void addItem() {
      items.add({
        'variant_id': null,
        'variant_search': '',
        'quantity': 1,
        'unit_price': 0.0,
        'variants': <dynamic>[],
        'is_loading': false,
      });
    }

    addItem();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          double total = 0;
          for (final item in items) {
            final qty = (item['quantity'] as int?) ?? 0;
            final price = (item['unit_price'] as num?)?.toDouble() ?? 0;
            total += qty * price;
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Title
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.add_shopping_cart, color: Colors.indigo),
                          const SizedBox(width: 8),
                          const Text('Nouveau Bon de Commande',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Form fields
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Supplier
                            FutureBuilder<List<dynamic>>(
                              future: supabase.from('suppliers').select('id, company_name').eq('is_active', true).order('company_name'),
                              builder: (ctx, snapshot) {
                                final suppliers = snapshot.data ?? [];
                                return DropdownButtonFormField<String>(
                                  decoration: const InputDecoration(
                                    labelText: 'Fournisseur *',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    isDense: true,
                                  ),
                                  value: selectedSupplierId,
                                  items: suppliers.map((s) => DropdownMenuItem(
                                    value: s['id'] as String,
                                    child: Text(s['company_name'] as String),
                                  )).toList(),
                                  onChanged: (v) => setSheetState(() => selectedSupplierId = v),
                                  validator: (v) => v == null ? 'Requis' : null,
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            // Store
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Magasin',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                isDense: true,
                              ),
                              value: storeIdCtrl,
                              items: _stores.map((s) => DropdownMenuItem(
                                value: s['id'] as String,
                                child: Text(s['name'] as String),
                              )).toList(),
                              onChanged: (_) {},
                            ),
                            const SizedBox(height: 12),
                            // Notes
                            TextFormField(
                              controller: notesCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Notes',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                isDense: true,
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 16),
                            // Items header
                            Row(
                              children: [
                                const Text('Articles', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                const Spacer(),
                                TextButton.icon(
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Ajouter'),
                                  onPressed: () => setSheetState(() => addItem()),
                                ),
                              ],
                            ),
                            // Items list
                            ...items.asMap().entries.map((entry) {
                              final i = entry.key;
                              final item = entry.value;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildVariantSearchField(item, setSheetState),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.close, size: 18, color: Colors.red),
                                            onPressed: items.length > 1
                                                ? () => setSheetState(() => items.removeAt(i))
                                                : null,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              initialValue: '${item['quantity']}',
                                              decoration: const InputDecoration(
                                                labelText: 'Quantité',
                                                border: OutlineInputBorder(),
                                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                isDense: true,
                                              ),
                                              keyboardType: TextInputType.number,
                                              onChanged: (v) => item['quantity'] = int.tryParse(v) ?? 1,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextFormField(
                                              initialValue: item['unit_price'] > 0 ? '${item['unit_price']}' : '',
                                              decoration: const InputDecoration(
                                                labelText: 'Prix unitaire',
                                                border: OutlineInputBorder(),
                                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                isDense: true,
                                              ),
                                              keyboardType: TextInputType.number,
                                              onChanged: (v) => item['unit_price'] = double.tryParse(v) ?? 0,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                    // Total + Confirm
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        border: Border(top: BorderSide(color: Colors.grey[200]!)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              Text('${total.toStringAsFixed(2)} ${S.t('misc_currency')}',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo[700],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      if (!formKey.currentState!.validate()) return;
                                      setSheetState(() => isSubmitting = true);
                                      try {
                                        final itemsPayload = items.where((i) => i['variant_id'] != null).map((i) => {
                                          'variant_id': i['variant_id'],
                                          'quantity': i['quantity'],
                                          'unit_price': i['unit_price'],
                                        }).toList();
                                        if (itemsPayload.isEmpty) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Ajoutez au moins un article'), backgroundColor: Colors.red),
                                          );
                                          setSheetState(() => isSubmitting = false);
                                          return;
                                        }
                                        await supabase.rpc('create_purchase_order', params: {
                                          'p_store_id': storeIdCtrl,
                                          'p_supplier_id': selectedSupplierId,
                                          'p_notes': notesCtrl.text,
                                          'p_items': itemsPayload,
                                        });
                                        if (ctx.mounted) Navigator.pop(ctx);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Bon de commande créé'), backgroundColor: Colors.green),
                                          );
                                          _fetchOrders();
                                        }
                                      } catch (e) {
                                        setSheetState(() => isSubmitting = false);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
                                          );
                                        }
                                      }
                                    },
                              child: isSubmitting
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('Confirmer la commande', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVariantSearchField(Map<String, dynamic> item, StateSetter setSheetState) {
    return Autocomplete<String>(
      optionsBuilder: (textEditingValue) async {
        if (textEditingValue.text.isEmpty) return [];
        item['is_loading'] = true;
        setSheetState(() {});
        final q = textEditingValue.text.toLowerCase();
        try {
          final res = await supabase
              .from('product_variants')
              .select('id, size, color, barcode, buy_price, products(name)')
              .or('barcode.ilike.%$q%,products.name.ilike.%$q%')
              .limit(20);
          item['variants'] = res;
          return res.map<String>((v) {
            final name = v['products']?['name'] ?? '';
            final size = v['size'] ?? '';
            final color = v['color'] ?? '';
            final barcode = v['barcode'] ?? '';
            return '$name $size $color ($barcode)';
          }).toList();
        } catch (_) {
          return [];
        } finally {
          item['is_loading'] = false;
          setSheetState(() {});
        }
      },
      initialValue: TextEditingValue(text: item['variant_search'] as String? ?? ''),
      onSelected: (selection) {
        final variants = item['variants'] as List<dynamic>;
        final idx = variants.indexWhere((v) {
          final name = v['products']?['name'] ?? '';
          final size = v['size'] ?? '';
          final color = v['color'] ?? '';
          final barcode = v['barcode'] ?? '';
          return '$name $size $color ($barcode)' == selection;
        });
        if (idx >= 0) {
          final v = variants[idx];
          item['variant_id'] = v['id'];
          item['variant_search'] = selection;
          if ((item['unit_price'] as num?)?.toDouble() == 0) {
            item['unit_price'] = (v['buy_price'] as num?)?.toDouble() ?? 0;
          }
          setSheetState(() {});
        }
      },
      fieldViewBuilder: (ctx, controller, focusNode, onSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Rechercher un produit...',
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            isDense: true,
            suffixIcon: item['is_loading'] == true
                ? const SizedBox(width: 20, height: 20, child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ))
                : null,
          ),
          onChanged: (v) {
            item['variant_search'] = v;
            if (v.isEmpty) {
              item['variant_id'] = null;
              item['variants'] = [];
            }
          },
        );
      },
      displayStringForOption: (option) => option,
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

class _ReceiveStockDialog extends StatefulWidget {
  final List<Map<String, dynamic>> poItems;
  const _ReceiveStockDialog({required this.poItems});

  @override
  State<_ReceiveStockDialog> createState() => _ReceiveStockDialogState();
}

class _ReceiveStockDialogState extends State<_ReceiveStockDialog> {
  final Map<String, TextEditingController> _controllers = {};
  bool _isLoadingVariants = true;
  List<dynamic> _variantDetails = [];

  @override
  void initState() {
    super.initState();
    for (final item in widget.poItems) {
      final vid = item['variant_id'] as String;
      _controllers[vid] = TextEditingController(
        text: (item['received_qty'] as int? ?? 0).toString(),
      );
    }
    _fetchVariantDetails();
  }

  Future<void> _fetchVariantDetails() async {
    try {
      final variantIds = widget.poItems.map((i) => i['variant_id'] as String).toList();
      final res = await Supabase.instance.client
          .from('product_variants')
          .select('id, size, color, product_id, product:products(name)')
          .inFilter('id', variantIds);
      if (mounted) {
        setState(() {
          _variantDetails = res;
          _isLoadingVariants = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingVariants = false);
    }
  }

  Map<String, dynamic> _variantInfo(String variantId) {
    try {
      return _variantDetails.firstWhere((v) => v['id'] == variantId) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Réception de stock'),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoadingVariants
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Saisir les quantités reçues:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 12),
                  ...widget.poItems.map((item) {
                    final vid = item['variant_id'] as String;
                    final info = _variantInfo(vid);
                    final orderedQty = item['quantity'] as int? ?? 0;
                    final product = info['product'] as Map<String, dynamic>?;
                    final productName = product?['name'] ?? '—';
                    final size = info['size'] ?? '—';
                    final color = info['color'] ?? '—';
                    final alreadyReceived = item['received_qty'] as int? ?? 0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                Text('Taille: $size  Couleur: $color', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                                Text('Commandé: $orderedQty  Reçu: $alreadyReceived', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: TextField(
                              controller: _controllers[vid],
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            final result = <String, int>{};
            for (final item in widget.poItems) {
              final vid = item['variant_id'] as String;
              final val = int.tryParse(_controllers[vid]?.text ?? '') ?? 0;
              if (val >= 0) result[vid] = val;
            }
            Navigator.pop(context, result);
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          child: const Text('Valider la réception'),
        ),
      ],
    );
  }
}
