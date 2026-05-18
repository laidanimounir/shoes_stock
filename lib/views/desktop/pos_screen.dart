import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:isar/isar.dart';
import 'dart:async';
import '../../core/app_session.dart';
import '../../core/app_strings.dart';
import '../../core/connectivity_service.dart';
import '../../core/sync_engine.dart';
import '../../local_db/isar_service.dart';
import '../../local_db/collections/product_local.dart';
import '../../local_db/collections/product_variant_local.dart';
import '../../local_db/collections/inventory_local.dart';
import '../../local_db/collections/invoice_local.dart';
import '../../local_db/collections/customer_local.dart';
import '../../local_db/collections/store_local.dart';
import '../../services/invoice_service.dart';

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
  
  List<dynamic> _customers = [];
  String? _selectedCustomerId; 

  bool _isLoading = true;
  bool _isProcessingPayment = false;

  /// FIX 2: Tracks cart indices with stock conflicts during payment check.
  Set<int> _stockConflictItems = {};

  /// Cached balance of the selected client (null = not fetched yet).
  double? _selectedCustomerBalance;

  StreamSubscription<List<Map<String, dynamic>>>? _inventorySubscription;

  // FIX 3: Rebuild today-sales tab after sync completes
  StreamSubscription<void>? _syncCompleteSubscription;
  // Key used to force-rebuild the FutureBuilder in today-sales tab
  UniqueKey _todaySalesKey = UniqueKey();

  String _barcodeBuffer = '';
  DateTime? _lastKeyPress;

  // ── FIX 5: Online/offline + date/time state ──
  bool _isOnline = true;
  String _currentDateTimeStr = '';
  Timer? _dateTimer;

  // ── FIX 3: Low-stock pulse animation ──
  bool _pulseVisible = true;
  Timer? _pulseTimer;

  // ── FIX 4: Cached stock per variant in cart ──
  final Map<String, int> _cachedStock = {};

  /// Index of the cart item currently in direct-qty-edit mode, or null.
  int? _editingQtyIndex;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _fetchInitialData();

    // FIX 3: Listen for sync completions → rebuild today-sales tab
    _syncCompleteSubscription =
        SyncEngine.instance.onSyncComplete.listen((_) {
      if (mounted) {
        setState(() => _todaySalesKey = UniqueKey());
      }
    });

    // ── FIX 5: Listen to connectivity changes ──
    _isOnline = ConnectivityService.instance.isOnline;
    AppSession.isOfflineMode = !_isOnline;
    ConnectivityService.instance.onConnectivityChanged.listen((online) {
      if (mounted) {
        setState(() {
          _isOnline = online;
          AppSession.isOfflineMode = !online;
        });
      }
    });

    // ── FIX 5: Update date/time every 30 seconds ──
    _updateDateTimeStr();
    _dateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updateDateTimeStr();
      if (mounted) setState(() {});
    });

    // ── FIX 3: Pulse timer for low-stock indicator ──
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (mounted) {
        setState(() => _pulseVisible = !_pulseVisible);
      }
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _inventorySubscription?.cancel();
    _syncCompleteSubscription?.cancel();
    _dateTimer?.cancel();
    _pulseTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _updateDateTimeStr() {
    final now = DateTime.now();
    final locale = S.currentLocale;
    if (locale == 'fr') {
      final daysFr = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
      final monthsFr = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun', 'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
      _currentDateTimeStr =
          '${daysFr[now.weekday - 1]} ${now.day} ${monthsFr[now.month - 1]} ${now.year} — '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    } else {
      final daysAr = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
      final monthsAr = ['جانفي', 'فيفري', 'مارس', 'أفريل', 'ماي', 'جوان', 'جويلية', 'أوت', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
      _currentDateTimeStr =
          '${daysAr[now.weekday - 1]} ${now.day} ${monthsAr[now.month - 1]} ${now.year} — '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    }
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_barcodeBuffer.isNotEmpty) {
          _searchController.text = _barcodeBuffer;
          _searchProduct(_barcodeBuffer);
          _barcodeBuffer = '';
        }
      } else if (event.character != null) {
        final now = DateTime.now();
        if (_lastKeyPress != null && now.difference(_lastKeyPress!).inMilliseconds > 50) {
          _barcodeBuffer = '';
        }
        _barcodeBuffer += event.character!;
        _lastKeyPress = now;
      }
    }
    return false;
  }

  Future<void> _fetchInitialData() async {
    if (AppSession.isOfflineMode) {
      final isar = await IsarService.getInstance();
      
      _selectedStoreId = AppSession.currentStoreId;
      if (_selectedStoreId != null) {
        final store = await isar.storeLocals
            .filter()
            .supabaseIdEqualTo(_selectedStoreId!)
            .findFirst();
        _storeName = store?.name ?? S.t('misc_unknown');
      }

      final customers = await isar.customerLocals
          .filter()
          .isActiveEqualTo(true)
          .findAll();
      _customers = customers.map((c) => {'id': c.supabaseId, 'full_name': c.fullName}).toList();

      if (mounted) {
        setState(() => _isLoading = false);
      }
      _searchProduct('');
      return;
    }

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final profile = await Supabase.instance.client
            .from('user_profiles')
            .select('store_id')
            .eq('id', user.id)
            .single();
        
        _selectedStoreId = profile['store_id'];

        if (_selectedStoreId != null) {
          final storeRes = await Supabase.instance.client
              .from('stores')
              .select('name')
              .eq('id', _selectedStoreId!)
              .maybeSingle();
          _storeName = storeRes?['name'] ?? S.t('misc_unknown');
        }

      
        final customersRes = await Supabase.instance.client
            .from('customers')
            .select('id, full_name')
            .eq('is_active', true)
            .order('full_name');
            
        _customers = customersRes;
        
        if (mounted) {
          setState(() => _isLoading = false);
        }
        
        _searchProduct('');
      }
    } catch (e) {
      debugPrint("Error fetching initial data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setupInventoryStream() {
    if (_selectedStoreId == null) return;
    
    _inventorySubscription?.cancel();
    _inventorySubscription = Supabase.instance.client
        .from('inventory')
        .stream(primaryKey: ['id'])
        .eq('store_id', _selectedStoreId!)
        .listen((inventoryData) {
          if (!mounted) return;
          
          setState(() {
            for (var searchResult in _searchResults) {
              final variantId = searchResult['id'];
              final invItem = inventoryData.firstWhere(
                (inv) => inv['variant_id'] == variantId && inv['store_id'] == _selectedStoreId,
                orElse: () => {},
              );
              
              if (invItem.isNotEmpty) {
                final invList = searchResult['inventory'] as List<dynamic>? ?? [];
                final existingInvIndex = invList.indexWhere((i) => i['store_id'] == _selectedStoreId);
                
                if (existingInvIndex >= 0) {
                  invList[existingInvIndex]['quantity'] = invItem['quantity'];
                } else {
                  invList.add({'store_id': _selectedStoreId, 'quantity': invItem['quantity']});
                  searchResult['inventory'] = invList;
                }
              }
            }
          });
        });
  }

  Future<void> _searchProduct(String query) async {
    setState(() => _isSearching = true);

    if (AppSession.isOfflineMode) {
      final isar = await IsarService.getInstance();
      
      final variants = await isar.productVariantLocals
          .filter()
          .isActiveEqualTo(true)
          .findAll();
          
      final products = await isar.productLocals.where().findAll();
      final inventory = await isar.inventoryLocals.where().findAll();

      final productMap = {for (var p in products) p.supabaseId: p};

      final results = variants.where((v) {
        final p = productMap[v.productId];
        if (p == null) return false;
        if (query.isEmpty) return true;
        
        final q = query.toLowerCase();
        return (v.barcode?.toLowerCase().contains(q) ?? false) || 
               p.name.toLowerCase().contains(q);
      }).map((v) {
        final p = productMap[v.productId]!;
        final invs = inventory
            .where((inv) => inv.variantId == v.supabaseId)
            .map((inv) => {
                  'quantity': inv.quantity,
                  'store_id': inv.storeId,
                }).toList();

        return {
          'id': v.supabaseId,
          'size': v.size,
          'color': v.color,
          'barcode': v.barcode,
          'sell_price': v.sellPrice,
          'products': {
            'name': p.name,
            'image_url': p.imageUrl,
          },
          'inventory': invs,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _searchResults = results.take(20).toList();
          _isSearching = false;
        });
      }
      return;
    }

    try {
      var queryBuilder = Supabase.instance.client
          .from('product_variants')
          .select('''
            id, size, color, barcode, sell_price,
            products!inner(name, image_url),
            inventory(quantity, store_id)
          ''').eq('is_active', true); // المنتجات غير المحذوفة فقط

      if (query.isNotEmpty) {
        queryBuilder = queryBuilder.or('barcode.ilike.%$query%,products.name.ilike.%$query%');
      }

      final response = await queryBuilder.limit(20);

      if (mounted) {
        setState(() {
          _searchResults = response;
          _isSearching = false;
        });
        
        if (_inventorySubscription == null) {
          _setupInventoryStream();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
      debugPrint("Search error: $e");
    }
  }

  void _addToCart(dynamic variantData) {
    if (_selectedStoreId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(S.t('pos_select_store_first')),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final inventoryList = variantData['inventory'] as List<dynamic>? ?? [];
    int availability = 0;
    for (var inv in inventoryList) {
      if (inv['store_id'] == _selectedStoreId) {
        availability += (inv['quantity'] as int?) ?? 0;
      }
    }

    // ── FIX 1: Block add when stock = 0 ──
    if (availability <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(S.t('pos_stock_empty_warning')),
        backgroundColor: Colors.orange,
      ));
      return; // ⬅ was missing — item was added despite stock = 0
    }

    final variantId = variantData['id'];

    // ── FIX 1: Block add when alreadyInCart >= available stock ──
    final alreadyInCart = _cart
        .where((i) => i.variantId == variantId)
        .fold(0, (int sum, CartItem i) => sum + i.quantity);
    if (alreadyInCart >= availability) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('${S.t('pos_stock_insufficient')} $availability ${S.t('pos_stock_available')}'),
        backgroundColor: Colors.red,
      ));
      return;
    }

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
          unitPrice: double.tryParse(variantData['sell_price']?.toString() ?? '0') ?? 0.0,
        ));
      });
      // Warm the stock cache for the new item
      _getCurrentStock(variantId).then((s) {
        if (mounted) setState(() => _cachedStock[variantId] = s);
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

  double get _cartTotal => _cart.fold(0, (sum, item) => sum + item.totalPrice);

  /// Returns the current stock quantity for a variant in the selected store.
  Future<int> _getCurrentStock(String variantId) async {
    if (AppSession.isOfflineMode) {
      final isar = await IsarService.getInstance();
      final inv = await isar.inventoryLocals
          .filter()
          .variantIdEqualTo(variantId)
          .and()
          .storeIdEqualTo(_selectedStoreId!)
          .findFirst();
      return inv?.quantity ?? 0;
    }
    try {
      final result = await Supabase.instance.client
          .from('inventory')
          .select('quantity')
          .eq('variant_id', variantId)
          .eq('store_id', _selectedStoreId!)
          .maybeSingle();
      return (result?['quantity'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Resolves stock for a search-result item entry in the current store.
  int _getStockForItem(Map<String, dynamic> item) {
    final invList = (item['inventory'] as List<dynamic>?) ?? [];
    for (final inv in invList) {
      if (inv['store_id'] == _selectedStoreId) {
        return (inv['quantity'] as int?) ?? 0;
      }
    }
    return 0;
  }

  /// Fetches and caches the selected client's balance.
  Future<void> _cacheCustomerBalance(String customerId) async {
    if (AppSession.isOfflineMode) {
      final isar = await IsarService.getInstance();
      final c = await isar.customerLocals
          .filter()
          .supabaseIdEqualTo(customerId)
          .findFirst();
      _selectedCustomerBalance = c?.balance ?? 0;
    } else {
      try {
        final res = await Supabase.instance.client
            .from('customers')
            .select('balance')
            .eq('id', customerId)
            .single();
        _selectedCustomerBalance = (res['balance'] as num?)?.toDouble() ?? 0;
      } catch (_) {
        _selectedCustomerBalance = 0;
      }
    }
  }

  /// Caches the available stock for all items currently in the cart.
  Future<void> _cacheCartStock() async {
    for (final item in _cart) {
      if (!_cachedStock.containsKey(item.variantId)) {
        _cachedStock[item.variantId] = await _getCurrentStock(item.variantId);
      }
    }
  }

  void _showPaymentDialog() {
    if (_cart.isEmpty) return;
    
    for (var item in _cart) {
      if (item.unitPrice <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(S.t('pos_invalid_price')),
          backgroundColor: Colors.red,
        ));
        return;
      }
    }

    final totalAmount = _cartTotal;
    final isRegisteredClient = _selectedCustomerId != null;

    // ── FIX 3: Payment method state ──
    String selectedMethod = 'cash'; // 'cash' | 'credit' | 'mixed'
    final cashController = TextEditingController(text: totalAmount.toStringAsFixed(2));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final bool canUseCredit = isRegisteredClient;
            final double cashAmount = selectedMethod == 'mixed'
                ? (double.tryParse(cashController.text) ?? 0)
                : (selectedMethod == 'cash'
                    ? (double.tryParse(cashController.text) ?? totalAmount)
                    : 0);
            final double creditAmount = selectedMethod == 'mixed'
                ? (totalAmount - cashAmount).clamp(0, totalAmount)
                : (selectedMethod == 'credit' ? totalAmount : 0);

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.point_of_sale, color: Colors.indigo),
                  const SizedBox(width: 8),
                  Text(S.t('pos_cashout_title')),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Total banner ──
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.indigo[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(S.t('pos_total_to_pay_lbl'),
                            style: const TextStyle(fontSize: 18)),
                        Text(
                          '${totalAmount.toStringAsFixed(2)} ${S.t('misc_currency')}',
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── FIX 3: Payment method segmented control ──
                  Text(S.t('pos_payment_method'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  ToggleButtons(
                    isSelected: [
                      selectedMethod == 'cash',
                      selectedMethod == 'credit' && canUseCredit,
                      selectedMethod == 'mixed' && canUseCredit,
                    ],
                    onPressed: (index) {
                      setDialogState(() {
                        if (index == 0) {
                          selectedMethod = 'cash';
                        } else if (index == 1 && canUseCredit) {
                          selectedMethod = 'credit';
                        } else if (index == 2 && canUseCredit) {
                          selectedMethod = 'mixed';
                          cashController.text = totalAmount.toStringAsFixed(2);
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(6),
                    constraints: const BoxConstraints(minHeight: 38, minWidth: 80),
                    textStyle: const TextStyle(fontSize: 13),
                    selectedColor: Colors.indigo,
                    fillColor: Colors.indigo[50],
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(S.t('pos_cash')),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Opacity(
                          opacity: canUseCredit ? 1.0 : 0.4,
                          child: Text(S.t('pos_credit')),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Opacity(
                          opacity: canUseCredit ? 1.0 : 0.4,
                          child: Text(S.t('pos_mixed')),
                        ),
                      ),
                    ],
                  ),
                  if (!canUseCredit)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(S.t('pos_credit_client_only'),
                          style: const TextStyle(
                              color: Colors.orange, fontSize: 11)),
                    ),
                  const SizedBox(height: 16),

                  // ── Amount fields based on method ──
                  if (selectedMethod == 'cash')
                    TextFormField(
                      controller: cashController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText:
                            '${S.t('pos_amount_received')} (${S.t('misc_currency')})',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.payments),
                        isDense: true,
                      ),
                    ),
                  if (selectedMethod == 'credit')
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(S.t('pos_credit_note'),
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  if (selectedMethod == 'mixed')
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: cashController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText:
                                '${S.t('pos_cash_amount')} (${S.t('misc_currency')})',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.money),
                            isDense: true,
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text('${S.t('pos_credit_amount')}: ',
                                style: const TextStyle(fontSize: 13)),
                            Text(
                              '${creditAmount.toStringAsFixed(2)} ${S.t('misc_currency')}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.orange[700]),
                            ),
                          ],
                        ),
                      ],
                    ),

                  // ── FIX 3: Client balance warning (amber left border) ──
                  if (isRegisteredClient &&
                      _selectedCustomerBalance != null &&
                      selectedMethod != 'cash')
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: const Border(
                            left: BorderSide(color: Colors.amber, width: 4)),
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${S.t('pos_client_balance_current')} ${_selectedCustomerBalance!.toStringAsFixed(2)} ${S.t('misc_currency')}',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _selectedCustomerBalance! > 0
                                    ? Colors.amber[900]
                                    : null),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${S.t('pos_balance_new_warning')} ${(_selectedCustomerBalance! + creditAmount).toStringAsFixed(2)} ${S.t('misc_currency')}',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _selectedCustomerBalance! > 0
                                    ? Colors.red[700]
                                    : Colors.amber[900]),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(S.t('action_cancel'),
                      style: const TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // ── FIX 2: Re-verify stock before processing ──
                    final conflicts = <int>{};
                    for (int i = 0; i < _cart.length; i++) {
                      final currentStock =
                          await _getCurrentStock(_cart[i].variantId);
                      if (currentStock < _cart[i].quantity) {
                        conflicts.add(i);
                      }
                    }
                      if (conflicts.isNotEmpty) {
                        setState(() => _stockConflictItems = conflicts);
                        Navigator.pop(context);
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '${S.t('pos_stock_changed_title')}: ${S.t('pos_stock_changed_msg')}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    child: Text(S.t('pos_confirm_payment')),
                  ),

              ],
            );
        },
        );
      },
    );
  }

  // ── FIX 4: Quantity control widget for cart items ──
  Widget buildQtyControls(CartItem item, int index) {
    final int stockLimit = _cachedStock[item.variantId] ?? 999;
    final bool isMin = item.quantity <= 1;
    final bool isMax = item.quantity >= stockLimit;
    final bool isEditing = _editingQtyIndex == index;
    final qtyController = TextEditingController(
      text: item.quantity.toString(),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 32,
          height: 32,
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(Icons.remove, size: 18,
                color: isMin ? Colors.grey[300] : Colors.black54),
            onPressed: isMin
                ? null
                : () {
                    setState(() {
                      item.quantity--;
                      _editingQtyIndex = null;
                    });
                  },
          ),
        ),
        isEditing
            ? SizedBox(
                width: 40,
                height: 32,
                child: TextField(
                  controller: qtyController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (val) {
                    final q = int.tryParse(val) ?? 1;
                    setState(() {
                      item.quantity = q.clamp(1, stockLimit);
                      _editingQtyIndex = null;
                    });
                  },
                  onTapOutside: (_) {
                    setState(() => _editingQtyIndex = null);
                  },
                ),
              )
            : GestureDetector(
                onTap: () => setState(() => _editingQtyIndex = index),
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${item.quantity}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
        const SizedBox(width: 2),
        SizedBox(
          width: 32,
          height: 32,
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(Icons.add, size: 18,
                color: isMax ? Colors.grey[300] : Colors.black54),
            onPressed: isMax
                ? null
                : () {
                    setState(() {
                      item.quantity++;
                      _editingQtyIndex = null;
                    });
                  },
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBar() {
    final pending = AppSession.pendingSync;
    return Container(
      height: 28,
      color: Colors.blueGrey[50],
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Left: connectivity indicator
          Icon(
            _isOnline ? Icons.cloud_done : Icons.cloud_off,
            size: 14,
            color: _isOnline ? Colors.green[700] : Colors.red[700],
          ),
          const SizedBox(width: 6),
          Text(
            _isOnline ? S.t('pos_online_status') : S.t('pos_offline_status'),
            style: TextStyle(fontSize: 11, color: _isOnline ? Colors.green[700] : Colors.red[700]),
          ),
          if (!_isOnline && pending > 0) ...[
            const SizedBox(width: 4),
            Text(
              '— $pending ${S.t('pos_pending_ops')}',
              style: TextStyle(fontSize: 11, color: Colors.orange[700]),
            ),
          ],
          const Spacer(),
          // Right: date/time
          Text(
            _currentDateTimeStr,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.blueGrey[50],
        appBar: AppBar(
          title: Text(S.t('pos_title')),
          backgroundColor: Colors.indigo[800],
          foregroundColor: Colors.white,
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: const Icon(Icons.point_of_sale), text: S.t('pos_new_sale')),
              Tab(icon: const Icon(Icons.receipt_long), text: S.t('pos_today_invoices')),
            ],
          ),
          actions: [
            if (_storeName != null)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
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
        body: Column(
          children: [
            _buildStatusBar(),
            const Divider(height: 1, color: Colors.black12),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                                    ),
                                    child: TextField(
                                      controller: _searchController,
                                      style: const TextStyle(fontSize: 18),
                                      decoration: InputDecoration(
                                        hintText: S.t('pos_search_hint'),
                                        prefixIcon: const Icon(Icons.search, size: 28),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.all(20),
                                      ),
                                      onChanged: _searchProduct,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Expanded(
                              child: _isSearching
                                  ? const Center(child: CircularProgressIndicator())
                                  : _searchResults.isEmpty
                                      ? Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey),
                                              const SizedBox(height: 16),
                                              Text(S.t('pos_no_products'), style: const TextStyle(fontSize: 20, color: Colors.grey)),
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
                                            final item = _searchResults[index] as Map<String, dynamic>;
                                            final imageUrl = item['products']['image_url'];
                                            // ── FIX 1: Resolve stock for visual state ──
                                            final stock = _getStockForItem(item);
                                            final isOutOfStock = stock <= 0;
                                            final isLowStock = stock > 0 && stock <= 3;
                                            // ── FIX 1: Resolve price ──
                                            final sellPrice =
                                                double.tryParse(item['sell_price']?.toString() ?? '0') ?? 0.0;
                                            final colorRaw = item['color'] as String? ?? '';
                                            final hasArrivage =
                                                RegExp(r'\[Arrivage\s+\d+\s*•\s*\d{2}/\d{2}/\d{4}\]')
                                                    .hasMatch(colorRaw);
                                            
                                            return Card(
                                              clipBehavior: Clip.antiAlias,
                                              elevation: 2,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              child: InkWell(
                                                onTap: isOutOfStock ? null : () => _addToCart(item),
                                                child: Opacity(
                                                  opacity: isOutOfStock ? 0.35 : 1.0,
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                                    children: [
                                                      Expanded(
                                                        child: Stack(
                                                          children: [
                                                            Container(
                                                              color: Colors.grey[200],
                                                              child: imageUrl != null 
                                                                  ? Image.network(imageUrl, fit: BoxFit.cover)
                                                                  : const Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                                                            ),
                                                            // ── Stock badge ──
                                                            Positioned(
                                                              top: 8,
                                                              right: 8,
                                                              child: Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                                decoration: BoxDecoration(
                                                                  color: isOutOfStock
                                                                      ? Colors.red
                                                                      : isLowStock
                                                                          ? Colors.orange
                                                                          : Colors.green,
                                                                  borderRadius: BorderRadius.circular(4),
                                                                ),
                                                                child: Row(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: [
                                                                    // ── FIX 3: Low-stock pulsing dot ──
                                                                    if (isLowStock)
                                                                      AnimatedOpacity(
                                                                        opacity: _pulseVisible ? 1.0 : 0.2,
                                                                        duration: const Duration(milliseconds: 400),
                                                                        child: Container(
                                                                          width: 6,
                                                                          height: 6,
                                                                          margin: const EdgeInsets.only(right: 4),
                                                                          decoration: const BoxDecoration(
                                                                            color: Colors.white,
                                                                            shape: BoxShape.circle,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    Text(
                                                                      isOutOfStock
                                                                          ? S.t('pos_out_of_stock')
                                                                          : stock.toString(),
                                                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                            // ── FIX 6: "RUPTURE" watermark overlay ──
                                                            if (isOutOfStock)
                                                              Positioned.fill(
                                                                child: Center(
                                                                  child: Transform.rotate(
                                                                    angle: -0.5,
                                                                    child: Text(
                                                                      S.t('pos_out_of_stock').toUpperCase(),
                                                                      style: TextStyle(
                                                                        color: Colors.red.withValues(alpha: 0.12),
                                                                        fontSize: 22,
                                                                        fontWeight: FontWeight.w900,
                                                                        letterSpacing: 4,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                          ],
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
                                                            _buildVariantColorRow(item['color'], item['size']),
                                                            Text('${S.t('pos_code')}: ${item['barcode'] ?? 'N/A'}',
                                                                style: const TextStyle(color: Colors.indigo, fontSize: 12)),
                                                            // ── FIX 1: Price display ──
                                                            const SizedBox(height: 2),
                                                            Row(
                                                              children: [
                                                                Text(
                                                                  '${_formatPrice(sellPrice)} ${S.t('misc_currency')}',
                                                                  style: TextStyle(
                                                                    fontWeight: FontWeight.w500,
                                                                    fontSize: 12,
                                                                    color: isOutOfStock ? Colors.grey : Colors.black87,
                                                                  ),
                                                                ),
                                                                if (hasArrivage && !isOutOfStock) ...[
                                                                  const SizedBox(width: 6),
                                                                  Container(
                                                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                                    decoration: BoxDecoration(
                                                                      color: Colors.grey[200],
                                                                      borderRadius: BorderRadius.circular(3),
                                                                    ),
                                                                    child: Text(
                                                                      S.t('pos_new_price_label'),
                                                                      style: TextStyle(
                                                                        fontSize: 9,
                                                                        color: Colors.grey[600],
                                                                        fontWeight: FontWeight.w500,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      Container(
                                                        color: isOutOfStock ? Colors.red[50] : Colors.indigo[50],
                                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                                        child: Row(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          children: [
                                                            Icon(isOutOfStock ? Icons.block : Icons.add_shopping_cart,
                                                                color: isOutOfStock ? Colors.red : Colors.indigo, size: 18),
                                                            const SizedBox(width: 8),
                                                            Text(isOutOfStock ? S.t('pos_out_of_stock') : S.t('pos_add_btn'),
                                                                style: TextStyle(
                                                                    color: isOutOfStock ? Colors.red : Colors.indigo,
                                                                    fontWeight: FontWeight.bold)),
                                                          ],
                                                        ),
                                                      )
                                                    ],
                                                  ),
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
                                  Text(S.t('pos_cart_title'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo)),
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
                                ? Center(child: Text(S.t('pos_cart_empty'), style: const TextStyle(color: Colors.grey, fontSize: 16)))
                                : ListView.separated(
                                    itemCount: _cart.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final item = _cart[index];
                                      final hasConflict = _stockConflictItems.contains(index);
                                      return Container(
                                        decoration: hasConflict
                                            ? const BoxDecoration(
                                                border: Border(left: BorderSide(color: Colors.red, width: 4)),
                                              )
                                            : null,
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(item.productName,
                                                              style: TextStyle(
                                                                  fontWeight: FontWeight.bold,
                                                                  fontSize: 16,
                                                                  color: hasConflict ? Colors.red : null)),
                                                        ),
                                                        if (hasConflict)
                                                          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                                                      ],
                                                    ),
                                                    Text('${item.size} - ${item.color}',
                                                        style: TextStyle(color: hasConflict ? Colors.red[300] : Colors.grey)),
                                                    const SizedBox(height: 8),
                                                    Row(
                                                      children: [
                                                        Text(S.t('pos_qty_short'),
                                                            style: TextStyle(fontWeight: FontWeight.bold,
                                                                color: hasConflict ? Colors.red : null)),
                                                        const SizedBox(width: 4),
                                                        // FIX 4: +/- quantity controls
                                                        buildQtyControls(item, index),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        Text(S.t('pos_unit_price'),
                                                                style: TextStyle(fontWeight: FontWeight.bold,
                                                                    color: hasConflict ? Colors.red : null)),
                                                            const SizedBox(width: 4),
                                                            SizedBox(
                                                              width: 70,
                                                              child: TextFormField(
                                                                initialValue: item.unitPrice > 0 ? item.unitPrice.toString() : '',
                                                                keyboardType: TextInputType.number,
                                                                textAlign: TextAlign.center,
                                                                decoration: const InputDecoration(
                                                                    contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                                    isDense: true,
                                                                    hintText: '0.00'),
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
                                                  Text('${item.totalPrice.toStringAsFixed(2)} ${S.t('misc_currency')}',
                                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: hasConflict ? Colors.red : null)),
                                                ],
                                              )
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                            ),
                            
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
                              ),
                              child: Column(
                                children: [
                                  DropdownButtonFormField<String?>(
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: S.t('pos_client_optional'),
                                      prefixIcon: const Icon(Icons.person_outline, color: Colors.indigo),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    ),
                                    value: _selectedCustomerId,
                                    items: [
                                      DropdownMenuItem(
                                        value: null,
                                        child: Text(S.t('pos_walkin_client'), style: const TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                      ..._customers.map((c) => DropdownMenuItem(
                                        value: c['id'] as String,
                                        child: Text(c['full_name'] as String),
                                      )),
                                    ],
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedCustomerId = val;
                                        _selectedCustomerBalance = null;
                                      });
                                      if (val != null) {
                                        _cacheCustomerBalance(val);
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(S.t('pos_total_to_pay'), style: const TextStyle(fontSize: 20, color: Colors.grey)),
                                      Text('${_cartTotal.toStringAsFixed(2)} ${S.t('misc_currency')}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.indigo)),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 60,
                                    child: ElevatedButton(
                                      onPressed: (_cart.isEmpty || _isProcessingPayment) ? null : _showPaymentDialog,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: _isProcessingPayment 
                                        ? const CircularProgressIndicator(color: Colors.white)
                                        : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.payments_outlined, size: 28),
                                            const SizedBox(width: 12),
                                            Text(S.t('pos_pay_btn'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ],
                    ),
                    _buildTodaySalesTab(),
                  ],
                ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(double price) {
    return price.toStringAsFixed(2);
  }

  Widget _buildTodaySalesTab() {
    return Center(
      child: Text(S.t('pos_today_invoices'),
          style: const TextStyle(fontSize: 18, color: Colors.grey)),
    );
  }

  Widget _buildVariantColorRow(String color, String size) {
    final arrMatch = RegExp(r'\s*\[Arrivage\s+\d+\s*•\s*\d{2}/\d{2}/\d{4}\]').firstMatch(color);
    if (arrMatch == null) {
      return Text('${S.t('prod_size')}: $size | ${S.t('prod_color')}: $color',
          style: const TextStyle(color: Colors.black54));
    }
    final baseColor = color.replaceAll(arrMatch.group(0)!, '');
    final arrLabel = arrMatch.group(0)!.trim();
    return Row(
      children: [
        Text('${S.t('prod_size')}: $size | ${S.t('prod_color')}: $baseColor',
            style: const TextStyle(color: Colors.black54)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: const Color(0xFF2ECC71).withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(arrLabel,
              style: TextStyle(fontSize: 9, color: const Color(0xFF2ECC71), fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}