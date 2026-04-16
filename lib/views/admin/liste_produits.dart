import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ListeProduitsScreen extends StatefulWidget {
  final VoidCallback? onAddProduct;

  const ListeProduitsScreen({super.key, this.onAddProduct});

  @override
  State<ListeProduitsScreen> createState() => _ListeProduitsScreenState();
}

class _ListeProduitsScreenState extends State<ListeProduitsScreen> {
  List<dynamic> _products = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();
  String? _userRole;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initRoleAndFetch();
  }

  Future<void> _initRoleAndFetch() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final profile = await Supabase.instance.client
            .from('user_profiles')
            .select('role')
            .eq('id', user.id)
            .single();
        _userRole = profile['role'];
      }
    } catch (e) {
      debugPrint("Error fetching role: $e");
    }
    if (mounted) {
      setState(() {});
    }
    await _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('products')
          .select('''
            id, name, description, image_url, created_at,
            suppliers(company_name),
            product_variants(id, size, color, barcode, sell_price, buy_price, is_active,
              inventory(quantity, store_id, stores(name))
            )
          ''')
          .eq('is_active', true) 
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _products = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching products: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredProducts {
    if (_searchQuery.isEmpty) return _products;
    return _products.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final supplier = (p['suppliers']?['company_name'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return name.contains(q) || supplier.contains(q);
    }).toList();
  }

  int _getTotalStock(List<dynamic> variants) {
    int total = 0;
    for (var v in variants) {
      if (v['is_active'] == true) {
        final inv = v['inventory'] as List<dynamic>? ?? [];
        for (var i in inv) {
          total += (i['quantity'] as int?) ?? 0;
        }
      }
    }
    return total;
  }

  


  void _showEditVariantDialog(Map<String, dynamic> variant) {
    final buyPriceCtrl = TextEditingController(text: variant['buy_price']?.toString() ?? '0');
    final sellPriceCtrl = TextEditingController(text: variant['sell_price']?.toString() ?? '0');
    final barcodeCtrl = TextEditingController(text: variant['barcode'] ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Modifier: ${variant['size']} - ${variant['color']}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: barcodeCtrl,
                decoration: const InputDecoration(labelText: 'Code-barres', border: OutlineInputBorder(), prefixIcon: Icon(Icons.qr_code)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: buyPriceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Prix Achat (DA)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.arrow_downward, color: Colors.orange)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: sellPriceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Prix Vente (DA)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.arrow_upward, color: Colors.green)),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('Note: Les anciennes factures garderont l\'ancien prix.', style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
              )
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await Supabase.instance.client.from('product_variants').update({
                  'buy_price': double.tryParse(buyPriceCtrl.text) ?? 0,
                  'sell_price': double.tryParse(sellPriceCtrl.text) ?? 0,
                  'barcode': barcodeCtrl.text.trim(),
                }).eq('id', variant['id']);
                
                _fetchProducts();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Variante mise à jour avec succès.'), backgroundColor: Colors.green));
              } on PostgrestException catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.code == '42501' ? 'Accès refusé : Autorisations insuffisantes' : 'Erreur: ${e.message}'), backgroundColor: Colors.red));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            child: const Text('Enregistrer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  
  Future<void> _archiveVariant(String variantId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archiver cette variante ?'),
        content: const Text('Elle ne sera plus disponible pour la vente, mais restera dans les anciennes factures.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Archiver', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.from('product_variants').update({'is_active': false}).eq('id', variantId);
        _fetchProducts();
      } on PostgrestException catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.code == '42501' ? 'Accès refusé : Autorisations insuffisantes' : 'Erreur: ${e.message}'), backgroundColor: Colors.red));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    }
  }

  
  Future<void> _archiveProduct(String productId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archiver TOUT le produit ?'),
        content: const Text('Le produit et toutes ses variantes seront masqués du catalogue.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Archiver le produit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.from('products').update({'is_active': false}).eq('id', productId);
        _fetchProducts();
      } on PostgrestException catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.code == '42501' ? 'Accès refusé : Autorisations insuffisantes' : 'Erreur: ${e.message}'), backgroundColor: Colors.red));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Catalogue des Produits'),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: _fetchProducts,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.onAddProduct,
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Ajouter un Produit', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Rechercher un produit ou fournisseur...',
                              prefixIcon: Icon(Icons.search),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(16),
                            ),
                            onChanged: (val) => setState(() => _searchQuery = val),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      _buildMiniStat('Produits Actifs', '${_filteredProducts.length}', Icons.category, Colors.blue),
                    ],
                  ),
                ),

              
                Expanded(
                  child: _filteredProducts.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('Aucun produit trouvé', style: TextStyle(fontSize: 20, color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = _filteredProducts[index];
                           
                            final allVariants = product['product_variants'] as List<dynamic>? ?? [];
                            final activeVariants = allVariants.where((v) => v['is_active'] == true).toList();
                            
                            final supplierName = product['suppliers']?['company_name'] ?? 'Sans fournisseur';
                            final totalStock = _getTotalStock(activeVariants);
                            final imageUrl = product['image_url'];

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ExpansionTile(
                                leading: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: imageUrl != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(imageUrl, fit: BoxFit.cover),
                                        )
                                      : const Icon(Icons.image_not_supported, color: Colors.grey),
                                ),
                                title: Text(
                                  product['name'] ?? 'Inconnu',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                                subtitle: Row(
                                  children: [
                                    Icon(Icons.local_shipping, size: 14, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text(supplierName, style: TextStyle(color: Colors.grey[600])),
                                    const SizedBox(width: 16),
                                    Icon(Icons.style, size: 14, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text('${activeVariants.length} variantes', style: TextStyle(color: Colors.grey[600])),
                                    const SizedBox(width: 16),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: totalStock > 0 ? Colors.green[50] : Colors.red[50],
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: totalStock > 0 ? Colors.green : Colors.red),
                                      ),
                                      child: Text(
                                        'Stock: $totalStock',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: totalStock > 0 ? Colors.green[800] : Colors.red,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                children: [
                                  if (activeVariants.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Text('Aucune variante active.', style: TextStyle(color: Colors.grey)),
                                    )
                                  else
                                    Container(
                                      color: Colors.grey[50],
                                      child: Column(
                                        children: [
                                         
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                            decoration: BoxDecoration(color: Colors.teal[50]),
                                            child: const Row(
                                              children: [
                                                Expanded(flex: 2, child: Text('Détails', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                                Expanded(flex: 2, child: Text('Code-barres', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                                Expanded(flex: 3, child: Text('Achat / Vente (Marge)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                                Expanded(flex: 1, child: Text('Stock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue))),
                                                SizedBox(width: 80, child: Text('Actions', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                              ],
                                            ),
                                          ),
                                       
                                          ...activeVariants.map((v) {
                                            final invList = v['inventory'] as List<dynamic>? ?? [];
                                            int variantStock = 0;
                                            String storeInfo = '';
                                            for (var inv in invList) {
                                              final qty = (inv['quantity'] as int?) ?? 0;
                                              variantStock += qty;
                                              final storeName = inv['stores']?['name'] ?? '?';
                                              if (storeInfo.isNotEmpty) storeInfo += '\n';
                                              storeInfo += '$storeName: $qty';
                                            }

                                            final buyPrice = (v['buy_price'] as num?)?.toDouble() ?? 0.0;
                                            final sellPrice = (v['sell_price'] as num?)?.toDouble() ?? 0.0;
                                            final margin = sellPrice - buyPrice;

                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                                              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[200]!))),
                                              child: Row(
                                                children: [
                                                  Expanded(flex: 2, child: Text('${v['size']} - ${v['color']}', style: const TextStyle(fontWeight: FontWeight.bold))),
                                                  Expanded(flex: 2, child: Text(v['barcode'] ?? '-', style: const TextStyle(fontSize: 12, color: Colors.grey))),
                                                  Expanded(
                                                    flex: 3,
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Text('A: $buyPrice DA', style: const TextStyle(fontSize: 12, color: Colors.orange)),
                                                        Text('V: $sellPrice DA', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                                                        Text('Marge: +$margin DA', style: const TextStyle(fontSize: 11, color: Colors.teal)),
                                                      ],
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 1,
                                                    child: Tooltip(
                                                      message: storeInfo.isEmpty ? 'Pas en stock' : storeInfo,
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: variantStock > 0 ? Colors.green[50] : Colors.red[50],
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: Text(
                                                          '$variantStock',
                                                          textAlign: TextAlign.center,
                                                          style: TextStyle(fontWeight: FontWeight.bold, color: variantStock > 0 ? Colors.green[800] : Colors.red),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 80,
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.end,
                                                      children: [
                                                        if (_userRole == 'owner') ...[
                                                          IconButton(
                                                            icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                                                            tooltip: 'Modifier Prix/Code',
                                                            onPressed: () => _showEditVariantDialog(v),
                                                          ),
                                                          IconButton(
                                                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                                            tooltip: 'Archiver cette variante',
                                                            onPressed: () => _archiveVariant(v['id']),
                                                          ),
                                                        ]
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                  
                                  if (_userRole == 'owner')
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton.icon(
                                          onPressed: () => _archiveProduct(product['id']),
                                          icon: const Icon(Icons.archive, color: Colors.red, size: 18),
                                          label: const Text('Archiver TOUT le produit', style: TextStyle(color: Colors.red)),
                                        ),
                                      ),
                                    )
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: color)),
              Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
            ],
          ),
        ],
      ),
    );
  }
}