import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/app_strings.dart';
import '../../core/app_session.dart';

class EmployeeDashboard extends StatefulWidget {
  const EmployeeDashboard({super.key});

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      _PosTab(),
      _ProductsTab(),
      _InventoryTab(),
      _CustomersTab(),
      _SalesTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(S.t('owner_dash_title')),
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.indigo[900],
        onTap: (i) => setState(() => _currentIndex = i),
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.point_of_sale), label: S.t('nav_pos')),
          BottomNavigationBarItem(icon: const Icon(Icons.inventory_2), label: S.t('nav_products')),
          BottomNavigationBarItem(icon: const Icon(Icons.inventory), label: S.t('nav_inventory')),
          BottomNavigationBarItem(icon: const Icon(Icons.people), label: S.t('nav_clients')),
          BottomNavigationBarItem(icon: const Icon(Icons.history), label: S.t('nav_sales')),
        ],
      ),
    );
  }
}

class _PosTab extends StatefulWidget {
  @override
  State<_PosTab> createState() => _PosTabState();
}

class _PosTabState extends State<_PosTab> {
  void _scanBarcode() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.8,
          child: Column(
            children: [
              AppBar(
                title: Text(S.t('owner_scanner_title')),
                automaticallyImplyLeading: false,
                backgroundColor: Colors.indigo[900],
                foregroundColor: Colors.white,
                actions: [
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
                ],
              ),
              Expanded(
                child: MobileScanner(
                  onDetect: (capture) {
                    final barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty) {
                      final barcode = barcodes.first.rawValue;
                      if (barcode != null) {
                        Navigator.pop(context);
                        _lookupBarcode(barcode);
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _lookupBarcode(String barcode) async {
    try {
      final res = await Supabase.instance.client
          .from('product_variants')
          .select('id, size, color, sell_price, products(name), inventory!inner(quantity, store_id)')
          .eq('barcode', barcode)
          .eq('inventory.store_id', AppSession.currentStoreId!)
          .maybeSingle();

      if (res == null || !mounted) return;
      final qty = (res['inventory']?['quantity'] as int?) ?? 0;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(res['products']['name']),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${S.t('prod_size')}: ${res['size']} | ${S.t('prod_color')}: ${res['color']}'),
            Text('${S.t('prod_sell_short')}${res['sell_price']} ${S.t('misc_currency')}'),
            Text('${S.t('label_stock')}: $qty'),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.t('action_close')))],
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.qr_code_scanner, size: 80, color: Colors.indigo[200]),
          const SizedBox(height: 16),
          Text(S.t('owner_scanner_hint'), style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _scanBarcode,
            icon: const Icon(Icons.qr_code_scanner),
            label: Text(S.t('owner_scanner_start')),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo[900], foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _ProductsTab extends StatefulWidget {
  @override
  State<_ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<_ProductsTab> {
  List<dynamic> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final res = await Supabase.instance.client
          .from('products')
          .select('''
            id, name,
            product_variants(id, size, color, barcode, sell_price, is_active,
              inventory!inner(quantity, store_id)
            )
          ''')
          .eq('is_active', true)
          .eq('product_variants.is_active', true)
          .eq('product_variants.inventory.store_id', AppSession.currentStoreId!);
      if (mounted) setState(() { _products = res; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_products.isEmpty) return Center(child: Text(S.t('prod_no_results')));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final p = _products[index];
        final variants = (p['product_variants'] as List?)?.where((v) => v['is_active'] == true).toList() ?? [];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            title: Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            children: variants.map<Widget>((v) {
              final qty = (v['inventory'] is List ? (v['inventory'] as List).fold(0, (s, i) => s + ((i['quantity'] as int?) ?? 0)) : (v['inventory']?['quantity'] as int?) ?? 0);
              return ListTile(
                title: Text('${v['size']} - ${v['color']}'),
                subtitle: Text('${S.t('prod_sell_price')}: ${v['sell_price']} ${S.t('misc_currency')}'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: qty > 0 ? Colors.green[50] : Colors.red[50], borderRadius: BorderRadius.circular(8)),
                  child: Text('$qty', style: TextStyle(fontWeight: FontWeight.bold, color: qty > 0 ? Colors.green[800] : Colors.red)),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _InventoryTab extends StatefulWidget {
  @override
  State<_InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<_InventoryTab> {
  List<dynamic> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final res = await Supabase.instance.client
          .from('inventory')
          .select('quantity, product_variants!inner(id, size, color, products!inner(name))')
          .eq('store_id', AppSession.currentStoreId!)
          .order('quantity');
      if (mounted) setState(() { _items = res; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) return Center(child: Text(S.t('inv_no_products')));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final v = item['product_variants'];
        final qty = (item['quantity'] as int?) ?? 0;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(v['products']['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${S.t('prod_size')}: ${v['size']} | ${S.t('prod_color')}: ${v['color']}'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: qty < 3 ? Colors.red[50] : Colors.green[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: qty < 3 ? Colors.red : Colors.green[800])),
            ),
          ),
        );
      },
    );
  }
}

class _CustomersTab extends StatefulWidget {
  @override
  State<_CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<_CustomersTab> {
  List<dynamic> _customers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final res = await Supabase.instance.client
          .from('customers')
          .select()
          .eq('is_active', true)
          .order('full_name');
      if (mounted) setState(() { _customers = res; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addCustomer() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.t('cust_add')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Téléphone', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.t('action_cancel'))),
          ElevatedButton(onPressed: () async {
            if (nameCtrl.text.isEmpty) return;
            Navigator.pop(ctx);
            try {
              await Supabase.instance.client.from('customers').insert({'full_name': nameCtrl.text.trim(), 'phone': phoneCtrl.text.trim(), 'balance': 0, 'is_active': true});
              try {
                await Supabase.instance.client.from('activity_logs').insert({
                  'user_id': AppSession.currentUserId,
                  'action_type': 'add_customer',
                  'description': 'Nouveau client: ${nameCtrl.text.trim()}',
                });
              } catch (_) {}
              _fetch();
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
            }
          }, child: Text(S.t('action_save'))),
        ],
      ),
    );
  }

  void _recordPayment(Map<String, dynamic> customer) {
    final amountCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.t('cust_receive_payment')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${S.t('pos_credit')}: ${(customer['balance'] as num?)?.toDouble() ?? 0} ${S.t('misc_currency')}'),
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
              await Supabase.instance.client.from('payments').insert({
                'customer_id': customer['id'], 'user_id': AppSession.currentUserId, 'amount': amount,
                'payment_method': 'cash', 'notes': 'Paiement mobile employee',
              });
              try {
                await Supabase.instance.client.from('activity_logs').insert({
                  'user_id': AppSession.currentUserId, 'action_type': 'debt_payment',
                  'description': 'Paiement reçu de ${customer['full_name']} — $amount ${S.t('misc_currency')}',
                });
              } catch (_) {}
              _fetch();
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
            }
          }, child: Text(S.t('action_confirm'))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(child: Text('${_customers.length} ${S.t('nav_clients')}', style: const TextStyle(fontWeight: FontWeight.bold))),
              IconButton(icon: const Icon(Icons.person_add), onPressed: _addCustomer),
            ],
          ),
        ),
        Expanded(
          child: _customers.isEmpty
              ? Center(child: Text(S.t('cust_no_results')))
              : ListView.builder(
                  itemCount: _customers.length,
                  itemBuilder: (context, index) {
                    final c = _customers[index];
                    final balance = (c['balance'] as num?)?.toDouble() ?? 0;
                    return ListTile(
                      title: Text(c['full_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(c['phone'] ?? ''),
                      trailing: balance > 0
                          ? Row(mainAxisSize: MainAxisSize.min, children: [
                              Text('${balance.toStringAsFixed(0)} ${S.t('misc_currency')}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              IconButton(icon: const Icon(Icons.payments, color: Colors.green), onPressed: () => _recordPayment(c)),
                            ])
                          : const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SalesTab extends StatefulWidget {
  @override
  State<_SalesTab> createState() => _SalesTabState();
}

class _SalesTabState extends State<_SalesTab> {
  List<dynamic> _sales = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final res = await Supabase.instance.client
          .from('transactions')
          .select('id, invoice_number, invoice_id, quantity, total_price, created_at, type, invoices(status), product_variants(id, products(name), size, color)')
          .eq('type', 'out')
          .eq('store_id', AppSession.currentStoreId!)
          .order('created_at', ascending: false)
          .limit(50);
      if (mounted) setState(() { _sales = res; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _refund(Map<String, dynamic> sale) async {
    final createdAtStr = sale['created_at'] as String?;
    if (createdAtStr == null) return;
    final hoursSince = DateTime.now().difference(DateTime.parse(createdAtStr)).inHours;

    if (hoursSince > 48) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.t('refund_48h_blocked')), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.t('refund_title')),
        content: Text('${S.t('refund_original_invoice')} ${sale['invoice_number']}\n${S.t('refund_total_amount')} ${sale['total_price']} ${S.t('misc_currency')}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.t('action_cancel'))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: Text(S.t('refund_confirm'))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final invoiceId = sale['invoice_id'] ?? sale['id'];
      final items = [{'variant_id': sale['product_variants']?['id'] ?? sale['variant_id'], 'quantity': sale['quantity']}];
      final response = await Supabase.instance.client.rpc('process_refund', params: {
        'p_invoice_id': invoiceId, 'p_items': items, 'p_refund_amount': sale['total_price'],
      });
      try {
        await Supabase.instance.client.from('activity_logs').insert({
          'user_id': AppSession.currentUserId, 'action_type': 'refund',
          'description': 'Refund from mobile — invoice ${sale['invoice_number']} (employee)',
          'invoice_id': invoiceId, 'amount': sale['total_price'],
        });
      } catch (_) {}
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${S.t('refund_success')} $response'), backgroundColor: Colors.green));
      _fetch();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_sales.isEmpty) return Center(child: Text(S.t('label_no_data')));
    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _sales.length,
        itemBuilder: (context, index) {
          final s = _sales[index];
          final status = s['invoices']?['status'] as String?;
          final isRefunded = status == 'refunded';
          return Card(
            child: ListTile(
              title: Text('${s['product_variants']?['products']?['name'] ?? ''} (${s['product_variants']?['size'] ?? ''})'),
              subtitle: Text('${s['invoice_number']} • ${s['created_at']?.toString().substring(0, 10) ?? ''}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('${s['total_price']} ${S.t('misc_currency')}', style: TextStyle(decoration: isRefunded ? TextDecoration.lineThrough : null, color: isRefunded ? Colors.red : Colors.black)),
                if (status == 'paid')
                  IconButton(icon: const Icon(Icons.assignment_return, color: Colors.red, size: 20), onPressed: () => _refund(s)),
              ]),
            ),
          );
        },
      ),
    );
  }
}