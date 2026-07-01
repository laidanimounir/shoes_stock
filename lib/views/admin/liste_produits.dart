import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:isar/isar.dart';
import 'package:barcode/barcode.dart' as bc;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/app_strings.dart';
import '../../core/app_session.dart';
import '../../core/app_constants.dart';
import '../../theme/app_text_styles.dart';
import '../../services/report_service.dart';
import '../../local_db/isar_service.dart';
import '../../local_db/collections/product_local.dart';
import '../../local_db/collections/product_variant_local.dart';
import '../../local_db/collections/supplier_local.dart';
import '../../local_db/collections/inventory_local.dart';
import '../../local_db/collections/store_local.dart';
import '../../shared/constants/shoe_constants.dart';

class _T {
  _T._();
  static const bgPage = Color(0xFF0A0A14);
  static const bgAppBar = Color(0xFF0F0F1C);
  static const bgCard = Color(0xFF13131F);
  static const bgTable = Color(0xFF0D0D1A);
  static const bgTableHeader = Color(0xFF1A1400);
  static const bgTableRowAlt = Color(0xFF111120);
  static const bgTableHover = Color(0xFF1E1E35);
  static const accentGold = Color(0xFFFFC107);
  static const accentBlue = Color(0xFF58A6FF);
  static const textPrimary = Color(0xFFEEEEFF);
  static const textSecondary = Color(0xFF8888AA);
  static const textMuted = Color(0xFF555570);
  static const borderColor = Color(0xFF1E1E35);
  static const statusPaidBg = Color(0xFF0D2B1A);
  static const statusPaidText = Color(0xFF4ADE80);
  static const statusRefundedBg = Color(0xFF2B1A0D);
  static const statusRefundedText = Color(0xFFFBBF24);
  static const statusUnpaidBg = Color(0xFF2B0D0D);
  static const statusUnpaidText = Color(0xFFF87171);
  static const statusPartialBg = Color(0xFF1A1A0D);
  static const statusPartialText = Color(0xFFFDE68A);
  static const shimmerColor = Color(0xFF252538);
}

const Color kPrimaryColor = _T.accentGold;
const Color kAccentGreen = _T.statusPaidText;
const Color kWarningOrange = _T.accentGold;
const Color kDangerRed = _T.statusUnpaidText;
const Color kNegativeRed = _T.statusUnpaidText;
const Color kBackgroundColor = _T.bgPage;
const double kBorderRadius = 12.0;

enum StockStatus { healthy, low, empty, negative }

