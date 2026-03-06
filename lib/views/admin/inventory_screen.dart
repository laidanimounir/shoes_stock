import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

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

  // Stats
  int _totalProducts = 0;
  int _totalStock = 0;
  int _lowStockCount = 0;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('fr', timeago.FrMessages());
    _fetchStores();
  }

  Future<void> _fetchStores() async {
    try {
      final res = await Supabase.instance.client
          .from('stores')
          .select()
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

  Future<void> _fetchInventoryData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchInventory(),
      _fetchLowStock(),
      _fetchRecentMovements(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchInventory() async {
    try {
      final res = await Supabase.instance.client
          .from('inventory')
          .select('id, quantity, product_variants(id, size, color, barcode, products(name, image_url))')
          .eq('store_id', _selectedStoreId!)
          .order('quantity', ascending: true);

      if (mounted) {
        setState(() {
          _inventoryItems = res;
          _totalProducts = res.length;
          _totalStock = 0;
          _lowStockCount = 0;
          for (var item in res) {
            final qty = (item['quantity'] as int?) ?? 0;
            _totalStock += qty;
            if (qty < 3) _lowStockCount++;
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching inventory: $e");
    }
  }

  Future<void> _fetchLowStock() async {
    try {
      final res = await Supabase.instance.client
          .from('inventory')
          .select('quantity, product_variants(size, color, barcode, products(name))')
          .eq('store_id', _selectedStoreId!)
          .lt('quantity', 3)
          .order('quantity', ascending: true)
          .limit(20);

      if (mounted) {
        setState(() => _lowStockAlerts = res);
      }
    } catch (e) {
      debugPrint("Error fetching low stock: $e");
    }
  }

  Future<void> _fetchRecentMovements() async {
    try {
      final res = await Supabase.instance.client
          .from('transactions')
          .select('*, product_variants(size, color, products(name)), user_profiles(full_name)')
          .eq('store_id', _selectedStoreId!)
          .order('created_at', ascending: false)
          .limit(30);

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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Gestion de l'Inventaire"),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
        actions: [
          // Store selector
          if (_stores.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
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
                  children: [
                    // Left Panel: Inventory List
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          // Stats Row
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                _buildStatCard('Total Produits', '$_totalProducts', Icons.category, Colors.blue),
                                const SizedBox(width: 12),
                                _buildStatCard('Stock Total', '$_totalStock unités', Icons.inventory_2, Colors.green),
                                const SizedBox(width: 12),
                                _buildStatCard('Stock Faible', '$_lowStockCount', Icons.warning_amber, Colors.red),
                              ],
                            ),
                          ),

                          // Search Bar
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
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

                          // Inventory Table
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
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
                                      separatorBuilder: (_, _) => const Divider(height: 1),
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
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),

                    // Right Panel: Alerts + Movements
                    Expanded(
                      flex: 2,
                      child: Container(
                        color: Colors.white,
                        child: Column(
                          children: [
                            // Low Stock Alerts
                            Container(
                              padding: const EdgeInsets.all(16),
                              color: Colors.red[50],
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
                              height: 200,
                              child: _lowStockAlerts.isEmpty
                                  ? const Center(
                                      child: Text('Aucune alerte', style: TextStyle(color: Colors.green, fontSize: 16)),
                                    )
                                  : ListView.separated(
                                      padding: const EdgeInsets.all(8),
                                      itemCount: _lowStockAlerts.length,
                                      separatorBuilder: (_, _) => const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final alert = _lowStockAlerts[index];
                                        final name = alert['product_variants']?['products']?['name'] ?? 'Inconnu';
                                        final size = alert['product_variants']?['size'] ?? '-';
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

                            const Divider(height: 1),

                            // Recent Movements
                            Container(
                              padding: const EdgeInsets.all(16),
                              color: Colors.indigo[50],
                              child: const Row(
                                children: [
                                  Icon(Icons.swap_vert, color: Colors.indigo),
                                  SizedBox(width: 8),
                                  Text(
                                    'Derniers Mouvements (Entrée / Sortie)',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: _recentMovements.isEmpty
                                  ? const Center(child: Text('Aucun mouvement', style: TextStyle(color: Colors.grey)))
                                  : ListView.separated(
                                      padding: const EdgeInsets.all(8),
                                      itemCount: _recentMovements.length,
                                      separatorBuilder: (_, _) => const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final mov = _recentMovements[index];
                                        final isIn = mov['type'] == 'in';
                                        final productName = mov['product_variants']?['products']?['name'] ?? 'Inconnu';
                                        final size = mov['product_variants']?['size'] ?? '-';
                                        final userName = mov['user_profiles']?['full_name'] ?? 'Inconnu';
                                        final date = DateTime.tryParse(mov['created_at'] ?? '');
                                        final qty = mov['quantity'] ?? 0;
                                        final total = mov['total_price'] ?? 0;

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
                                            '${isIn ? "Entrée" : "Sortie"} × $qty • $userName • ${date != null ? timeago.format(date, locale: 'fr') : ''}',
                                            style: const TextStyle(fontSize: 11),
                                          ),
                                          trailing: Text(
                                            '${(total as num).toStringAsFixed(2)} €',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isIn ? Colors.blue : Colors.green,
                                              fontSize: 13,
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
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
          border: Border(bottom: BorderSide(color: color, width: 3)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
