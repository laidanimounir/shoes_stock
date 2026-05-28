import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_strings.dart';
import '../../core/app_session.dart';
import '../../local_db/isar_service.dart';
import '../../local_db/collections/product_local.dart';
import '../../local_db/collections/product_variant_local.dart';
import '../../local_db/collections/supplier_local.dart';
import '../../local_db/collections/inventory_local.dart';
import 'add_product_screen.dart';

void _showEditProductDialog(BuildContext context, Map<String, dynamic> product) {
  final nameCtrl = TextEditingController(text: product['name'] ?? '');
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Modifier le produit'),
      content: TextField(
        controller: nameCtrl,
        decoration: const InputDecoration(labelText: 'Nom du produit', border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.t('action_cancel'))),
        ElevatedButton(
          onPressed: () async {
            if (nameCtrl.text.trim().isEmpty) return;
            try {
              await Supabase.instance.client.from('products').update({'name': nameCtrl.text.trim()}).eq('id', product['id']);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produit modifié'), backgroundColor: Colors.green));
            } catch (e) {
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
            }
          },
          child: Text(S.t('action_save')),
        ),
      ],
    ),
  );
}

void _toggleProductActive(BuildContext context, Map<String, dynamic> product) async {
  final newActive = !(product['is_active'] ?? true);
  try {
    await Supabase.instance.client.from('products').update({'is_active': newActive}).eq('id', product['id']);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(newActive ? 'Produit réactivé' : 'Produit archivé'),
      backgroundColor: newActive ? Colors.green : Colors.orange,
    ));
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
  }
}

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<dynamic> _products = [];
  bool _isLoading = true;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _filterCategory;
  String? _filterStockStatus;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    if (AppSession.isOfflineMode) {
      try {
        final isar = await IsarService.getInstance();
        final localProducts = await isar.productLocals.where().findAll();
        final localSuppliers = await isar.supplierLocals.where().findAll();
        final supplierMap = {for (var s in localSuppliers) s.supabaseId: s};
        final localVariants = await isar.productVariantLocals.where().findAll();
        final localInv = await isar.inventoryLocals.where().findAll();

        final results = localProducts.map((p) {
          final variants = localVariants.where((v) => v.productId == p.supabaseId).map((v) {
            final invs = localInv.where((i) => i.variantId == v.supabaseId).map((i) => {
              'quantity': i.quantity, 'store_id': i.storeId,
            }).toList();
            return {
              'id': v.supabaseId, 'size': v.size, 'color': v.color, 'barcode': v.barcode,
              'sell_price': v.sellPrice, 'buy_price': v.buyPrice, 'is_active': v.isActive,
              'inventory': invs,
            };
          }).toList();
          final supplier = supplierMap[p.supplierId];
          return {
            'id': p.supabaseId, 'name': p.name, 'image_url': p.imageUrl, 'category': p.category,
            'is_active': p.isActive,
            'suppliers': supplier != null ? {'company_name': supplier.companyName} : null,
            'product_variants': variants,
          };
        }).toList();
        if (mounted) setState(() { _products = results; _isLoading = false; });
      } catch (_) { if (mounted) setState(() => _isLoading = false); }
      return;
    }

    try {
      final res = await Supabase.instance.client
          .from('products')
          .select('id, name, image_url, category, is_active, suppliers(company_name), product_variants(id, size, color, barcode, sell_price, buy_price, is_active, inventory(quantity, store_id))')
          .order('created_at', ascending: false);
      if (mounted) setState(() { _products = res; _isLoading = false; });
    } catch (_) { if (mounted) setState(() => _isLoading = false); }
  }

  String? _filterArchiveStatus;

  List<dynamic> get _filtered {
    return _products.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      if (q.isNotEmpty && !name.contains(q)) return false;
      final isActive = p['is_active'] ?? true;
      if (_filterArchiveStatus == 'archived' && isActive == true) return false;
      if (_filterArchiveStatus == 'active' && isActive == false) return false;
      if (_filterCategory != null && p['category'] != _filterCategory) return false;
      if (_filterStockStatus != null) {
        final variants = (p['product_variants'] as List?) ?? [];
        int total = 0;
        for (var v in variants) {
          if (v['is_active'] == true) {
            for (var i in (v['inventory'] as List?) ?? []) {
              total += (i['quantity'] as int?) ?? 0;
            }
          }
        }
        if (_filterStockStatus == 'healthy' && total < 5) return false;
        if (_filterStockStatus == 'low' && (total < 1 || total >= 5)) return false;
        if (_filterStockStatus == 'empty' && total != 0) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.t('prod_catalog_title')),
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch),
        ],
      ),
      floatingActionButton: AppSession.isOwner
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddProductScreen()));
                _fetch();
              },
              backgroundColor: Colors.green,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.white,
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: S.t('prod_search_hint'),
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                // Filter chips
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  color: Colors.white,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chip('Tous', null, _filterCategory, () => setState(() => _filterCategory = null)),
                        const SizedBox(width: 6),
                        _chip('Homme', 'homme', _filterCategory, () => setState(() => _filterCategory = 'homme')),
                        const SizedBox(width: 6),
                        _chip('Femme', 'femme', _filterCategory, () => setState(() => _filterCategory = 'femme')),
                        const SizedBox(width: 6),
                        _chip('Enfant', 'enfant', _filterCategory, () => setState(() => _filterCategory = 'enfant')),
                        const SizedBox(width: 6),
                        _chip('En stock', 'healthy', _filterStockStatus, () => setState(() => _filterStockStatus = 'healthy')),
                        const SizedBox(width: 6),
                        _chip('Faible', 'low', _filterStockStatus, () => setState(() => _filterStockStatus = 'low')),
                        const SizedBox(width: 6),
                        _chip('Rupture', 'empty', _filterStockStatus, () => setState(() => _filterStockStatus = 'empty')),
                        const SizedBox(width: 6),
                        _chip('Actifs', 'active', _filterArchiveStatus, () => setState(() => _filterArchiveStatus = _filterArchiveStatus == 'active' ? null : 'active')),
                        const SizedBox(width: 6),
                        _chip('Archivés', 'archived', _filterArchiveStatus, () => setState(() => _filterArchiveStatus = _filterArchiveStatus == 'archived' ? null : 'archived')),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                // Product list
                Expanded(
                  child: _filtered.isEmpty
                      ? Center(child: Text(S.t('prod_no_results')))
                      : RefreshIndicator(
                          onRefresh: _fetch,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) {
                              final p = _filtered[i];
                              final variants = (p['product_variants'] as List?) ?? [];
                              final totalStock = variants.fold<int>(0, (s, v) {
                                if (v['is_active'] != true) return s;
                                return s + ((v['inventory'] as List?)?.fold<int>(0, (a, iv) => a + ((iv['quantity'] as int?) ?? 0)) ?? 0);
                              });
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ExpansionTile(
                                  leading: Stack(
                                    children: [
                                      Container(
                                        width: 48, height: 48,
                                        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                                        child: p['image_url'] != null
                                            ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(p['image_url'], fit: BoxFit.cover))
                                            : const Icon(Icons.image, color: Colors.grey),
                                      ),
                                      if (p['is_active'] == false)
                                        Positioned(
                                          top: 0, right: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                                            child: const Icon(Icons.archive, size: 12, color: Colors.white),
                                          ),
                                        ),
                                    ],
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(child: Text(p['name'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: p['is_active'] == false ? Colors.grey : null))),
                                      _catBadge(p['category']),
                                    ],
                                  ),
                                  trailing: AppSession.isOwner
                                      ? PopupMenuButton<String>(
                                          onSelected: (v) {
                                            if (v == 'edit') {
                                              _showEditProductDialog(context, p);
                                            } else if (v == 'archive') {
                                              _toggleProductActive(context, p);
                                            }
                                          },
                                          itemBuilder: (_) => [
                                            const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit, size: 18), title: Text('Modifier'))),
                                            PopupMenuItem(value: 'archive', child: ListTile(
                                              leading: Icon(Icons.archive, size: 18, color: Colors.orange),
                                              title: Text((p['is_active'] ?? true) ? 'Archiver' : 'Réactiver'),
                                            )),
                                          ],
                                        )
                                      : null,
                                  subtitle: Row(
                                    children: [
                                      if (p['is_active'] == false)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          margin: const EdgeInsets.only(right: 4),
                                          decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(4)),
                                          child: Text('Archivé', style: TextStyle(fontSize: 9, color: Colors.orange[800])),
                                        ),
                                      Text('${variants.length} var.', style: const TextStyle(fontSize: 12)),
                                      const SizedBox(width: 8),
                                      _stockBadge(totalStock),
                                    ],
                                  ),
                                  children: variants.where((v) => v['is_active'] == true).map<Widget>((v) {
                                    final inv = (v['inventory'] as List?) ?? [];
                                    final qty = inv.fold<int>(0, (s, i) => s + ((i['quantity'] as int?) ?? 0));
                                    return ListTile(
                                      dense: true,
                                      title: Text('${v['size']} - ${v['color']}', style: const TextStyle(fontSize: 13)),
                                      subtitle: Text('${S.t('prod_sell_price')}: ${v['sell_price']} ${S.t('misc_currency')}', style: const TextStyle(fontSize: 11)),
                                      trailing: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: qty < 3 ? Colors.red[50] : Colors.green[50],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text('$qty', style: TextStyle(fontWeight: FontWeight.bold, color: qty < 3 ? Colors.red : Colors.green[800])),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _chip(String label, String? value, String? current, VoidCallback onTap) {
    final selected = current == value;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: selected,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _catBadge(String? cat) {
    final colors = {'homme': Colors.blue, 'femme': Colors.pink, 'enfant': Colors.orange};
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: (colors[cat] ?? Colors.grey).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(cat ?? '', style: TextStyle(fontSize: 10, color: colors[cat] ?? Colors.grey, fontWeight: FontWeight.bold)),
    );
  }

  Widget _stockBadge(int qty) {
    final color = qty <= 0 ? Colors.red : qty < 5 ? Colors.orange : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text('$qty', style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }
}
