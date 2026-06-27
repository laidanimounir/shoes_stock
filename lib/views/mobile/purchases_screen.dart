import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_strings.dart';
import '../../theme/app_colors.dart';
import '../../services/purchase_service.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});
  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  List<dynamic> _suppliers = [];
  List<dynamic> _variants = [];
  List<Map<String, dynamic>> _cart = [];
  String? _supplierId, _storeId;
  List<dynamic> _stores = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    try {
      final res = await Future.wait([
        Supabase.instance.client.from('suppliers').select().eq('is_active', true),
        Supabase.instance.client.from('stores').select().eq('is_active', true),
        Supabase.instance.client.from('product_variants').select('id, size, color, buy_price, products(name)').eq('is_active', true),
      ]);
      if (mounted) setState(() { _suppliers = res[0]; _stores = res[1]; _variants = res[2]; if (_stores.isNotEmpty) _storeId = _stores.first['id']; if (_suppliers.isNotEmpty) _supplierId = _suppliers.first['id']; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  int _totalQty = 0;
  double _totalCost = 0;

  void _addVariant(dynamic v) {
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController(text: '${v['buy_price'] ?? 0}');
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('${v['products']?['name'] ?? ''} ${v['size']} / ${v['color']}'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantité', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Prix d'achat unitaire", border: OutlineInputBorder())),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.t('action_cancel'))),
        ElevatedButton(onPressed: () {
          final qty = int.tryParse(qtyCtrl.text) ?? 1;
          final price = double.tryParse(priceCtrl.text) ?? 0;
          if (qty <= 0 || price <= 0) return;
          Navigator.pop(ctx);
          setState(() => _cart.add({'variant_id': v['id'], 'product_name': '${v['products']?['name'] ?? ''} ${v['size']}/${v['color']}', 'quantity': qty, 'unit_price': price}));
          _calcTotals();
        }, child: Text(S.t('action_add'))),
      ],
    ));
  }

  void _calcTotals() {
    _totalQty = _cart.fold(0, (s, i) => s + (i['quantity'] as int));
    _totalCost = _cart.fold(0.0, (s, i) => s + (i['quantity'] as int) * (i['unit_price'] as num).toDouble());
  }

  Future<void> _save() async {
    if (_supplierId == null || _storeId == null || _cart.isEmpty) return;
    setState(() => _loading = true);
    try {
      final items = _cart.map((item) => {
        'variant_id': item['variant_id'],
        'quantity': item['quantity'],
        'unit_price': item['unit_price'],
        'total_price': (item['quantity'] as int) * (item['unit_price'] as num).toDouble(),
      }).toList();

      await PurchaseService.instance.processPurchase(
        storeId: _storeId!,
        supplierId: _supplierId!,
        items: items,
        totalAmount: _totalCost,
        paidAmount: _totalCost,
        paymentMethod: 'cash',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Achat enregistré'), backgroundColor: AppColors.success));
        setState(() { _cart.clear(); _totalQty = 0; _totalCost = 0; });
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.t('nav_purchases')), backgroundColor: AppColors.mobileBackground, foregroundColor: Colors.white),
      body: _loading ? const Center(child: CircularProgressIndicator()) : Column(children: [
        Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Column(children: [
          DropdownButtonFormField<String>(value: _supplierId, decoration: const InputDecoration(labelText: 'Fournisseur', border: OutlineInputBorder()),
            items: _suppliers.map((s) => DropdownMenuItem<String>(value: s['id'] as String?, child: Text(s['company_name'] ?? ''))).toList(), onChanged: (v) => _supplierId = v),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(value: _storeId, decoration: const InputDecoration(labelText: 'Magasin', border: OutlineInputBorder()),
            items: _stores.map((s) => DropdownMenuItem<String>(value: s['id'] as String?, child: Text(s['name'] ?? ''))).toList(), onChanged: (v) => _storeId = v),
        ])),
        Expanded(
          child: Row(children: [
            Expanded(
              child: _variants.isEmpty ? Center(child: Text(S.t('prod_no_results'))) : ListView.builder(padding: const EdgeInsets.all(4), itemCount: _variants.length, itemBuilder: (_, i) {
                final v = _variants[i];
                return Card(margin: const EdgeInsets.only(bottom: 4), child: ListTile(dense: true,
                  title: Text('${v['products']?['name'] ?? ''} ${v['size']}/${v['color']}', style: const TextStyle(fontSize: 12)),
                  subtitle: Text('${v['buy_price']} ${S.t('misc_currency')}', style: const TextStyle(fontSize: 10)),
                  trailing: IconButton(icon: const Icon(Icons.add, size: 16), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => _addVariant(v)),
                ));
              }),
            ),
            Container(width: 1, color: AppColors.mobileBorderStrong),
            Expanded(
              child: _cart.isEmpty ? Center(child: Text(S.t('pos_cart_empty'))) : Column(children: [
                Expanded(child: ListView.builder(itemCount: _cart.length, itemBuilder: (_, i) {
                  final item = _cart[i];
                  return Card(margin: const EdgeInsets.all(4), child: Padding(padding: const EdgeInsets.all(8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Expanded(child: Text(item['product_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))), IconButton(icon: const Icon(Icons.close, size: 14), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => setState(() { _cart.removeAt(i); _calcTotals(); }))]),
                    Text('${item['quantity']} × ${item['unit_price']} = ${(item['quantity'] as int) * (item['unit_price'] as num).toDouble()} ${S.t('misc_currency')}', style: const TextStyle(fontSize: 11)),
                  ])));
                })),
                Container(padding: const EdgeInsets.all(12), child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('$_totalQty ${S.t('inv_units')} - ${S.t('pos_total')}:'), Text('$_totalCost ${S.t('misc_currency')}', style: const TextStyle(fontWeight: FontWeight.bold))]),
                  const SizedBox(height: 8),
                  SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white), onPressed: _cart.isEmpty ? null : _save, child: Text(S.t('action_save')))),
                ])),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}
