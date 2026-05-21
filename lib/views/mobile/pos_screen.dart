import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/app_session.dart';
import '../../core/app_strings.dart';
import '../../services/invoice_service.dart';
import '../../local_db/isar_service.dart';
import '../../local_db/collections/product_local.dart';
import '../../local_db/collections/product_variant_local.dart';
import '../../local_db/collections/inventory_local.dart';
import '../../local_db/collections/customer_local.dart';
import '../../local_db/collections/store_local.dart';
class CartItem {
  final String variantId;
  final String productName;
  final String size;
  final String color;
  int quantity;
  double unitPrice;
  CartItem({required this.variantId, required this.productName, required this.size, required this.color, required this.quantity, required this.unitPrice});
  double get totalPrice => quantity * unitPrice;
}

class PosScreenMobile extends StatefulWidget {
  const PosScreenMobile({super.key});
  @override
  State<PosScreenMobile> createState() => _PosScreenMobileState();
}

class _PosScreenMobileState extends State<PosScreenMobile> {
  final _searchCtrl = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false, _isLoading = true, _processing = false;
  final List<CartItem> _cart = [];
  String? _storeId, _storeName, _customerId;
  List<dynamic> _customers = [];
  double _discountPercent = 0;
  bool _hasDiscount = false;
  final Map<String, int> _cachedStock = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  double get _subtotal => _cart.fold(0.0, (s, i) => s + i.totalPrice);
  double get _discountAmount => _hasDiscount ? _subtotal * _discountPercent / 100 : 0;
  double get _total => _subtotal - _discountAmount;

