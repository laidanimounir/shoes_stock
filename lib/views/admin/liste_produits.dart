import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:isar/isar.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_strings.dart';
import '../../core/app_session.dart';
import '../../local_db/isar_service.dart';
import '../../local_db/collections/product_local.dart';
import '../../local_db/collections/product_variant_local.dart';
import '../../local_db/collections/supplier_local.dart';
import '../../local_db/collections/inventory_local.dart';
import '../../local_db/collections/store_local.dart';

const Color kPrimaryColor = Color(0xFF1B4F72);
const Color kAccentGreen = Color(0xFF2ECC71);
const Color kWarningOrange = Color(0xFFE67E22);
const Color kDangerRed = Color(0xFFE74C3C);
const Color kNegativeRed = Color(0xFF7B0000);
const Color kBackgroundColor = Color(0xFFF5F7FA);
const double kBorderRadius = 12.0;

enum StockStatus { healthy, low, empty, negative }

const Map<String, Map<String, dynamic>> kCategoryConfig = {
  'homme': {'icon': '👨', 'label': 'Homme', 'color': Color(0xFF1B4F72)},
  'femme': {'icon': '👩', 'label': 'Femme', 'color': Color(0xFFE91E8C)},
  'enfant': {'icon': '👶', 'label': 'Enfant', 'color': Color(0xFFE67E22)},
};

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

  String? _filterCategory;
  String? _filterStockStatus;
  String? _filterSupplier;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);

    if (AppSession.isOfflineMode) {
      final isar = await IsarService.getInstance();
      
      final localProducts = await isar.productLocals
          .filter()
          .isActiveEqualTo(true)
          .findAll();
          
      final localSuppliers = await isar.supplierLocals.where().findAll();
      final supplierMap = {for (var s in localSuppliers) s.supabaseId: s};
      
      final localVariants = await isar.productVariantLocals
          .filter()
          .isActiveEqualTo(true)
          .findAll();
          
      final localInventory = await isar.inventoryLocals.where().findAll();
      final localStores = await isar.storeLocals.where().findAll();
      final storeMap = {for (var st in localStores) st.supabaseId: st};

      final results = localProducts.map((p) {
        final supplier = supplierMap[p.supplierId];
        final variants = localVariants
            .where((v) => v.productId == p.supabaseId)
            .map((v) {
              final invs = localInventory
                  .where((inv) => inv.variantId == v.supabaseId)
                  .map((inv) {
                    final store = storeMap[inv.storeId];
                    return {
                      'quantity': inv.quantity,
                      'store_id': inv.storeId,
                      'stores': store != null ? {'name': store.name} : null,
                    };
                  }).toList();

              return {
                'id': v.supabaseId,
                'size': v.size,
                'color': v.color,
                'barcode': v.barcode,
                'sell_price': v.sellPrice,
                'buy_price': v.buyPrice,
                'is_active': v.isActive,
                'inventory': invs,
              };
            }).toList();

        return {
          'id': p.supabaseId,
          'name': p.name,
          'description': p.description,
          'image_url': p.imageUrl,
          'category': p.category,
          'created_at': p.createdAt?.toIso8601String(),
          'suppliers': supplier != null ? {'company_name': supplier.companyName} : null,
          'product_variants': variants,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _products = results;
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final res = await Supabase.instance.client
          .from('products')
          .select('''
            id, name, description, image_url, created_at, category,
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
    return _products.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final supplier = (p['suppliers']?['company_name'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      final searchMatch = q.isEmpty || name.contains(q) || supplier.contains(q);

      final categoryMatch = _filterCategory == null || p['category'] == _filterCategory;

      final allVariants = p['product_variants'] as List<dynamic>? ?? [];
      final active = allVariants.where((v) => v['is_active'] == true).toList();
      final stock = _getTotalStock(active);
      final status = _getStockStatus(stock);
      final stockMatch = _filterStockStatus == null || status.name == _filterStockStatus;

      final supplierMatch = _filterSupplier == null ||
        (p['suppliers']?['company_name']) == _filterSupplier;

      return searchMatch && categoryMatch && stockMatch && supplierMatch;
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

  StockStatus _getStockStatus(int stock) {
    if (stock < 0) return StockStatus.negative;
    if (stock == 0) return StockStatus.empty;
    if (stock <= 5) return StockStatus.low;
    return StockStatus.healthy;
  }

  Color _getStockColor(StockStatus status) {
    switch (status) {
      case StockStatus.healthy: return kAccentGreen;
      case StockStatus.low: return kWarningOrange;
      case StockStatus.empty: return kDangerRed;
      case StockStatus.negative: return kNegativeRed;
    }
  }

  String _getStockLabel(StockStatus status, int stock) {
    switch (status) {
      case StockStatus.healthy: return 'Stock: $stock';
      case StockStatus.low: return 'Stock faible: $stock';
      case StockStatus.empty: return 'Rupture';
      case StockStatus.negative: return 'Stock: $stock';
    }
  }

  int get _negativeCount => _products.where((p) {
    final allVariants = p['product_variants'] as List<dynamic>? ?? [];
    final active = allVariants.where((v) => v['is_active'] == true).toList();
    return _getTotalStock(active) < 0;
  }).length;

  List<String> get _uniqueSuppliers => _products
    .map((p) => (p['suppliers']?['company_name'] ?? '') as String)
    .where((s) => s.isNotEmpty)
    .toSet()
    .toList()..sort();

  int get _activeFilterCount => [
    if (_filterCategory != null) 1,
    if (_filterStockStatus != null) 1,
    if (_filterSupplier != null) 1,
    if (_searchQuery.isNotEmpty) 1,
  ].length;

  void _resetFilters() {
    setState(() {
      _filterCategory = null;
      _filterStockStatus = null;
      _filterSupplier = null;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  Widget _buildCategoryBadge(String? category) {
    if (category == null) return const SizedBox.shrink();
    final config = kCategoryConfig[category];
    if (config == null) return const SizedBox.shrink();
    final color = config['color'] as Color;
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${config['icon']} ${config['label']}',
        style: GoogleFonts.raleway(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  void _showEditVariantDialog(Map<String, dynamic> variant) {
    final buyPriceCtrl = TextEditingController(text: variant['buy_price']?.toString() ?? '0');
    final sellPriceCtrl = TextEditingController(text: variant['sell_price']?.toString() ?? '0');
    final barcodeCtrl = TextEditingController(text: variant['barcode'] ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${S.t('prod_edit_variant')}${variant['size']} - ${variant['color']}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: barcodeCtrl,
                decoration: InputDecoration(labelText: S.t('prod_barcode'), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.qr_code)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: buyPriceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: S.t('prod_buy_price'), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.arrow_downward, color: Colors.orange)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: sellPriceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: S.t('prod_sell_price'), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.arrow_upward, color: Colors.green)),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(S.t('prod_price_note'), style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
              )
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.t('action_cancel'))),
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
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.t('prod_variant_updated')), backgroundColor: Colors.green));
              } on PostgrestException catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.code == '42501' ? S.t('msg_access_denied') : '${S.t('msg_error')}: ${e.message}'), backgroundColor: Colors.red));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${S.t('msg_error')}: $e'), backgroundColor: Colors.red));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            child: Text(S.t('action_save'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  
  Future<void> _archiveVariant(String variantId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.t('prod_archive_variant_title')),
        content: Text(S.t('prod_archive_variant_msg')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.t('action_cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text(S.t('action_archive'), style: const TextStyle(color: Colors.white)),
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
        title: Text(S.t('prod_archive_title')),
        content: Text(S.t('prod_archive_msg')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.t('action_cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(S.t('prod_archive_btn'), style: const TextStyle(color: Colors.white)),
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
    final bool hasActiveFilters = _activeFilterCount > 0;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text(S.t('prod_catalog_title'),
          style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        elevation: 1,
        actions: [
          if (hasActiveFilters)
            TextButton(
              onPressed: _resetFilters,
              child: const Text('Réinitialiser', style: TextStyle(color: Colors.white70, fontSize: 13)),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: S.t('action_refresh'),
            onPressed: _fetchProducts,
          ),
        ],
      ),
      floatingActionButton: AppSession.isOwner
          ? FloatingActionButton.extended(
              onPressed: widget.onAddProduct,
              backgroundColor: kAccentGreen,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(S.t('prod_add_btn'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar
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
                            decoration: InputDecoration(
                              hintText: S.t('prod_search_hint'),
                              prefixIcon: const Icon(Icons.search),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            onChanged: (val) => setState(() => _searchQuery = val),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (hasActiveFilters)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: kWarningOrange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kWarningOrange.withOpacity(0.3)),
                          ),
                          child: Text('$_activeFilterCount filtre(s)',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kWarningOrange),
                          ),
                        ),
                      const SizedBox(width: 12),
                      _buildMiniStat(S.t('prod_active_count'), '${_filteredProducts.length}', Icons.category, Colors.blue),
                    ],
                  ),
                ),

                // Negative stock banner
                if (_negativeCount > 0)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kNegativeRed.withOpacity(0.1),
                      border: Border.all(color: kNegativeRed),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: kNegativeRed),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$_negativeCount produit(s) avec stock négatif détecté — vérification requise',
                            style: GoogleFonts.raleway(
                              color: kNegativeRed,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Filter chips
                if (_products.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip('Tous', null, _filterCategory,
                                onSelected: () => setState(() => _filterCategory = null)),
                              const SizedBox(width: 8),
                              ...['homme', 'femme', 'enfant'].map((c) {
                                final cfg = kCategoryConfig[c]!;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: _buildFilterChip(
                                    '${cfg['icon']} ${cfg['label']}',
                                    c, _filterCategory,
                                    onSelected: () => setState(() => _filterCategory = c),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Stock status chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip('Tous stocks', null, _filterStockStatus,
                                onSelected: () => setState(() => _filterStockStatus = null)),
                              const SizedBox(width: 8),
                              _buildFilterChip('Disponible', 'healthy', _filterStockStatus,
                                icon: Icons.check_circle, chipColor: kAccentGreen,
                                onSelected: () => setState(() => _filterStockStatus = 'healthy')),
                              const SizedBox(width: 8),
                              _buildFilterChip('Faible', 'low', _filterStockStatus,
                                icon: Icons.warning_amber_rounded, chipColor: kWarningOrange,
                                onSelected: () => setState(() => _filterStockStatus = 'low')),
                              const SizedBox(width: 8),
                              _buildFilterChip('Rupture', 'empty', _filterStockStatus,
                                icon: Icons.remove_circle, chipColor: kDangerRed,
                                onSelected: () => setState(() => _filterStockStatus = 'empty')),
                              const SizedBox(width: 8),
                              _buildFilterChip('Négatif', 'negative', _filterStockStatus,
                                icon: Icons.error, chipColor: kNegativeRed,
                                onSelected: () => setState(() => _filterStockStatus = 'negative')),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Supplier chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip('Tous fournisseurs', null, _filterSupplier,
                                onSelected: () => setState(() => _filterSupplier = null)),
                              const SizedBox(width: 8),
                              ..._uniqueSuppliers.map((s) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _buildFilterChip(s, s, _filterSupplier,
                                  onSelected: () => setState(() => _filterSupplier = s)),
                              )),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_filteredProducts.length} produit(s) trouvé(s)',
                          style: GoogleFonts.raleway(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),

                // Product list
                Expanded(
                  child: _filteredProducts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                hasActiveFilters ? Icons.filter_alt_off : Icons.inventory_2_outlined,
                                size: 80,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                hasActiveFilters
                                  ? 'Aucun produit ne correspond aux filtres sélectionnés'
                                  : S.t('prod_no_results'),
                                style: GoogleFonts.raleway(fontSize: 18, color: Colors.grey[500]),
                              ),
                              if (hasActiveFilters) ...[
                                const SizedBox(height: 16),
                                OutlinedButton(
                                  onPressed: _resetFilters,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: kPrimaryColor,
                                    side: BorderSide(color: kPrimaryColor.withOpacity(0.3)),
                                  ),
                                  child: const Text('Réinitialiser les filtres'),
                                ),
                              ],
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

                            final supplierName = product['suppliers']?['company_name'] ?? S.t('prod_no_supplier');
                            final totalStock = _getTotalStock(activeVariants);
                            final stockStatus = _getStockStatus(totalStock);
                            final imageUrl = product['image_url'];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: totalStock < 0
                                ? BoxDecoration(
                                    border: const Border(left: BorderSide(color: kNegativeRed, width: 4)),
                                    color: kNegativeRed.withOpacity(0.03),
                                    borderRadius: BorderRadius.circular(kBorderRadius + 2),
                                  )
                                : null,
                              child: Card(
                                margin: EdgeInsets.zero,
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kBorderRadius)),
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
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          product['name'] ?? 'Inconnu',
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 17),
                                        ),
                                      ),
                                      _buildCategoryBadge(product['category']),
                                    ],
                                  ),
                                  subtitle: Row(
                                    children: [
                                      Icon(Icons.local_shipping, size: 14, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Flexible(child: Text(supplierName, overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: Colors.grey[600], fontSize: 12))),
                                      const SizedBox(width: 12),
                                      Icon(Icons.style, size: 14, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text('${activeVariants.length} var.',
                                        style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                      const SizedBox(width: 12),
                                      _buildStockBadge(stockStatus, totalStock),
                                    ],
                                  ),
                                  children: [
                                    if (activeVariants.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text(S.t('prod_no_active_variants'), style: const TextStyle(color: Colors.grey)),
                                      )
                                    else
                                      Container(
                                        color: Colors.grey[50],
                                        child: Column(
                                          children: [

                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                              decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.05)),
                                              child: Row(
                                                children: [
                                                  Expanded(flex: 2, child: Text(S.t('prod_details'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                                  Expanded(flex: 2, child: Text(S.t('label_barcode'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                                  Expanded(flex: 3, child: Text(S.t('prod_buy_sell_margin'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                                  Expanded(flex: 1, child: Text(S.t('label_stock'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue))),
                                                  SizedBox(width: 80, child: Text(S.t('label_actions'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
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
                                              final varStatus = _getStockStatus(variantStock);

                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                                                decoration: BoxDecoration(
                                                  border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                                                  color: variantStock < 0 ? kNegativeRed.withOpacity(0.03) : null,
                                                ),
                                                child: Row(
                                                  children: [
                                                    Expanded(flex: 2, child: Text('${v['size']} - ${v['color']}',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: variantStock < 0 ? kNegativeRed : null,
                                                      ),
                                                    )),
                                                    Expanded(flex: 2, child: Text(v['barcode'] ?? '-',
                                                      style: const TextStyle(fontSize: 12, color: Colors.grey))),
                                                    Expanded(
                                                      flex: 3,
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        if (AppSession.isOwner) ...[
                                                          Text('${S.t('prod_buy_short')}$buyPrice ${S.t('misc_currency')}',
                                                            style: const TextStyle(fontSize: 12, color: Colors.orange)),
                                                          Text('${S.t('prod_sell_short')}$sellPrice ${S.t('misc_currency')}',
                                                            style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                                                          Text('${S.t('prod_margin_short')}$margin ${S.t('misc_currency')}',
                                                            style: const TextStyle(fontSize: 11, color: Colors.teal)),
                                                        ] else
                                                          Text('${S.t('prod_sell_short')}$sellPrice ${S.t('misc_currency')}',
                                                            style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                                                      ],
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 1,
                                                      child: Tooltip(
                                                        message: storeInfo.isEmpty ? S.t('prod_out_of_stock') : storeInfo,
                                                        child: _buildStockBadge(varStatus, variantStock, compact: true),
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      width: 80,
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.end,
                                                        children: [
                                                          if (AppSession.isOwner) ...[
                                                            IconButton(
                                                              icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                                                              tooltip: S.t('prod_edit_price_code'),
                                                              onPressed: () => _showEditVariantDialog(v),
                                                            ),
                                                            IconButton(
                                                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                                              tooltip: S.t('prod_archive_variant'),
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

                                    if (AppSession.isOwner)
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Align(
                                          alignment: AlignmentDirectional.centerEnd,
                                          child: TextButton.icon(
                                            onPressed: () => _archiveProduct(product['id']),
                                            icon: const Icon(Icons.archive, color: Colors.red, size: 18),
                                            label: Text(S.t('prod_archive_btn'), style: const TextStyle(color: Colors.red)),
                                          ),
                                        ),
                                      )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterChip(String label, String? value, String? currentValue, {
    VoidCallback? onSelected,
    IconData? icon,
    Color chipColor = kPrimaryColor,
  }) {
    final selected = currentValue == value;
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? chipColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? chipColor : chipColor.withOpacity(0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: selected ? Colors.white : chipColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.raleway(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : chipColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockBadge(StockStatus status, int stock, {bool compact = false}) {
    final color = _getStockColor(status);
    IconData icon;
    switch (status) {
      case StockStatus.healthy: icon = Icons.check_circle; break;
      case StockStatus.low: icon = Icons.warning_amber_rounded; break;
      case StockStatus.empty: icon = Icons.remove_circle; break;
      case StockStatus.negative: icon = Icons.error; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 14, color: color),
          const SizedBox(width: 4),
          Text(
            compact ? '$stock' : _getStockLabel(status, stock),
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.bold,
              color: color,
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