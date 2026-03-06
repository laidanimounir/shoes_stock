import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CartItem {
  final String variantId;
  final String productName;
  final String size;
  final String color;
  int quantity;
  double unitPrice;

  CartItem({
    required this.variantId,
    required this.productName,
    required this.size,
    required this.color,
    required this.quantity,
    required this.unitPrice,
  });

  double get totalPrice => quantity * unitPrice;
}

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _searchController = TextEditingController();
  
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  
  final List<CartItem> _cart = [];
  
  String? _selectedStoreId;
  String? _storeName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // Fetch employee's assigned store
        final profile = await Supabase.instance.client
            .from('user_profiles')
            .select('store_id')
            .eq('id', user.id)
            .single();
        
        _selectedStoreId = profile['store_id'];

        // Fetch store name for display
        if (_selectedStoreId != null) {
          final storeRes = await Supabase.instance.client
              .from('stores')
              .select('name')
              .eq('id', _selectedStoreId!)
              .maybeSingle();
          _storeName = storeRes?['name'] ?? 'Inconnu';
        }
        
        if (mounted) {
          setState(() => _isLoading = false);
        }
        
        // Load products
        _searchProduct('');
      }
    } catch (e) {
      debugPrint("Error fetching initial data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _searchProduct(String query) async {
    setState(() => _isSearching = true);

    try {
      var queryBuilder = Supabase.instance.client
          .from('product_variants')
          .select('''
            id, size, color, barcode,
            products!inner(name, image_url),
            inventory(quantity, store_id)
          ''');

      if (query.isNotEmpty) {
        queryBuilder = queryBuilder.or('barcode.ilike.%$query%,products.name.ilike.%$query%');
      }

      final response = await queryBuilder.limit(20);

      if (mounted) {
        setState(() {
          _searchResults = response;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
      debugPrint("Search error: $e");
    }
  }

  void _addToCart(dynamic variantData) {
    if (_selectedStoreId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Veuillez sélectionner un magasin."),
        backgroundColor: Colors.red,
      ));
      return;
    }

    // Check inventory for the selected store
    final inventoryList = variantData['inventory'] as List<dynamic>? ?? [];
    int availability = 0;
    for (var inv in inventoryList) {
      if (inv['store_id'] == _selectedStoreId) {
        availability += (inv['quantity'] as int?) ?? 0;
      }
    }
    
    if (availability <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Attention: Stock épuisé pour ce magasin."),
        backgroundColor: Colors.orange,
      ));
    }

    final variantId = variantData['id'];
    final existIndex = _cart.indexWhere((item) => item.variantId == variantId);

    if (existIndex >= 0) {
      setState(() {
        _cart[existIndex].quantity++;
      });
    } else {
      setState(() {
        _cart.add(CartItem(
          variantId: variantId,
          productName: variantData['products']['name'],
          size: variantData['size'],
          color: variantData['color'],
          quantity: 1,
          unitPrice: 0.0,
        ));
      });
    }
    _searchController.clear();
    _searchProduct('');
  }

  void _updateCartItem(int index, int qty, double price) {
    setState(() {
      _cart[index].quantity = qty;
      _cart[index].unitPrice = price;
    });
  }

  Future<void> _processPayment() async {
    if (_cart.isEmpty) return;
    if (_selectedStoreId == null) return;
    
    // Validate prices
    for (var item in _cart) {
      if (item.unitPrice <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Veuillez saisir un prix unitaire pour chaque article."),
          backgroundColor: Colors.red,
        ));
        return;
      }
    }

    setState(() => _isLoading = true);
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final invoiceNumber = 'INV-${DateTime.now().millisecondsSinceEpoch}';

      for (var item in _cart) {
        await Supabase.instance.client.from('transactions').insert({
          'invoice_number': invoiceNumber,
          'type': 'out',
          'variant_id': item.variantId,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'total_price': item.totalPrice,
          'store_id': _selectedStoreId,
          'user_id': user!.id,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Vente enregistrée avec succès."),
          backgroundColor: Colors.green,
        ));
        setState(() {
          _cart.clear();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Erreur de paiement: $e"),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  double get _cartTotal => _cart.fold(0, (sum, item) => sum + item.totalPrice);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[50],
      appBar: AppBar(
        title: const Text('Point de Vente (POS)'),
        backgroundColor: Colors.indigo[800],
        foregroundColor: Colors.white,
        actions: [
          // Show employee's assigned store name
          if (_storeName != null)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warehouse, color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  Text(_storeName!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Row(
            children: [
              // Left Panel (Search & Products)
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Search Bar
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(fontSize: 18),
                          decoration: const InputDecoration(
                            hintText: 'Rechercher un produit ou scanner un code-barres...',
                            prefixIcon: Icon(Icons.search, size: 28),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(20),
                          ),
                          onChanged: _searchProduct,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Results Grid
                      Expanded(
                        child: _isSearching
                            ? const Center(child: CircularProgressIndicator())
                            : _searchResults.isEmpty
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
                                : GridView.builder(
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      childAspectRatio: 0.8,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                    ),
                                    itemCount: _searchResults.length,
                                    itemBuilder: (context, index) {
                                      final item = _searchResults[index];
                                      final imageUrl = item['products']['image_url'];
                                      
                                      return Card(
                                        clipBehavior: Clip.antiAlias,
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        child: InkWell(
                                          onTap: () => _addToCart(item),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              Expanded(
                                                child: Container(
                                                  color: Colors.grey[200],
                                                  child: imageUrl != null 
                                                    ? Image.network(imageUrl, fit: BoxFit.cover)
                                                    : const Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.all(12),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      item['products']['name'],
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text('Taille: ${item['size']} | Couleur: ${item['color']}', style: const TextStyle(color: Colors.black54)),
                                                    Text('Code: ${item['barcode'] ?? 'N/A'}', style: const TextStyle(color: Colors.indigo, fontSize: 12)),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                color: Colors.indigo[50],
                                                padding: const EdgeInsets.symmetric(vertical: 8),
                                                child: const Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.add_shopping_cart, color: Colors.indigo, size: 18),
                                                    SizedBox(width: 8),
                                                    Text("Ajouter", style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
                                                  ],
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
                ),
              ),
              
              // Right Panel (Cart)
              Expanded(
                flex: 2,
                child: Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        color: Colors.indigo[50],
                        child: Row(
                          children: [
                            const Icon(Icons.shopping_cart, color: Colors.indigo, size: 28),
                            const SizedBox(width: 12),
                            const Text("Panier", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo)),
                            const Spacer(),
                            Chip(
                              label: Text('${_cart.length}'), 
                              backgroundColor: Colors.indigo,
                              labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            )
                          ],
                        ),
                      ),
                      Expanded(
                        child: _cart.isEmpty
                          ? const Center(child: Text("Le panier est vide", style: TextStyle(color: Colors.grey, fontSize: 16)))
                          : ListView.separated(
                              itemCount: _cart.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = _cart[index];
                                return Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                            Text('${item.size} - ${item.color}', style: const TextStyle(color: Colors.grey)),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                const Text("Qté: ", style: TextStyle(fontWeight: FontWeight.bold)),
                                                SizedBox(
                                                  width: 50,
                                                  child: TextFormField(
                                                    initialValue: item.quantity.toString(),
                                                    keyboardType: TextInputType.number,
                                                    textAlign: TextAlign.center,
                                                    onChanged: (val) {
                                                      final q = int.tryParse(val) ?? 1;
                                                      _updateCartItem(index, q, item.unitPrice);
                                                    },
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                const Text("Prix U: ", style: TextStyle(fontWeight: FontWeight.bold)),
                                                SizedBox(
                                                  width: 70,
                                                  child: TextFormField(
                                                    initialValue: item.unitPrice > 0 ? item.unitPrice.toString() : '',
                                                    keyboardType: TextInputType.number,
                                                    textAlign: TextAlign.center,
                                                    decoration: const InputDecoration(hintText: '0.00'),
                                                    onChanged: (val) {
                                                      final p = double.tryParse(val) ?? 0.0;
                                                      _updateCartItem(index, item.quantity, p);
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.close, color: Colors.red),
                                            onPressed: () => setState(() => _cart.removeAt(index)),
                                          ),
                                          const SizedBox(height: 8),
                                          Text('${item.totalPrice.toStringAsFixed(2)} €', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                        ],
                                      )
                                    ],
                                  ),
                                );
                              },
                            ),
                      ),
                      
                      // Payment Section
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Total à payer", style: TextStyle(fontSize: 20, color: Colors.grey)),
                                Text('${_cartTotal.toStringAsFixed(2)} €', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.indigo)),
                              ],
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 60,
                              child: ElevatedButton(
                                onPressed: _cart.isEmpty ? null : _processPayment,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.payments_outlined, size: 28),
                                    SizedBox(width: 12),
                                    Text("Payer", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
    );
  }
}