  Future<void> _init() async {
    _storeId = AppSession.currentStoreId;
    if (AppSession.isOfflineMode) {
      try {
        final isar = await IsarService.getInstance();
        if (_storeId != null) {
          final store = await isar.storeLocals.where().findFirst();
          _storeName = store?.name;
        }
        final cs = await isar.customerLocals.where().findAll();
        _customers = cs.map((c) => {'id': c.supabaseId, 'full_name': c.fullName}).toList();
        if (mounted) setState(() => _isLoading = false);
      } catch (_) { if (mounted) setState(() => _isLoading = false); }
      return;
    }
    try {
      final res = await Supabase.instance.client.from('customers').select('id, full_name').eq('is_active', true).order('full_name');
      if (mounted) setState(() { _customers = res; _isLoading = false; });
    } catch (_) { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _search(String q) async {
    setState(() => _isSearching = true);
    if (AppSession.isOfflineMode) {
      try {
        final isar = await IsarService.getInstance();
        final variants = await isar.productVariantLocals.where().findAll();
        final products = await isar.productLocals.where().findAll();
        final inv = await isar.inventoryLocals.where().findAll();
        final pMap = {for (var p in products) p.supabaseId: p};
        final results = variants.where((v) {
          if (!v.isActive) return false;
          final p = pMap[v.productId];
          if (p == null) return false;
          if (q.isEmpty) return true;
          final query = q.toLowerCase();
          return p.name.toLowerCase().contains(query) || (v.barcode?.toLowerCase().contains(query) ?? false);
        }).map((v) {
          final p = pMap[v.productId]!;
          final invs = inv.where((i) => i.variantId == v.supabaseId).map((i) => {'quantity': i.quantity, 'store_id': i.storeId}).toList();
          return {'id': v.supabaseId, 'size': v.size, 'color': v.color, 'barcode': v.barcode, 'sell_price': v.sellPrice, 'products': {'name': p.name, 'image_url': p.imageUrl}, 'inventory': invs};
        }).take(40).toList();
        if (mounted) setState(() { _searchResults = results; _isSearching = false; });
      } catch (_) { if (mounted) setState(() => _isSearching = false); }
      return;
    }
    try {
      var qb = Supabase.instance.client.from('product_variants').select('id, size, color, barcode, sell_price, products!inner(name, image_url), inventory(quantity, store_id)').eq('is_active', true);
      if (q.isNotEmpty) qb = qb.or('barcode.ilike.%$q%,products.name.ilike.%$q%');
      final res = await qb.limit(40);
      if (mounted) setState(() { _searchResults = res; _isSearching = false; });
    } catch (_) { if (mounted) setState(() => _isSearching = false); }
  }

  void _addToCart(dynamic v) {
    if (_storeId == null) return;
    final invList = (v['inventory'] as List?) ?? [];
    int avail = 0;
    for (var i in invList) { if (i['store_id'] == _storeId) avail += (i['quantity'] as int?) ?? 0; }
    if (avail <= 0) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.t('pos_stock_empty_warning')), backgroundColor: Colors.orange)); return; }
    final vid = v['id'];
    final inCart = _cart.where((i) => i.variantId == vid).fold(0, (s, i) => s + i.quantity);
    if (inCart >= avail) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${S.t('pos_stock_insufficient')} $avail'), backgroundColor: Colors.red)); return; }
    final idx = _cart.indexWhere((i) => i.variantId == vid);
    if (idx >= 0) { setState(() => _cart[idx].quantity++); }
    else {
      setState(() => _cart.add(CartItem(variantId: vid, productName: v['products']['name'], size: v['size'], color: v['color'], quantity: 1, unitPrice: (v['sell_price'] as num?)?.toDouble() ?? 0)));
      _cachedStock[vid] = avail;
    }
    _searchCtrl.clear();
    _search('');
  }

  void _scanBarcode() {
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (ctx) {
      return FractionallySizedBox(heightFactor: 0.8, child: Column(children: [
        AppBar(title: Text(S.t('owner_scanner_title')), automaticallyImplyLeading: false, backgroundColor: Colors.indigo[900], foregroundColor: Colors.white,
          actions: [IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))]),
        Expanded(child: MobileScanner(onDetect: (c) {
          final b = c.barcodes.firstOrNull?.rawValue;
          if (b != null) { Navigator.pop(ctx); _searchCtrl.text = b; _search(b); }
        })),
      ]));
    });
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty) return;
    final result = await showDialog<String>(context: context, builder: (ctx) => _PaymentDialog(
      total: _total, discountAmount: _discountAmount, hasDiscount: _hasDiscount,
      customerId: _customerId, customers: _customers,
    ));
    if (result == null) return;
    final parts = result.split('|');
    final method = parts[0];
    final paidAmount = double.tryParse(parts[1]) ?? _total;
    setState(() => _processing = true);
    try {
      final items = _cart.map((i) => {'variant_id': i.variantId, 'quantity': i.quantity, 'unit_price': i.unitPrice, 'total_price': i.totalPrice}).toList();
      final invoiceNum = 'INV-${DateTime.now().millisecondsSinceEpoch}';
      await InvoiceService.instance.processSale(
        storeId: _storeId!, invoiceNumber: invoiceNum, items: items,
        totalAmount: _total, paidAmount: paidAmount, paymentMethod: method,
        customerId: _customerId,
      );
      if (mounted) {
        setState(() { _cart.clear(); _customerId = null; _hasDiscount = false; _discountPercent = 0; _processing = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${S.t('pos_sale_success')} $invoiceNum'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) { setState(() => _processing = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red)); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.t('nav_pos')),
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.qr_code_scanner), onPressed: _scanBarcode),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Store + Customer bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: Colors.grey[50],
                  child: Row(
                    children: [
                      Icon(Icons.store, size: 16, color: Colors.indigo[900]),
                      const SizedBox(width: 4),
                      Text(_storeName ?? S.t('pos_select_store'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const Spacer(),
                      if (_customers.isNotEmpty)
                        GestureDetector(
                          onTap: () => _selectCustomer(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.indigo[50], borderRadius: BorderRadius.circular(8)),
                            child: Text(_customerId != null ? _customers.firstWhere((c) => c['id'] == _customerId, orElse: () => {'full_name': ''})['full_name'] ?? '' : S.t('pos_select_client'), style: const TextStyle(fontSize: 11, color: Colors.indigo)),
                          ),
                        ),
                    ],
                  ),
                ),
                // Search
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.white,
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: S.t('prod_search_hint'),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchCtrl.clear(); _search(''); })
                          : null,
                    ),
                    onChanged: _search,
                  ),
                ),
                // Results + Cart
                Expanded(
                  child: Row(
                    children: [
                      // Products panel
                      Expanded(
                        flex: 3,
                        child: _isSearching
                            ? const Center(child: CircularProgressIndicator())
                            : _searchResults.isEmpty
                                ? Center(child: Text(S.t('prod_no_results'), style: const TextStyle(color: Colors.grey)))
                                : ListView.builder(
                                    padding: const EdgeInsets.all(4),
                                    itemCount: _searchResults.length,
                                    itemBuilder: (_, i) {
                                      final v = _searchResults[i];
                                      final invList = (v['inventory'] as List?) ?? [];
                                      int stock = 0;
                                      for (var inv in invList) { if (inv['store_id'] == _storeId) stock += (inv['quantity'] as int?) ?? 0; }
                                      return Card(
                                        margin: const EdgeInsets.only(bottom: 4),
                                        child: ListTile(
                                          dense: true,
                                          leading: v['products']?['image_url'] != null
                                              ? ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(v['products']['image_url'], width: 36, height: 36, fit: BoxFit.cover))
                                              : Container(width: 36, height: 36, color: Colors.grey[200], child: const Icon(Icons.image, size: 18)),
                                          title: Text(v['products']?['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                          subtitle: Text('${v['size']} / ${v['color']} — ${v['sell_price']} ${S.t('misc_currency')}', style: const TextStyle(fontSize: 11)),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: stock < 3 ? Colors.red[50] : Colors.green[50],
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text('$stock', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: stock < 3 ? Colors.red : Colors.green[800])),
                                              ),
                                              const SizedBox(width: 4),
                                              IconButton(
                                                icon: const Icon(Icons.add_shopping_cart, size: 18, color: Colors.indigo),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onPressed: stock > 0 ? () => _addToCart(v) : null,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                      // Cart panel
                      Container(
                        width: 1,
                        color: Colors.grey[300],
                      ),
                      Expanded(
                        flex: 4,
                        child: _cart.isEmpty
                            ? Center(child: Text(S.t('pos_cart_empty'), style: const TextStyle(color: Colors.grey)))
                            : Column(
                                children: [
                                  Expanded(
                                    child: ListView.builder(
                                      padding: const EdgeInsets.all(4),
                                      itemCount: _cart.length,
                                      itemBuilder: (_, i) {
                                        final item = _cart[i];
                                        return Card(
                                          margin: const EdgeInsets.only(bottom: 4),
                                          child: Padding(
                                            padding: const EdgeInsets.all(8),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(child: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                                    IconButton(
                                                      icon: const Icon(Icons.close, size: 16, color: Colors.red),
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(),
                                                      onPressed: () => setState(() => _cart.removeAt(i)),
                                                    ),
                                                  ],
                                                ),
                                                Text('${item.size} / ${item.color}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        _qtyBtn(Icons.remove, item.quantity <= 1 ? null : () => setState(() => item.quantity--)),
                                                        const SizedBox(width: 6),
                                                        Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                                        const SizedBox(width: 6),
                                                        _qtyBtn(Icons.add, () => setState(() => item.quantity++)),
                                                      ],
                                                    ),
                                                    const Spacer(),
                                                    Text('${item.totalPrice.toStringAsFixed(0)} ${S.t('misc_currency')}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  // Totals
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, -2))],
                                    ),
                                    child: Column(
                                      children: [
                                        if (_hasDiscount) ...[
                                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                            Text(S.t('pos_discount'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                            Text('-$_discountPercent%', style: const TextStyle(fontSize: 12, color: Colors.red)),
                                          ]),
                                          const SizedBox(height: 4),
                                        ],
                                        Row(
                                          children: [
                                            Expanded(
                                              child: GestureDetector(
                                                onTap: () => _showDiscountDialog(),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: _hasDiscount ? Colors.red[50] : Colors.grey[100],
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.percent, size: 14, color: _hasDiscount ? Colors.red : Colors.grey),
                                                      const SizedBox(width: 4),
                                                      Text(_hasDiscount ? '$_discountPercent%' : S.t('pos_discount'), style: TextStyle(fontSize: 11, color: _hasDiscount ? Colors.red : Colors.grey[600])),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text('${S.t('pos_total')}: ', style: const TextStyle(fontSize: 16)),
                                            Text('${_total.toStringAsFixed(0)} ${S.t('misc_currency')}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo[900])),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(vertical: 14),
                                            ),
                                            onPressed: _processing ? null : _checkout,
                                            child: _processing
                                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                                : Text(S.t('pos_confirm_payment'), style: const TextStyle(fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _selectCustomer() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(S.t('pos_select_client'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ..._customers.map((c) => ListTile(
            title: Text(c['full_name'] ?? ''),
            trailing: c['id'] == _customerId ? const Icon(Icons.check, color: Colors.green) : null,
            onTap: () { Navigator.pop(ctx); setState(() => _customerId = c['id']); },
          )),
          ListTile(
            leading: const Icon(Icons.remove_circle_outline, color: Colors.grey),
            title: Text(S.t('pos_no_client')),
            onTap: () { Navigator.pop(ctx); setState(() => _customerId = null); },
          ),
        ]),
      ),
    );
  }

  void _showDiscountDialog() {
    final ctrl = TextEditingController(text: _hasDiscount ? _discountPercent.toString() : '');
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(S.t('pos_discount')),
      content: TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Pourcentage %', border: OutlineInputBorder())),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.t('action_cancel'))),
        TextButton(onPressed: () { Navigator.pop(ctx); setState(() { _hasDiscount = false; _discountPercent = 0; }); }, child: Text(S.t('action_remove'), style: const TextStyle(color: Colors.red))),
        ElevatedButton(onPressed: () {
          final p = double.tryParse(ctrl.text) ?? 0;
          Navigator.pop(ctx);
          setState(() { _hasDiscount = p > 0; _discountPercent = p.clamp(0, 100); });
        }, child: Text(S.t('action_apply'))),
      ],
    ));
  }

  Widget _qtyBtn(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24, height: 24,
        decoration: BoxDecoration(
          color: onTap == null ? Colors.grey[100] : Colors.indigo[50],
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: onTap == null ? Colors.grey[300]! : Colors.indigo.withOpacity(0.3)),
        ),
        child: Icon(icon, size: 14, color: onTap == null ? Colors.grey[400] : Colors.indigo[900]),
      ),
    );
  }
}

// ─── PAYMENT DIALOG ─────────────────────────────
class _PaymentDialog extends StatefulWidget {
  final double total;
  final double discountAmount;
  final bool hasDiscount;
  final String? customerId;
  final List<dynamic> customers;
  const _PaymentDialog({required this.total, required this.discountAmount, required this.hasDiscount, this.customerId, required this.customers});
  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  String _method = 'cash';
  String _numpadValue = '';

  @override
  Widget build(BuildContext context) {
    final total = widget.total;
    final cashAmount = double.tryParse(_numpadValue) ?? 0;
    final change = cashAmount - total;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(S.t('pos_confirm_payment')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        // Amount
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.indigo[50], borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Text(S.t('pos_total'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 4),
            Text('${total.toStringAsFixed(0)} ${S.t('misc_currency')}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo[900])),
          ]),
        ),
        const SizedBox(height: 16),
        // Payment method
        Row(
          children: [
            _methodBtn('cash', 'Espèces', Icons.money, () => setState(() { _method = 'cash'; _numpadValue = ''; })),
            const SizedBox(width: 8),
            _methodBtn('credit', 'Crédit', Icons.credit_card, () => setState(() { _method = 'credit'; _numpadValue = ''; })),
            const SizedBox(width: 8),
            _methodBtn('mixed', 'Mixte', Icons.swap_horiz, () => setState(() { _method = 'mixed'; _numpadValue = ''; })),
          ],
        ),
        const SizedBox(height: 16),
        // Cash input (for cash/mixed)
        if (_method != 'credit')
          Column(children: [
            TextField(
              decoration: InputDecoration(
                labelText: '${S.t('pos_amount_received')} (${S.t('misc_currency')})',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) => setState(() => _numpadValue = v),
            ),
            if (cashAmount >= total && _method == 'cash')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('${S.t('pos_change_label')} ${change.toStringAsFixed(0)} ${S.t('misc_currency')}',
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ),
            if (_method == 'cash' && cashAmount > 0 && cashAmount < total)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('${S.t('pos_insufficient')} ${(total - cashAmount).toStringAsFixed(0)} ${S.t('misc_currency')}',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
          ]),
        if (_method == 'mixed')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('${S.t('pos_credit_amount')}: ${(total - cashAmount).toStringAsFixed(0)} ${S.t('misc_currency')}',
                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          ),
        // Credit note
        if (_method == 'credit')
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8)),
            child: Text(S.t('pos_credit_note'), style: const TextStyle(color: Colors.orange, fontSize: 12)),
          ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(S.t('action_cancel'))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          onPressed: () {
            if (_method == 'cash' && cashAmount < total) return;
            Navigator.pop(context, '$_method|${_method == 'credit' ? '0' : cashAmount.toString()}');
          },
          child: Text(S.t('pos_confirm_payment')),
        ),
      ],
    );
  }

  Widget _methodBtn(String method, String label, IconData icon, VoidCallback onTap) {
    final sel = _method == method;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? Colors.indigo[900] : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sel ? Colors.indigo[900]! : Colors.grey[300]!),
          ),
          child: Column(children: [
            Icon(icon, size: 18, color: sel ? Colors.white : Colors.grey[600]),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sel ? Colors.white : Colors.grey[600])),
          ]),
        ),
      ),
    );
  }
}
