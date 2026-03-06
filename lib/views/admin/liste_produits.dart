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
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('products')
          .select('''
            id, name, description, image_url, created_at,
            suppliers(company_name),
            product_variants(id, size, color, barcode, sell_price, buy_price,
              inventory(quantity, store_id, stores(name))
            )
          ''')
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

  int _getTotalStock(dynamic product) {
    int total = 0;
    final variants = product['product_variants'] as List<dynamic>? ?? [];
    for (var v in variants) {
      final inv = v['inventory'] as List<dynamic>? ?? [];
      for (var i in inv) {
        total += (i['quantity'] as int?) ?? 0;
      }
    }
    return total;
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
        icon: const Icon(Icons.add),
        label: const Text('Ajouter un Produit', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search + Stats Bar
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
                      _buildMiniStat('Produits', '${_products.length}', Icons.category, Colors.blue),
                      const SizedBox(width: 12),
                      _buildMiniStat(
                        'Variantes',
                        '${_products.fold<int>(0, (sum, p) => sum + ((p['product_variants'] as List?)?.length ?? 0))}',
                        Icons.style,
                        Colors.orange,
                      ),
                    ],
                  ),
                ),

                // Products List
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
                            final variants = product['product_variants'] as List<dynamic>? ?? [];
                            final supplierName = product['suppliers']?['company_name'] ?? 'Sans fournisseur';
                            final totalStock = _getTotalStock(product);
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
                                    Text('${variants.length} variantes', style: TextStyle(color: Colors.grey[600])),
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
                                  if (variants.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Text('Aucune variante', style: TextStyle(color: Colors.grey)),
                                    )
                                  else
                                    Container(
                                      color: Colors.grey[50],
                                      child: Column(
                                        children: [
                                          // Table Header
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: Colors.teal[50],
                                            ),
                                            child: const Row(
                                              children: [
                                                Expanded(flex: 2, child: Text('Pointure', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                                Expanded(flex: 2, child: Text('Couleur', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                                Expanded(flex: 2, child: Text('Code-barres', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                                Expanded(flex: 2, child: Text('Prix Achat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange))),
                                                Expanded(flex: 2, child: Text('Prix Vente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green))),
                                                Expanded(flex: 2, child: Text('Stock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue))),
                                              ],
                                            ),
                                          ),
                                          // Table Rows
                                          ...variants.map((v) {
                                            final invList = v['inventory'] as List<dynamic>? ?? [];
                                            int variantStock = 0;
                                            String storeInfo = '';
                                            for (var inv in invList) {
                                              final qty = (inv['quantity'] as int?) ?? 0;
                                              variantStock += qty;
                                              final storeName = inv['stores']?['name'] ?? '?';
                                              if (storeInfo.isNotEmpty) storeInfo += ', ';
                                              storeInfo += '$storeName: $qty';
                                            }

                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                              decoration: BoxDecoration(
                                                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(flex: 2, child: Text(v['size'] ?? '-', style: const TextStyle(fontSize: 14))),
                                                  Expanded(flex: 2, child: Text(v['color'] ?? '-', style: const TextStyle(fontSize: 14))),
                                                  Expanded(flex: 2, child: Text(v['barcode'] ?? '-', style: const TextStyle(fontSize: 13, color: Colors.grey))),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      '${(v['buy_price'] ?? 0.0).toStringAsFixed(2)} €',
                                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orange),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      '${(v['sell_price'] ?? 0.0).toStringAsFixed(2)} €',
                                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Tooltip(
                                                      message: storeInfo.isEmpty ? 'Pas en stock' : storeInfo,
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: variantStock > 0
                                                              ? (variantStock < 3 ? Colors.orange[50] : Colors.green[50])
                                                              : Colors.red[50],
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: Text(
                                                          '$variantStock',
                                                          textAlign: TextAlign.center,
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            color: variantStock > 0
                                                                ? (variantStock < 3 ? Colors.orange : Colors.green[800])
                                                                : Colors.red,
                                                          ),
                                                        ),
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
        color: color.withValues(alpha: 0.1),
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