const Map<String, Map<String, dynamic>> kCategoryConfig = {
  'homme': {'icon': '👨', 'label': 'Homme', 'color': _T.accentGold},
  'femme': {'icon': '👩', 'label': 'Femme', 'color': _T.statusUnpaidText},
  'enfant': {'icon': '👶', 'label': 'Enfant', 'color': _T.accentGold},
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

  bool _selectionMode = false;
  final Set<String> _selectedVariantIds = {};
  int _offset = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts({bool reset = true}) async {
    if (reset) {
      _offset = 0;
      _hasMore = true;
      setState(() => _isLoading = true);
    } else {
      setState(() => _isLoadingMore = true);
    }

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
      var query = Supabase.instance.client
          .from('products')
          .select('''
            id, name, description, image_url, created_at, category,
            suppliers(company_name),
            product_variants(id, size, color, barcode, sell_price, buy_price, is_active,
              inventory(quantity, store_id, stores(name))
            )
          ''')
          .eq('is_active', true);

      if (_searchQuery.isNotEmpty) {
        query = query.ilike('name', '%$_searchQuery%');
      }
      if (_filterCategory != null) {
        query = query.eq('category', _filterCategory!);
      }
      if (_filterSupplier != null) {
        query = query.eq('supplier_id', _filterSupplier!);
      }

      final res = await query
          .order('created_at', ascending: false)
          .range(_offset, _offset + AppConstants.paginationPageSize - 1);

      final newItems = res as List<dynamic>;
      if (newItems.length < AppConstants.paginationPageSize) {
        _hasMore = false;
      }

      if (mounted) {
        setState(() {
          if (_offset == 0) {
            _products = newItems;
          } else {
            _products.addAll(newItems);
          }
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching products: $e");
      if (mounted) setState(() { _isLoading = false; _isLoadingMore = false; });
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoadingMore || !_hasMore) return;
    _offset += AppConstants.paginationPageSize;
    await _fetchProducts(reset: false);
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

  List<Map<String, dynamic>> get _allVisibleVariants {
    final result = <Map<String, dynamic>>[];
    for (final product in _filteredProducts) {
      final variants = (product['product_variants'] as List<dynamic>?)
          ?.where((v) => v['is_active'] == true)
          .toList() ?? [];
      for (final v in variants) {
        result.add({...v, '_productName': product['name']});
      }
    }
    return result;
  }

  void _enterSelectionMode(String variantId) {
    if (!_selectionMode) {
      setState(() {
        _selectionMode = true;
        _selectedVariantIds.add(variantId);
      });
    }
  }

  void _toggleSelectAllVariants() {
    final allIds = _allVisibleVariants.map((v) => v['id'] as String).toSet();
    if (_selectedVariantIds.length == allIds.length) {
      _selectedVariantIds.clear();
    } else {
      _selectedVariantIds.addAll(allIds);
    }
    setState(() {});
  }

  Future<void> _showBulkPrintDialog() async {
    final allVariants = _allVisibleVariants;
    final selectedVariants = allVariants
        .where((v) => _selectedVariantIds.contains(v['id']))
        .toList();
    if (selectedVariants.isEmpty) return;

    final controllers = selectedVariants
        .map((_) => TextEditingController(text: '1'))
        .toList();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _T.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Imprimer ${selectedVariants.length} étiquettes',
            style: const TextStyle(color: _T.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
        content: SizedBox(
          width: 400,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: selectedVariants.length,
            itemBuilder: (_, i) {
              final v = selectedVariants[i];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${v['_productName']} / ${v['size']} / ${v['color']}',
                        style: const TextStyle(fontSize: 13, color: _T.textPrimary),
                      ),
                    ),
                    SizedBox(
                      width: 70,
                      child: TextField(
                        controller: controllers[i],
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: _T.textPrimary, fontSize: 13),
                        cursorColor: _T.accentGold,
                        decoration: InputDecoration(
                          labelText: 'Qté',
                          labelStyle: const TextStyle(color: _T.textSecondary, fontSize: 11),
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFF1E1E2E),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: _T.borderColor),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: _T.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _T.accentGold,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Imprimer', style: TextStyle(color: _T.bgPage, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final items = <BarcodeItem>[];
    for (int i = 0; i < selectedVariants.length; i++) {
      final v = selectedVariants[i];
      final qty = int.tryParse(controllers[i].text) ?? 1;
      final barcode = (v['barcode'] as String?)?.trim();
      if (qty > 0 && barcode != null && barcode.isNotEmpty) {
        items.add(BarcodeItem(
          variantId: v['id'],
          barcode: barcode,
          productName: v['_productName'] ?? '',
          size: v['size'] ?? '',
          color: v['color'] ?? '',
          price: (v['sell_price'] as num?)?.toDouble() ?? 0,
          quantity: qty,
        ));
      }
    }

    if (items.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Aucun code-barres valide sélectionné'),
            backgroundColor: _T.statusUnpaidBg,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      return;
    }

    final pdfBytes = await ReportService.instance.generateBulkBarcodePdf(items);
    await Printing.layoutPdf(onLayout: (_) => pdfBytes);
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
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${config['icon']} ${config['label']}',
        style: AppTextStyles.bodyMedium(color: color),
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
        backgroundColor: _T.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${S.t('prod_edit_variant')}${variant['size']} - ${variant['color']}',
            style: const TextStyle(color: _T.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _themedField(
                controller: barcodeCtrl,
                label: S.t('prod_barcode'),
                icon: Icons.qr_code_rounded,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _themedField(
                      controller: buyPriceCtrl,
                      label: S.t('prod_buy_price'),
                      icon: Icons.arrow_downward_rounded,
                      iconColor: _T.accentGold,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _themedField(
                      controller: sellPriceCtrl,
                      label: S.t('prod_sell_price'),
                      icon: Icons.arrow_upward_rounded,
                      iconColor: _T.statusPaidText,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(S.t('prod_price_note'),
                    style: const TextStyle(fontSize: 12, color: _T.textMuted, fontStyle: FontStyle.italic)),
              )
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(S.t('action_cancel'), style: const TextStyle(color: _T.textSecondary))),
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
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(S.t('prod_variant_updated')),
                    backgroundColor: _T.statusPaidBg,
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ));
                }
              } on PostgrestException catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(e.code == '42501' ? S.t('msg_access_denied') : '${S.t('msg_error')}: ${e.message}'),
                    backgroundColor: _T.statusUnpaidBg,
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('${S.t('msg_error')}: $e'),
                    backgroundColor: _T.statusUnpaidBg,
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ));
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _T.accentBlue,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(S.t('action_save'), style: const TextStyle(color: _T.textPrimary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _themedField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    Color? iconColor,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: _T.textPrimary, fontSize: 14),
      cursorColor: _T.accentGold,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _T.textSecondary, fontSize: 13),
        prefixIcon: Icon(icon, color: iconColor ?? _T.textMuted, size: 18),
        filled: true,
        fillColor: const Color(0xFF1E1E2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _T.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _T.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _T.accentGold),
        ),
      ),
    );
  }

  Future<void> _archiveVariant(String variantId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _T.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(S.t('prod_archive_variant_title'), style: const TextStyle(color: _T.textPrimary, fontWeight: FontWeight.w700)),
        content: Text(S.t('prod_archive_variant_msg'), style: const TextStyle(color: _T.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.t('action_cancel'), style: const TextStyle(color: _T.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _T.accentGold, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text(S.t('action_archive'), style: const TextStyle(color: _T.bgPage, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.from('product_variants').update({'is_active': false}).eq('id', variantId);
        _fetchProducts();
      } on PostgrestException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.code == '42501' ? 'Accès refusé : Autorisations insuffisantes' : 'Erreur: ${e.message}'),
            backgroundColor: _T.statusUnpaidBg,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: _T.statusUnpaidBg,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      }
    }
  }

  Future<void> _archiveProduct(String productId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _T.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(S.t('prod_archive_title'), style: const TextStyle(color: _T.textPrimary, fontWeight: FontWeight.w700)),
        content: Text(S.t('prod_archive_msg'), style: const TextStyle(color: _T.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.t('action_cancel'), style: const TextStyle(color: _T.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text(S.t('prod_archive_btn'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.from('products').update({'is_active': false}).eq('id', productId);
        _fetchProducts();
      } on PostgrestException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.code == '42501' ? 'Accès refusé : Autorisations insuffisantes' : 'Erreur: ${e.message}'),
            backgroundColor: _T.statusUnpaidBg,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: _T.statusUnpaidBg,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      }
    }
  }

  // ─── Helpers ──────────────────────────────────────────────

  Color _getColorForName(String name) {
    for (final c in kShoeColors) {
      if (c['name'] == name) return _hexToColor(c['hex'] as String);
    }
    return _T.textSecondary;
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  // ─── Barcode Printing ─────────────────────────────────────

  Future<void> _printSingleVariant(Map<String, dynamic> variant, String productName) async {
    final barcodeText = (variant['barcode'] as String?)?.trim();
    if (barcodeText == null || barcodeText.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Aucun code-barres disponible pour cette variante'),
            backgroundColor: _T.statusUnpaidBg,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      return;
    }
    await _generateAndPrintLabel(barcodeText, productName,
      variant['size'] as String? ?? '', variant['color'] as String? ?? '',
      (variant['sell_price'] as num?)?.toDouble() ?? 0,
    );
  }

  Future<void> _printAllVariants(Map<String, dynamic> product) async {
    final variants = (product['product_variants'] as List<dynamic>?)
        ?.where((v) => v['is_active'] == true).toList() ?? [];
    if (variants.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _T.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Imprimer les étiquettes', style: TextStyle(color: _T.textPrimary, fontWeight: FontWeight.w800)),
        content: Text('Imprimer ${variants.length} étiquette(s) pour "${product['name']}"?', style: const TextStyle(color: _T.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler', style: TextStyle(color: _T.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _T.accentGold, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Imprimer', style: TextStyle(color: _T.bgPage, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final pdf = pw.Document();
    int pageCount = 0;
    for (final v in variants) {
      final barcodeText = (v['barcode'] as String?)?.trim();
      if (barcodeText == null || barcodeText.isEmpty) continue;
      await _addLabelPage(pdf, barcodeText,
        product['name'] as String? ?? '',
        v['size'] as String? ?? '', v['color'] as String? ?? '',
        (v['sell_price'] as num?)?.toDouble() ?? 0,
      );
      pageCount++;
    }
    if (pageCount > 0) {
      await Printing.layoutPdf(onLayout: (_) => pdf.save());
    }
  }

  Future<void> _printCustomQuantity(Map<String, dynamic> variant, String productName) async {
    final barcodeText = (variant['barcode'] as String?)?.trim();
    if (barcodeText == null || barcodeText.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Aucun code-barres disponible'),
            backgroundColor: _T.statusUnpaidBg,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      return;
    }

    final qtyCtrl = TextEditingController(text: '1');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _T.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.print_rounded, color: _T.accentGold),
          SizedBox(width: 8),
          Text('Quantité d\'impression', style: TextStyle(color: _T.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Combien d\'étiquettes imprimer?', style: TextStyle(color: _T.textSecondary)),
            const SizedBox(height: 12),
            _themedField(
              controller: qtyCtrl,
              label: 'Nombre de copies',
              icon: Icons.numbers_rounded,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            Text('Aperçu: $barcodeText / ${variant['size']} / ${variant['color']}',
              style: const TextStyle(fontSize: 12, color: _T.textMuted)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: _T.textSecondary))),
          ElevatedButton(
            onPressed: () {
              final qty = int.tryParse(qtyCtrl.text) ?? 1;
              if (qty > 0) Navigator.pop(ctx, qty);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _T.accentGold, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('Imprimer ${qtyCtrl.text} copie(s)', style: const TextStyle(color: _T.bgPage, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (result == null || result <= 0) return;

    final pdf = pw.Document();
    for (int i = 0; i < result; i++) {
      await _addLabelPage(pdf, barcodeText, productName,
        variant['size'] as String? ?? '', variant['color'] as String? ?? '',
        (variant['sell_price'] as num?)?.toDouble() ?? 0,
      );
    }
    await Printing.layoutPdf(onLayout: (_) => pdf.save());
  }

  Future<void> _generateAndPrintLabel(
    String barcodeText, String productName, String size, String color, double price,
  ) async {
    final pdf = pw.Document();
    await _addLabelPage(pdf, barcodeText, productName, size, color, price);
    await Printing.layoutPdf(onLayout: (_) => pdf.save());
  }

  Future<void> _addLabelPage(pw.Document pdf, String barcodeText,
    String productName, String size, String color, double price,
  ) async {
    final code128 = bc.Barcode.code128();
    final svg = code128.toSvg(barcodeText, width: 200, height: 80);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(80 * PdfPageFormat.mm, 40 * PdfPageFormat.mm),
        margin: const pw.EdgeInsets.all(2),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text('STEPZONE ERP',
                style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 2),
              pw.Expanded(
                child: pw.Center(
                  child: pw.SvgImage(svg: svg),
                ),
              ),
              pw.Text(barcodeText,
                style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 1),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('$productName / $size / $color',
                    style: const pw.TextStyle(fontSize: 4),
                  ),
                  pw.Text('${price.toStringAsFixed(0)} DA',
                    style: pw.TextStyle(fontSize: 5, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Product Detail Dialog ────────────────────────────────

  void _showProductDetailDialog(Map<String, dynamic> product) {
    final allVariants = (product['product_variants'] as List<dynamic>?) ?? [];
    final activeVariants = allVariants.where((v) => v['is_active'] == true).toList();
    final totalStock = _getTotalStock(activeVariants);
    final stockStatus = _getStockStatus(totalStock);
    final imageUrl = product['image_url'] as String?;

    final avgBuy = activeVariants.isEmpty
      ? 0.0
      : activeVariants.fold<double>(0, (s, v) => s + ((v['buy_price'] as num?)?.toDouble() ?? 0)) / activeVariants.length;
    final avgSell = activeVariants.isEmpty
      ? 0.0
      : activeVariants.fold<double>(0, (s, v) => s + ((v['sell_price'] as num?)?.toDouble() ?? 0)) / activeVariants.length;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _T.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        child: Container(
          width: 800,
          constraints: const BoxConstraints(maxHeight: 700),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 120,
                      height: 120,
                      child: imageUrl != null
                        ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildImageFallback())
                        : _buildImageFallback(),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product['name'] ?? '',
                          style: AppTextStyles.bodyMedium(color: _T.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Row(children: [
                          _buildCategoryBadge(product['category']),
                          const SizedBox(width: 8),
                          Text(product['suppliers']?['company_name'] ?? '',
                            style: AppTextStyles.bodyMedium(color: _T.textSecondary),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        _buildStockBadge(stockStatus, totalStock),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: _T.textSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Info cards
              Row(
                children: [
                  _buildInfoCard('📦 Variantes', '${activeVariants.length}', _T.accentGold),
                  const SizedBox(width: 12),
                  _buildInfoCard('💰 Prix achat moy.', '${avgBuy.toStringAsFixed(0)} DA', kWarningOrange),
                  const SizedBox(width: 12),
                  _buildInfoCard('🏷️ Prix vente moy.', '${avgSell.toStringAsFixed(0)} DA', kAccentGreen),
                ],
              ),
              const SizedBox(height: 20),

              // Variants table
              Text('Détail des variantes',
                style: AppTextStyles.bodyMedium(color: _T.textPrimary),
              ),
              const SizedBox(height: 12),

              if (activeVariants.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('Aucune variante active', style: TextStyle(color: _T.textSecondary))),
                )
              else
                Flexible(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        // Header
                        Container(
                          color: _T.bgTableHeader,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: const [
                              Expanded(flex: 2, child: Text('Code-barres',
                                style: TextStyle(color: _T.accentGold, fontWeight: FontWeight.w700, fontSize: 12))),
                              Expanded(flex: 1, child: Text('Pointure',
                                style: TextStyle(color: _T.accentGold, fontWeight: FontWeight.w700, fontSize: 12))),
                              Expanded(flex: 1, child: Text('Couleur',
                                style: TextStyle(color: _T.accentGold, fontWeight: FontWeight.w700, fontSize: 12))),
                              Expanded(flex: 1, child: Text('Stock',
                                style: TextStyle(color: _T.accentGold, fontWeight: FontWeight.w700, fontSize: 12))),
                              Expanded(flex: 1, child: Text('Achat',
                                style: TextStyle(color: _T.accentGold, fontWeight: FontWeight.w700, fontSize: 12))),
                              Expanded(flex: 1, child: Text('Vente',
                                style: TextStyle(color: _T.accentGold, fontWeight: FontWeight.w700, fontSize: 12))),
                              Expanded(flex: 1, child: Text('Marge',
                                style: TextStyle(color: _T.accentGold, fontWeight: FontWeight.w700, fontSize: 12))),
                              SizedBox(width: 64, child: Text('Actions',
                                style: TextStyle(color: _T.accentGold, fontWeight: FontWeight.w700, fontSize: 12))),
                            ],
                          ),
                        ),
                        // Rows as ExpansionTiles with price history
                        ...activeVariants.asMap().entries.map((entry) {
                          final v = entry.value;
                          final inv = v['inventory'] as List<dynamic>? ?? [];
                          int qty = 0;
                          for (var invItem in inv) {
                            qty += (invItem['quantity'] as int?) ?? 0;
                          }
                          final buy = (v['buy_price'] as num?)?.toDouble() ?? 0;
                          final sell = (v['sell_price'] as num?)?.toDouble() ?? 0;
                          final margin = sell - buy;
                          final varStatus = _getStockStatus(qty);
                          final barcodeText = v['barcode'] as String? ?? '';

                          return Container(
                            decoration: const BoxDecoration(
                              color: _T.bgTable,
                              border: Border(bottom: BorderSide(color: _T.borderColor)),
                            ),
                            child: ExpansionTile(
                              key: PageStorageKey(v['id']),
                              iconColor: _T.textSecondary,
                              collapsedIconColor: _T.textMuted,
                              tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                              childrenPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                              leading: null,
                              title: Row(
                                children: [
                                  Expanded(flex: 2, child: Text(barcodeText.isNotEmpty ? barcodeText : '-',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      color: barcodeText.isNotEmpty ? _T.textPrimary : _T.textMuted,
                                    ),
                                  )),
                                  Expanded(flex: 1, child: Text(v['size'] as String? ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.w700, color: _T.textPrimary))),
                                  Expanded(flex: 1, child: Row(
                                    children: [
                                      Container(
                                        width: 12, height: 12,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _getColorForName(v['color'] as String? ?? ''),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(child: Text(v['color'] as String? ?? '',
                                        style: const TextStyle(fontSize: 11, color: _T.textSecondary), overflow: TextOverflow.ellipsis)),
                                    ],
                                  )),
                                  Expanded(flex: 1, child: _buildStockBadge(varStatus, qty, compact: true)),
                                  Expanded(flex: 1, child: Text(buy.toStringAsFixed(0),
                                    style: const TextStyle(fontSize: 11, color: _T.accentGold))),
                                  Expanded(flex: 1, child: Text(sell.toStringAsFixed(0),
                                    style: const TextStyle(fontSize: 11, color: _T.statusPaidText))),
                                  Expanded(flex: 1, child: Text(
                                    margin >= 0 ? '+${margin.toStringAsFixed(0)}' : margin.toStringAsFixed(0),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: margin >= 0 ? kAccentGreen : kDangerRed,
                                    ),
                                  )),
                                  SizedBox(
                                    width: 64,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (barcodeText.isNotEmpty)
                                          IconButton(
                                            icon: const Icon(Icons.print_outlined, size: 16, color: _T.textSecondary),
                                            tooltip: 'Imprimer',
                                            onPressed: () => _showPrintChoice(v, product['name'] as String? ?? ''),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        IconButton(
                                          icon: const Icon(Icons.edit_rounded, size: 16, color: _T.accentBlue),
                                          tooltip: 'Modifier',
                                          onPressed: () { Navigator.pop(ctx); _showEditVariantDialog(v); },
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              children: [
                                Text('Historique des prix',
                                  style: AppTextStyles.bodyMedium(color: _T.accentGold),
                                ),
                                const SizedBox(height: 8),
                                _buildVariantPriceHistory(v['id']),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (activeVariants.isNotEmpty)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const Text('Imprimer tout'),
                      onPressed: () { Navigator.pop(ctx); _printAllVariants(product); },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _T.accentGold,
                        side: BorderSide(color: _T.accentGold.withValues(alpha: 0.3)),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  Row(
                    children: [
                      if (AppSession.isOwner)
                        TextButton.icon(
                          icon: const Icon(Icons.archive_rounded, color: _T.statusUnpaidText, size: 18),
                          label: Text(S.t('prod_archive_btn'), style: const TextStyle(color: _T.statusUnpaidText)),
                          onPressed: () { Navigator.pop(ctx); _archiveProduct(product['id']); },
                        ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(backgroundColor: _T.accentGold, foregroundColor: _T.bgPage, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        child: const Text('Fermer', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrintChoice(Map<String, dynamic> variant, String productName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _T.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Options d\'impression', style: TextStyle(color: _T.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
        content: const Text('Combien d\'étiquettes imprimer pour cette variante?', style: TextStyle(color: _T.textSecondary)),
        actions: [
          TextButton(onPressed: () { Navigator.pop(ctx); _printSingleVariant(variant, productName); },
            child: const Text('1 copie', style: TextStyle(color: _T.textSecondary))),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _printCustomQuantity(variant, productName); },
            style: ElevatedButton.styleFrom(backgroundColor: _T.accentGold, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('X copies (saisir)', style: TextStyle(color: _T.bgPage, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(label, style: AppTextStyles.bodyMedium(color: _T.textSecondary)),
            const SizedBox(height: 4),
            Text(value, style: AppTextStyles.bodyMedium(color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildImageFallback() {
    return Container(
      color: _T.borderColor,
      child: const Center(child: Icon(Icons.shopping_bag_rounded, size: 40, color: _T.textMuted)),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchVariantPriceHistory(String variantId) async {
    try {
      final res = await Supabase.instance.client.rpc('get_price_history', params: {
        'p_variant_id': variantId,
      });
      return List<Map<String, dynamic>>.from(res as List);
    } catch (_) {
      return [];
    }
  }

  Widget _buildVariantPriceHistory(String variantId) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchVariantPriceHistory(variantId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 60,
            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _T.accentGold))),
          );
        }
        final history = snapshot.data ?? [];
        if (history.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Aucun historique', style: TextStyle(color: _T.textSecondary)),
          );
        }

        final spots = <FlSpot>[];
        for (int i = 0; i < history.length; i++) {
          final price = (history[i]['purchase_price'] as num?)?.toDouble() ?? 0;
          spots.add(FlSpot(i.toDouble(), price));
        }

        final minY = spots.fold<double>(double.infinity, (s, e) => e.y < s ? e.y : s);
        final maxY = spots.fold<double>(double.negativeInfinity, (s, e) => e.y > s ? e.y : s);
        final yRange = maxY - minY;
        final adjustedMin = minY - (yRange * 0.1);
        final adjustedMax = maxY + (yRange * 0.1);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 120,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: _T.textMuted.withValues(alpha: 0.25),
                      strokeWidth: 0.5,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (value, meta) {
                          return Text('${value.toInt()}',
                            style: const TextStyle(fontSize: 8, color: _T.textSecondary),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= history.length) return const SizedBox.shrink();
                          final date = history[idx]['purchased_at'] as String? ?? '';
                          final label = date.length >= 10 ? date.substring(0, 10) : date;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(label,
                              style: const TextStyle(fontSize: 7, color: _T.textSecondary),
                            ),
                          );
                        },
                        interval: (history.length / 4).ceilToDouble().clamp(1, double.infinity),
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: adjustedMin,
                  maxY: adjustedMax,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: _T.accentGold,
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: history.length <= 20,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 3,
                            color: _T.accentGold,
                            strokeWidth: 1,
                            strokeColor: _T.bgCard,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: _T.accentGold.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                        final idx = spot.spotIndex;
                        final date = idx < history.length
                            ? (history[idx]['purchased_at'] as String? ?? '').substring(0, 10)
                            : '';
                        return LineTooltipItem(
                          '$date\n${spot.y.toStringAsFixed(0)} DA',
                          const TextStyle(color: _T.textPrimary),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Table
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: _T.borderColor),
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    color: _T.bgTableHeader,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: const Row(
                      children: [
                        Expanded(flex: 2, child: Text('Date',
                          style: TextStyle(color: _T.accentGold, fontWeight: FontWeight.w700, fontSize: 11))),
                        Expanded(flex: 2, child: Text('Fournisseur',
                          style: TextStyle(color: _T.accentGold, fontWeight: FontWeight.w700, fontSize: 11))),
                        Expanded(flex: 1, child: Text('Prix',
                          style: TextStyle(color: _T.accentGold, fontWeight: FontWeight.w700, fontSize: 11))),
                        Expanded(flex: 1, child: Text('Variation',
                          style: TextStyle(color: _T.accentGold, fontWeight: FontWeight.w700, fontSize: 11))),
                      ],
                    ),
                  ),
                  ...history.asMap().entries.map((entry) {
                    final i = entry.key;
                    final h = entry.value;
                    final date = (h['purchased_at'] as String? ?? '').substring(0, 10);
                    final supplier = h['supplier_name'] as String? ?? '-';
                    final price = (h['purchase_price'] as num?)?.toDouble() ?? 0;
                    final prev = h['prev_price'] as num?;
                    final change = prev != null ? price - prev.toDouble() : 0.0;
                    final hasChange = prev != null;

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: i.isEven ? _T.bgTable : _T.bgTableRowAlt,
                        border: const Border(bottom: BorderSide(color: _T.borderColor)),
                      ),
                      child: Row(
                        children: [
                          Expanded(flex: 2, child: Text(date,
                            style: const TextStyle(fontSize: 10, color: _T.textSecondary))),
                          Expanded(flex: 2, child: Text(supplier,
                            style: const TextStyle(fontSize: 10, color: _T.textPrimary))),
                          Expanded(flex: 1, child: Text('${price.toStringAsFixed(0)} DA',
                            style: const TextStyle(fontSize: 10, color: _T.accentGold))),
                          Expanded(
                            flex: 1,
                            child: hasChange
                                ? Row(
                                    children: [
                                      Icon(
                                        change >= 0 ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
                                        size: 16,
                                        color: change >= 0 ? kDangerRed : kAccentGreen,
                                      ),
                                      Text(
                                        '${change >= 0 ? '+' : ''}${change.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: change >= 0 ? kDangerRed : kAccentGreen,
                                        ),
                                      ),
                                    ],
                                  )
                                : const Text('-', style: TextStyle(fontSize: 10, color: _T.textMuted)),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatChip(String emoji, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _T.accentGold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _T.accentGold.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(text,
            style: AppTextStyles.bodyMedium(color: _T.accentGold),
          ),
        ],
      ),
    );
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
      backgroundColor: _T.bgPage,
      appBar: AppBar(
        title: Text(S.t('prod_catalog_title'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _T.textPrimary),
        ),
        backgroundColor: _T.bgAppBar,
        foregroundColor: _T.textPrimary,
        elevation: 0,
        actions: [
          if (hasActiveFilters)
            TextButton(
              onPressed: _resetFilters,
              child: const Text('Réinitialiser', style: TextStyle(color: _T.textSecondary)),
            ),
          IconButton(
            icon: const Icon(Icons.checklist_rounded, color: _T.textSecondary),
            tooltip: 'Sélectionner',
            onPressed: () => setState(() => _selectionMode = true),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _T.textSecondary),
            tooltip: S.t('action_refresh'),
            onPressed: _fetchProducts,
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: AppSession.isOwner
          ? FloatingActionButton.extended(
              onPressed: widget.onAddProduct,
              backgroundColor: _T.accentGold,
              icon: const Icon(Icons.add_rounded, color: _T.bgPage),
              label: Text(S.t('prod_add_btn'), style: const TextStyle(fontWeight: FontWeight.w700, color: _T.bgPage)),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _T.accentGold))
          : Column(
              children: [
                // Search bar
                Container(
                  padding: const EdgeInsets.all(16),
                  color: _T.bgAppBar,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: _T.bgCard,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _T.borderColor),
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: _T.textPrimary, fontSize: 14),
                            cursorColor: _T.accentGold,
                            decoration: InputDecoration(
                              hintText: S.t('prod_search_hint'),
                              hintStyle: const TextStyle(color: _T.textMuted, fontSize: 13),
                              prefixIcon: const Icon(Icons.search_rounded, color: _T.textMuted, size: 18),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
                            color: _T.accentGold.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _T.accentGold.withValues(alpha: 0.3)),
                          ),
                          child: Text('$_activeFilterCount filtre(s)',
                            style: const TextStyle(fontSize: 11, color: _T.accentGold),
                          ),
                        ),
                      const SizedBox(width: 12),
                      _buildMiniStat(S.t('prod_active_count'), '${_filteredProducts.length}', Icons.category_rounded, _T.accentBlue),
                    ],
                  ),
                ),

                // Negative stock banner
                if (_negativeCount > 0)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _T.statusUnpaidBg,
                      border: Border.all(color: _T.statusUnpaidText),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: _T.statusUnpaidText),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$_negativeCount produit(s) avec stock négatif détecté — vérification requise',
                            style: AppTextStyles.bodyMedium(
                              color: _T.statusUnpaidText,
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
                    color: _T.bgAppBar,
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
                                icon: Icons.check_circle_rounded, chipColor: kAccentGreen,
                                onSelected: () => setState(() => _filterStockStatus = 'healthy')),
                              const SizedBox(width: 8),
                              _buildFilterChip('Faible', 'low', _filterStockStatus,
                                icon: Icons.warning_amber_rounded, chipColor: kWarningOrange,
                                onSelected: () => setState(() => _filterStockStatus = 'low')),
                              const SizedBox(width: 8),
                              _buildFilterChip('Rupture', 'empty', _filterStockStatus,
                                icon: Icons.remove_circle_rounded, chipColor: kDangerRed,
                                onSelected: () => setState(() => _filterStockStatus = 'empty')),
                              const SizedBox(width: 8),
                              _buildFilterChip('Négatif', 'negative', _filterStockStatus,
                                icon: Icons.error_rounded, chipColor: kNegativeRed,
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
                        if (_selectionMode)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: _allVisibleVariants.isNotEmpty &&
                                      _selectedVariantIds.length == _allVisibleVariants.length,
                                  onChanged: (_) => _toggleSelectAllVariants(),
                                  activeColor: _T.accentGold,
                                  checkColor: _T.bgPage,
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                const SizedBox(width: 4),
                                Text('Tout sélectionner (${_allVisibleVariants.length})',
                                  style: AppTextStyles.bodyMedium(color: _T.textPrimary),
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  icon: const Icon(Icons.close_rounded, size: 16, color: _T.textSecondary),
                                  label: const Text('Annuler', style: TextStyle(color: _T.textSecondary)),
                                  onPressed: () => setState(() {
                                    _selectionMode = false;
                                    _selectedVariantIds.clear();
                                  }),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          '${_filteredProducts.length} produit(s) trouvé(s)',
                          style: AppTextStyles.bodyMedium(color: _T.textSecondary),
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
                                hasActiveFilters ? Icons.filter_alt_off_rounded : Icons.inventory_2_outlined,
                                size: 48,
                                color: _T.textMuted,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                hasActiveFilters
                                  ? 'Aucun produit ne correspond aux filtres sélectionnés'
                                  : S.t('prod_no_results'),
                                style: AppTextStyles.bodyMedium(color: _T.textSecondary),
                              ),
                              if (hasActiveFilters) ...[
                                const SizedBox(height: 16),
                                OutlinedButton(
                                  onPressed: _resetFilters,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _T.accentGold,
                                    side: BorderSide(color: _T.accentGold.withValues(alpha: 0.3)),
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

                            return GestureDetector(
                              onSecondaryTap: () => _enterSelectionMode(''),
                              child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                border: Border(left: BorderSide(
                                  color: _getStockColor(stockStatus),
                                  width: stockStatus == StockStatus.negative ? 4 : 3,
                                )),
                                color: stockStatus == StockStatus.negative
                                    ? kNegativeRed.withValues(alpha: 0.05)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(kBorderRadius + 2),
                              ),
                              child: Card(
                                margin: EdgeInsets.zero,
                                color: _T.bgCard,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(kBorderRadius),
                                  side: const BorderSide(color: _T.borderColor),
                                ),
                                child: Theme(
                                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                  iconColor: _T.textSecondary,
                                  collapsedIconColor: _T.textMuted,
                                  leading: Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: _T.borderColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: imageUrl != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.network(imageUrl, fit: BoxFit.cover),
                                          )
                                        : const Icon(Icons.image_not_supported_rounded, color: _T.textMuted),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          product['name'] ?? 'Inconnu',
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.bodyMedium(color: _T.textPrimary),
                                        ),
                                      ),
                                      _buildCategoryBadge(product['category']),
                                    ],
                                  ),
                                  subtitle: Row(
                                    children: [
                                      const Icon(Icons.local_shipping_rounded, size: 14, color: _T.textMuted),
                                      const SizedBox(width: 4),
                                      Flexible(child: Text(supplierName, overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: _T.textSecondary))),
                                      const SizedBox(width: 12),
                                      const Icon(Icons.style_rounded, size: 14, color: _T.textMuted),
                                      const SizedBox(width: 4),
                                      Text('${activeVariants.length} var.',
                                        style: const TextStyle(color: _T.textSecondary)),
                                      const SizedBox(width: 12),
                                      _buildStockBadge(stockStatus, totalStock),
                                    ],
                                  ),
                                  children: [
                                    if (activeVariants.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text(S.t('prod_no_active_variants'), style: const TextStyle(color: _T.textSecondary)),
                                      )
                                    else
                                      Container(
                                        color: _T.bgTable,
                                        child: Column(
                                          children: [

                                            if (activeVariants.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                                                child: Row(
                                                  children: [
                                                    _buildStatChip('📦', '${activeVariants.length} variantes'),
                                                    const SizedBox(width: 8),
                                                    _buildStatChip('🎨',
                                                      '${activeVariants.map((x) => x['color'] as String).toSet().length} couleurs'),
                                                    const SizedBox(width: 8),
                                                    _buildStatChip('👟',
                                                      '${activeVariants.map((x) => x['size'] as String).toSet().length} pointures'),
                                                  ],
                                                ),
                                              ),

                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                              decoration: BoxDecoration(color: _T.accentGold.withValues(alpha: 0.06)),
                                              child: Row(
                                                children: [
                                                  Expanded(flex: 2, child: Text(S.t('prod_details'), style: const TextStyle(fontWeight: FontWeight.bold, color: _T.textPrimary))),
                                                  Expanded(flex: 2, child: Text(S.t('label_barcode'), style: const TextStyle(fontWeight: FontWeight.bold, color: _T.textPrimary))),
                                                  Expanded(flex: 3, child: Text(S.t('prod_buy_sell_margin'), style: const TextStyle(fontWeight: FontWeight.bold, color: _T.textPrimary))),
                                                  Expanded(flex: 1, child: Text(S.t('label_stock'), style: const TextStyle(fontWeight: FontWeight.bold, color: _T.accentBlue))),
                                                  SizedBox(width: 96, child: Text(S.t('label_actions'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: _T.textPrimary))),
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

                                              final isSelected = _selectedVariantIds.contains(v['id']);
                                              final vid = v['id'] as String;

                                              return GestureDetector(
                                                onLongPress: () => _enterSelectionMode(vid),
                                                onSecondaryTap: () => _enterSelectionMode(vid),
                                                child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                                                decoration: BoxDecoration(
                                                  border: const Border(bottom: BorderSide(color: _T.borderColor)),
                                                  color: variantStock < 0 ? kNegativeRed.withValues(alpha: 0.05) : null,
                                                ),
                                                child: Row(
                                                  children: [
                                                    if (_selectionMode)
                                                      Checkbox(
                                                        value: isSelected,
                                                        activeColor: _T.accentGold,
                                                        checkColor: _T.bgPage,
                                                        onChanged: (_) {
                                                          setState(() {
                                                            if (isSelected) {
                                                              _selectedVariantIds.remove(v['id']);
                                                            } else {
                                                              _selectedVariantIds.add(v['id']);
                                                            }
                                                          });
                                                        },
                                                        visualDensity: VisualDensity.compact,
                                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                      ),
                                                    Expanded(flex: 2, child: Text('${v['size']} - ${v['color']}',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: variantStock < 0 ? kNegativeRed : _T.textPrimary,
                                                      ),
                                                    )),
                                                    Expanded(flex: 2, child: Text(v['barcode'] ?? '-',
                                                      style: const TextStyle(fontSize: 12, color: _T.textSecondary))),
                                                    Expanded(
                                                      flex: 3,
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        if (AppSession.isOwner) ...[
                                                          Text('${S.t('prod_buy_short')}$buyPrice ${S.t('misc_currency')}',
                                                            style: const TextStyle(fontSize: 12, color: _T.accentGold)),
                                                          Text('${S.t('prod_sell_short')}$sellPrice ${S.t('misc_currency')}',
                                                            style: const TextStyle(fontSize: 12, color: _T.statusPaidText)),
                                                          Text('${S.t('prod_margin_short')}$margin ${S.t('misc_currency')}',
                                                            style: const TextStyle(fontSize: 11, color: _T.accentBlue)),
                                                        ] else
                                                          Text('${S.t('prod_sell_short')}$sellPrice ${S.t('misc_currency')}',
                                                            style: const TextStyle(fontSize: 12, color: _T.statusPaidText)),
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
                                                      width: 96,
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.end,
                                                        children: [
                                                          if ((v['barcode'] as String?)?.isNotEmpty == true)
                                                            IconButton(
                                                              icon: const Icon(Icons.print_outlined, size: 16, color: _T.textSecondary),
                                                              tooltip: 'Imprimer étiquette',
                                                              onPressed: () => _printCustomQuantity(v, product['name']),
                                                            ),
                                                          if (AppSession.isOwner) ...[
                                                            IconButton(
                                                              icon: const Icon(Icons.edit_rounded, size: 16, color: _T.accentBlue),
                                                              tooltip: S.t('prod_edit_price_code'),
                                                              onPressed: () => _showEditVariantDialog(v),
                                                            ),
                                                            IconButton(
                                                              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: _T.statusUnpaidText),
                                                              tooltip: S.t('prod_archive_variant'),
                                                              onPressed: () => _archiveVariant(v['id']),
                                                            ),
                                                          ]
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                            }),
                                          ],
                                        ),
                                      ),

                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          OutlinedButton.icon(
                                            icon: const Icon(Icons.info_outline_rounded, size: 18),
                                            label: const Text('Détails complets'),
                                            onPressed: () => _showProductDetailDialog(product),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: _T.accentGold,
                                              side: BorderSide(color: _T.accentGold.withValues(alpha: 0.3)),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (AppSession.isOwner)
                                            TextButton.icon(
                                              onPressed: () => _archiveProduct(product['id']),
                                              icon: const Icon(Icons.archive_rounded, color: _T.statusUnpaidText, size: 18),
                                              label: Text(S.t('prod_archive_btn'), style: const TextStyle(color: _T.statusUnpaidText)),
                                            ),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                                ),
                              ),
                            ),
                          );
                          },
                        ),
                ),
                if (_selectionMode && _selectedVariantIds.isNotEmpty)
                  _buildBulkPrintBar(),
              ],
            ),
    );
  }

  Widget _buildBulkPrintBar() {
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: _T.bgCard,
          border: const Border(top: BorderSide(color: _T.borderColor)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: _T.statusPaidText, size: 20),
              const SizedBox(width: 8),
              Text(
                '${_selectedVariantIds.length} sélectionné(s)',
                style: AppTextStyles.bodyMedium(color: _T.textPrimary),
              ),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.print_rounded, size: 18),
                label: Text('Imprimer Barcodes (${_selectedVariantIds.length})'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _T.accentGold,
                  foregroundColor: _T.bgPage,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _showBulkPrintDialog,
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildFilterChip(String label, String? value, String? currentValue, {
    VoidCallback? onSelected,
    IconData? icon,
    Color chipColor = _T.accentGold,
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
            color: selected ? chipColor : chipColor.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: selected ? _T.bgPage : chipColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: AppTextStyles.bodyMedium(color: selected ? _T.bgPage : chipColor),
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
      case StockStatus.healthy: icon = Icons.check_circle_rounded; break;
      case StockStatus.low: icon = Icons.warning_amber_rounded; break;
      case StockStatus.empty: icon = Icons.remove_circle_rounded; break;
      case StockStatus.negative: icon = Icons.error_rounded; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
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
        color: color.withValues(alpha: 0.12),
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
              Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }
}