import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:isar/isar.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/app_session.dart';
import '../../local_db/isar_service.dart';
import '../../local_db/collections/store_local.dart';
import '../../local_db/collections/inventory_local.dart';
import '../../local_db/collections/product_variant_local.dart';
import '../../local_db/collections/product_local.dart';
import '../../local_db/collections/transaction_local.dart';
import '../../local_db/collections/user_profile_local.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<dynamic> _stores = [];
  String? _selectedStoreId;

  List<dynamic> _inventoryItems = [];
  List<dynamic> _lowStockAlerts = [];
  List<dynamic> _recentMovements = [];

  bool _isLoading = true;
  final _searchController = TextEditingController();
  String _searchQuery = '';

 
  StreamSubscription<List<Map<String, dynamic>>>? _inventorySubscription;

  
  int _totalProducts = 0;
  int _totalStock = 0;
  int _lowStockCount = 0;
  double _totalValue = 0;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('fr', timeago.FrMessages());
    _fetchStores();
  }

  @override
  void dispose() {
    _inventorySubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchStores() async {
    if (AppSession.isOfflineMode) {
      final isar = await IsarService.getInstance();
      final res = await isar.storeLocals
          .filter()
          .isActiveEqualTo(true)
          .findAll();
          
      if (mounted) {
        setState(() {
          _stores = res.map((s) => {'id': s.supabaseId, 'name': s.name}).toList();
          if (_stores.isNotEmpty) {
            _selectedStoreId = _stores.first['id'];
          }
        });
        if (_selectedStoreId != null) {
          _fetchInventoryData();
        } else {
          setState(() => _isLoading = false);
        }
      }
      return;
    }

    try {
      final res = await Supabase.instance.client
          .from('stores')
          .select()
          .eq('is_active', true) 
          .order('name', ascending: true);
      if (mounted) {
        setState(() {
          _stores = res;
          if (_stores.isNotEmpty) {
            _selectedStoreId = _stores.first['id'];
          }
        });
        if (_selectedStoreId != null) {
          _fetchInventoryData();
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      debugPrint("Error fetching stores: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setupRealtimeStreams() {
    _inventorySubscription?.cancel();
    if (_selectedStoreId == null) return;

  
    _inventorySubscription = Supabase.instance.client
        .from('inventory')
        .stream(primaryKey: ['id'])
        .eq('store_id', _selectedStoreId!)
        .order('quantity', ascending: true)
        .listen((data) async {
          final enrichedData = await Future.wait(data.map((item) async {
            final variantRes = await Supabase.instance.client
                .from('product_variants')
                .select('id, size, color, barcode, buy_price, products(name, image_url)') // جلب buy_price الحقيقي
                .eq('id', item['variant_id'])
                .eq('is_active', true) 
                .maybeSingle();
            item['product_variants'] = variantRes;
            return item;
          }));

          
          final validData = enrichedData.where((item) => item['product_variants'] != null).toList();

          if (mounted) {
            setState(() {
              _inventoryItems = validData;
              _totalProducts = validData.length;
              _totalStock = 0;
              _lowStockCount = 0;
              _totalValue = 0;
              
              _lowStockAlerts.clear(); 

              for (var item in validData) {
                final qty = (item['quantity'] as int?) ?? 0;
            
                final buyPrice = double.tryParse(item['product_variants']?['buy_price']?.toString() ?? '0') ?? 0.0;
                
                _totalStock += qty;
                _totalValue += (qty * buyPrice);
                
                if (qty < 3) {
                  _lowStockCount++;
                  _lowStockAlerts.add(item); 
                }
              }
            });
          }
        });
  }

  Future<void> _fetchInventoryData() async {
    setState(() => _isLoading = true);

    if (AppSession.isOfflineMode) {
      if (_selectedStoreId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final isar = await IsarService.getInstance();
      
      final localInventory = await isar.inventoryLocals
          .filter()
          .storeIdEqualTo(_selectedStoreId!)
          .findAll();
          
      final localVariants = await isar.productVariantLocals.where().findAll();
      final localProducts = await isar.productLocals.where().findAll();
      
      final variantMap = {for (var v in localVariants) v.supabaseId: v};
      final productMap = {for (var p in localProducts) p.supabaseId: p};

      final enrichedData = localInventory.map((item) {
        final variant = variantMap[item.variantId];
        if (variant == null) return null;
        
        final product = productMap[variant.productId];
        if (product == null) return null;

        return {
          'id': item.supabaseId,
          'quantity': item.quantity,
          'variant_id': item.variantId,
          'product_variants': {
            'id': variant.supabaseId,
            'size': variant.size,
            'color': variant.color,
            'barcode': variant.barcode,
            'buy_price': variant.buyPrice,
            'products': {
              'name': product.name,
              'image_url': product.imageUrl,
            }
          }
        };
      }).where((item) => item != null).map((item) => item!).toList();

      if (mounted) {
        setState(() {
          _inventoryItems = enrichedData;
          _totalProducts = enrichedData.length;
          _totalStock = 0;
          _lowStockCount = 0;
          _totalValue = 0;
          _lowStockAlerts.clear();

          for (var item in enrichedData) {
            final qty = (item['quantity'] as int?) ?? 0;
            final buyPrice = (item['product_variants']['buy_price'] as num?)?.toDouble() ?? 0.0;
            
            _totalStock += qty;
            _totalValue += (qty * buyPrice);
            
            if (qty < 3) {
              _lowStockCount++;
              _lowStockAlerts.add(item);
            }
          }
        });
      }
      
      await _fetchRecentMovements();
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    _setupRealtimeStreams();
    await _fetchRecentMovements();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchRecentMovements() async {
    if (_selectedStoreId == null) return;

    if (AppSession.isOfflineMode) {
      final isar = await IsarService.getInstance();
      
      final localTransactions = await isar.transactionLocals
          .filter()
          .storeIdEqualTo(_selectedStoreId!)
          .findAll();
          
      // Sort manually as Isar filter doesn't support complex sorting without indices
      localTransactions.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
      
      final variants = await isar.productVariantLocals.where().findAll();
      final products = await isar.productLocals.where().findAll();
      final profiles = await isar.userProfileLocals.where().findAll();
      
      final variantMap = {for (var v in variants) v.supabaseId: v};
      final productMap = {for (var p in products) p.supabaseId: p};
      final profileMap = {for (var pr in profiles) pr.supabaseId: pr};

      final results = localTransactions.take(20).map((mov) {
        final variant = variantMap[mov.variantId];
        final product = variant != null ? productMap[variant.productId] : null;
        final profile = profileMap[mov.userId];

        return {
          'id': mov.supabaseId,
          'type': mov.type,
          'quantity': mov.quantity,
          'created_at': mov.createdAt?.toIso8601String(),
          'product_variants': {
            'size': variant?.size,
            'color': variant?.color,
            'products': {
              'name': product?.name ?? 'Inconnu',
            }
          },
          'user_profiles': {
            'full_name': profile?.fullName ?? 'Système',
          }
        };
      }).toList();

      if (mounted) {
        setState(() => _recentMovements = results);
      }
      return;
    }

    try {
      final res = await Supabase.instance.client
          .from('transactions')
          .select('*, product_variants(size, color, products(name)), user_profiles(full_name)')
          .eq('store_id', _selectedStoreId!)
          .order('created_at', ascending: false)
          .limit(20); 

      if (mounted) {
        setState(() => _recentMovements = res);
      }
    } catch (e) {
      debugPrint("Error fetching movements: $e");
    }
  }

  List<dynamic> get _filteredInventory {
    if (_searchQuery.isEmpty) return _inventoryItems;
    return _inventoryItems.where((item) {
      final name = (item['product_variants']?['products']?['name'] ?? '').toString().toLowerCase();
      final barcode = (item['product_variants']?['barcode'] ?? '').toString().toLowerCase();
      final size = (item['product_variants']?['size'] ?? '').toString().toLowerCase();
      final color = (item['product_variants']?['color'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return name.contains(q) || barcode.contains(q) || size.contains(q) || color.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Tableau de Bord: Inventaire & Flux"),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
        actions: [
          if (_stores.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedStoreId,
                  dropdownColor: Colors.teal[800],
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  items: _stores.map<DropdownMenuItem<String>>((store) {
                    return DropdownMenuItem<String>(
                      value: store['id'],
                      child: Row(children: [
                        const Icon(Icons.warehouse, color: Colors.white70, size: 18),
                        const SizedBox(width: 8),
                        Text(store['name']),
                      ]),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedStoreId = val);
                    _fetchInventoryData();
                  },
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: _fetchInventoryData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stores.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warehouse_outlined, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("Aucun magasin. Ajoutez d'abord un magasin.", style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ],
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                       
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _buildStatCard('Total Produits', '$_totalProducts', Icons.category, Colors.blue),
                                _buildStatCard('Stock Total', '$_totalStock unités', Icons.inventory_2, Colors.green),
                                _buildStatCard('Valeur (Achat)', '${_totalValue.toStringAsFixed(2)} DA', Icons.account_balance_wallet, Colors.orange),
                                _buildStatCard('Stock Faible', '$_lowStockCount', Icons.warning_amber, Colors.red),
                              ],
                            ),
                          ),

                     
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                              ),
                              child: TextField(
                                controller: _searchController,
                                decoration: const InputDecoration(
                                  hintText: 'Rechercher un produit (Nom, Code-barres, Taille, Couleur)...',
                                  prefixIcon: Icon(Icons.search),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.all(16),
                                ),
                                onChanged: (val) => setState(() => _searchQuery = val),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                        
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                              ),
                              child: _filteredInventory.isEmpty
                                  ? const Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                                          SizedBox(height: 12),
                                          Text('Aucun produit dans ce magasin', style: TextStyle(color: Colors.grey, fontSize: 16)),
                                        ],
                                      ),
                                    )
                                  : ListView.separated(
                                      padding: const EdgeInsets.all(8),
                                      itemCount: _filteredInventory.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final item = _filteredInventory[index];
                                        final variant = item['product_variants'] ?? {};
                                        final product = variant['products'] ?? {};
                                        final qty = (item['quantity'] as int?) ?? 0;
                                        final isLow = qty < 3;

                                        return ListTile(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          leading: Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: isLow ? Colors.red[50] : Colors.teal[50],
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: product['image_url'] != null
                                                ? ClipRRect(
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: Image.network(product['image_url'], fit: BoxFit.cover),
                                                  )
                                                : Icon(Icons.image_not_supported, color: isLow ? Colors.red : Colors.teal),
                                          ),
                                          title: Text(
                                            product['name'] ?? 'Inconnu',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          subtitle: Text(
                                            'Taille: ${variant['size'] ?? '-'} | Couleur: ${variant['color'] ?? '-'} | Code-barres: ${variant['barcode'] ?? '-'}',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                          trailing: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: isLow ? Colors.red[50] : Colors.green[50],
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: isLow ? Colors.red : Colors.green),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (isLow) const Icon(Icons.warning_amber, size: 16, color: Colors.red),
                                                if (isLow) const SizedBox(width: 4),
                                                Text(
                                                  '$qty',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18,
                                                    color: isLow ? Colors.red : Colors.green[800],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),

                   
                    Expanded(
                      flex: 2,
                      child: Container(
                        margin: const EdgeInsets.only(top: 16, right: 16, bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                     
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: Colors.red),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Alertes Stock Faible (< 3)',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16),
                                    ),
                                  ),
                                  Chip(
                                    label: Text('$_lowStockCount'),
                                    backgroundColor: Colors.red,
                                    labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                           
                            SizedBox(
                              height: 250,
                              child: _lowStockAlerts.isEmpty
                                  ? const Center(child: Text('Aucune alerte. Le stock est bon!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)))
                                  : ListView.separated(
                                      padding: const EdgeInsets.all(8),
                                      itemCount: _lowStockAlerts.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final alert = _lowStockAlerts[index];
                                        final variant = alert['product_variants'] ?? {};
                                        final name = variant['products']?['name'] ?? 'Inconnu';
                                        final size = variant['size'] ?? '-';
                                        final qty = alert['quantity'] ?? 0;
                                        return ListTile(
                                          dense: true,
                                          leading: CircleAvatar(
                                            backgroundColor: Colors.red[100],
                                            radius: 16,
                                            child: Text('$qty', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                                          ),
                                          title: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                          subtitle: Text('Taille: $size', style: const TextStyle(fontSize: 11)),
                                        );
                                      },
                                    ),
                            ),

                        
                            Container(
                              padding: const EdgeInsets.all(16),
                              color: Colors.indigo[50],
                              child: const Row(
                                children: [
                                  Icon(Icons.swap_vert, color: Colors.indigo),
                                  SizedBox(width: 8),
                                  Text(
                                    'Derniers Flux (Entrées / Sorties)',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                        
                            Expanded(
                              child: _recentMovements.isEmpty
                                  ? const Center(child: Text('Aucun mouvement récent', style: TextStyle(color: Colors.grey)))
                                  : ListView.separated(
                                      padding: const EdgeInsets.all(8),
                                      itemCount: _recentMovements.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final mov = _recentMovements[index];
                                        final isIn = mov['type'] == 'in';
                                        final productName = mov['product_variants']?['products']?['name'] ?? 'Inconnu';
                                        final size = mov['product_variants']?['size'] ?? '-';
                                        final userName = mov['user_profiles']?['full_name'] ?? 'Système';
                                        final date = DateTime.tryParse(mov['created_at'] ?? '');
                                        final qty = mov['quantity'] ?? 0;

                                        return ListTile(
                                          dense: true,
                                          leading: CircleAvatar(
                                            backgroundColor: isIn ? Colors.blue[50] : Colors.green[50],
                                            radius: 16,
                                            child: Icon(
                                              isIn ? Icons.arrow_downward : Icons.arrow_upward,
                                              color: isIn ? Colors.blue : Colors.green,
                                              size: 18,
                                            ),
                                          ),
                                          title: Text(
                                            '$productName ($size)',
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                          ),
                                          subtitle: Text(
                                            '${isIn ? "Acheté" : "Vendu"} par $userName • ${date != null ? timeago.format(date, locale: 'fr') : ''}',
                                            style: const TextStyle(fontSize: 11),
                                          ),
                                          trailing: Text(
                                            '${isIn ? "+" : "-"}$qty',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isIn ? Colors.blue : Colors.green,
                                              fontSize: 14,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 220, 
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
        border: Border(bottom: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded( 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}