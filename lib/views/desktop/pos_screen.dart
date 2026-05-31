import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:isar/isar.dart';
import 'dart:async';
import 'dart:convert';
import '../../core/app_session.dart';
import '../../local_db/enums/local_enums.dart';
import '../../core/app_strings.dart';
import '../../core/connectivity_service.dart';
import '../../core/sync_engine.dart';
import '../../local_db/isar_service.dart';
import '../../local_db/collections/product_local.dart';
import '../../local_db/collections/product_variant_local.dart';
import '../../local_db/collections/transaction_local.dart';
import '../../local_db/collections/inventory_local.dart';
import '../../local_db/collections/invoice_local.dart';
import '../../local_db/collections/customer_local.dart';
import '../../local_db/collections/store_local.dart';
import '../../services/invoice_service.dart';
import '../../services/refund_service.dart';
import '../../services/receipt_service.dart';
import '../../shared/models/cart_item.dart';

// ─────────────────────────────────────────────
//  DESIGN TOKENS — Odoo-inspired clean palette
// ─────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFFF7F8FC);
  static const surface   = Color(0xFFFFFFFF);
  static const primary   = Color(0xFF1F3A6E);       // deep navy
  static const accent    = Color(0xFF3D5AFE);       // vivid blue
  static const success   = Color(0xFF00B96B);
  static const warning   = Color(0xFFF59E0B);
  static const danger    = Color(0xFFEF4444);
  static const textDark  = Color(0xFF111827);
  static const textMid   = Color(0xFF6B7280);
  static const textLight = Color(0xFFB0B8C8);
  static const border    = Color(0xFFE5E7EB);
  static const rowEven   = Color(0xFFFAFAFC);
  static const rowHover  = Color(0xFFF0F4FF);
  static const chip      = Color(0xFFEEF2FF);
}

// ─────────────────────────────────────────────
//  POS SCREEN
// ─────────────────────────────────────────────
class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> with TickerProviderStateMixin {
  final _searchController        = TextEditingController();
  final _cartSearchController    = TextEditingController();
  final _invoiceSearchController = TextEditingController();

  List<dynamic> _searchResults = [];
  List<dynamic> _bundles = [];
  bool _isSearching  = false;
  bool _isLoading    = true;
  bool _isProcessingPayment = false;
  bool _isLoadingInvoices   = false;

  final List<CartItem> _cart = [];
  String _cartSearchQuery = '';

  String? _selectedStoreId;
  String? _storeName;
  List<dynamic> _customers = [];
  String? _selectedCustomerId;
  double? _selectedCustomerBalance;
  double? _selectedCustomerCreditLimit;
  String? _customerType;
  int _customerPoints = 0;
  bool _isWholesale = false;

  Set<int> _stockConflictItems = {};
  final Map<String, int> _cachedStock = {};
  int? _editingQtyIndex;

  List<Map<String, dynamic>> _allInvoices      = [];
  List<Map<String, dynamic>> _filteredInvoices = [];

  int _invoiceCurrentPage  = 0;
  String _invoiceFilter    = 'all';
  String _invoiceSearchQuery = '';
  Timer? _invoiceSearchDebounce;
  static const int _invoicePageSize = 20;

  int    _discountMode     = 0; // 0=%, 1=DA
  double _discountInput    = 0;
  double _discountAmount   = 0;
  bool   _isDiscountApplied = false;

  bool   _showClearConfirm = false;
  Timer? _clearConfirmTimer;

  bool   _isOnline           = true;
  String _currentDateTimeStr = '';
  Timer? _dateTimer;

  bool   _pulseVisible = true;
  Timer? _pulseTimer;

  StreamSubscription<List<Map<String, dynamic>>>? _inventorySubscription;
  StreamSubscription<void>? _syncCompleteSubscription;

  String    _barcodeBuffer = '';
  DateTime? _lastKeyPress;

  // 0 = Nouvelle Vente, 1 = Factures du Jour
  int _activeTab = 0;

  // ── INIT ──────────────────────────────────────
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);

    _fetchInitialData().then((_) {
      if (mounted && !AppSession.posTicketPreferenceSet) {
        _showPrintPreferenceDialog();
      }
    });

    _syncCompleteSubscription = SyncEngine.instance.onSyncComplete.listen((_) {
      if (mounted) _loadTodayInvoices();
    });

    _isOnline = ConnectivityService.instance.isOnline;
    AppSession.isOfflineMode = !_isOnline;
    ConnectivityService.instance.onConnectivityChanged.listen((online) {
      if (mounted) setState(() { _isOnline = online; AppSession.isOfflineMode = !online; });
    });

    _updateDateTimeStr();
    _dateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updateDateTimeStr();
      if (mounted) setState(() {});
    });

    _pulseTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (mounted) setState(() => _pulseVisible = !_pulseVisible);
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _inventorySubscription?.cancel();
    _syncCompleteSubscription?.cancel();
    _dateTimer?.cancel();
    _pulseTimer?.cancel();
    _clearConfirmTimer?.cancel();
    _invoiceSearchDebounce?.cancel();
    _invoiceSearchController.dispose();
    _cartSearchController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── DATE / TIME ───────────────────────────────
  void _updateDateTimeStr() {
    final now = DateTime.now();
    final locale = S.currentLocale;
    if (locale == 'fr') {
      final days   = ['Lun','Mar','Mer','Jeu','Ven','Sam','Dim'];
      final months = ['Jan','Fév','Mar','Avr','Mai','Jun','Jul','Aoû','Sep','Oct','Nov','Déc'];
      _currentDateTimeStr =
          '${days[now.weekday-1]} ${now.day} ${months[now.month-1]}'
          ' • ${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}';
    } else {
      final days   = ['الإثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت','الأحد'];
      final months = ['جانفي','فيفري','مارس','أفريل','ماي','جوان','جويلية','أوت','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
      _currentDateTimeStr =
          '${days[now.weekday-1]} ${now.day} ${months[now.month-1]}'
          ' • ${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}';
    }
  }

  // ── BARCODE ───────────────────────────────────
  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_barcodeBuffer.isNotEmpty) {
          _searchController.text = _barcodeBuffer;
          _searchProduct(_barcodeBuffer);

          final buffer = _barcodeBuffer;
          _barcodeBuffer = '';
          _onBarcodeScanned(buffer);
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

  void _onBarcodeScanned(String barcode) {
    if (!barcode.startsWith('FAC-')) return;
    _lookupInvoiceByNumber(barcode);
  }

  Future<void> _lookupInvoiceByNumber(String invoiceNumber) async {
    try {
      final data = await Supabase.instance.client
          .from('invoices')
          .select('''
            id, invoice_number, total_amount, paid_amount, status, created_at,
            customers!inner(full_name),
            stores!inner(name)
          ''')
          .eq('invoice_number', invoiceNumber)
          .maybeSingle();

      if (data == null || !mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${S.t('pos_invoice')} $invoiceNumber'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${S.t('label_client')}: ${data['customers']['full_name']}'),
              Text('${S.t('label_store')}: ${data['stores']['name']}'),
              Text('${S.t('label_total')}: ${data['total_amount']} ${S.t('misc_currency')}'),
              Text('${S.t('label_status')}: ${data['status']}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(S.t('action_cancel')),
            ),
            if (data['status'] != 'refunded' && data['status'] != 'partial_refund') ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.replay, size: 18),
                label: Text(S.t('pos_refund_btn')),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showRefundDialog(context, data);
                },
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: Text(S.t('pos_return_resell_btn')),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () {
                  Navigator.pop(ctx);
                  _returnAndResell(context, data);
                },
              ),
            ],
          ],
        ),
      );
    } catch (_) {}
  }

  // ── DATA FETCHING ─────────────────────────────
  Future<void> _fetchInitialData() async {
    if (AppSession.isOfflineMode) {
      final isar = await IsarService.getInstance();
      _selectedStoreId = AppSession.currentStoreId;
      if (_selectedStoreId != null) {
        final store = await isar.storeLocals.filter().supabaseIdEqualTo(_selectedStoreId!).findFirst();
        _storeName = store?.name ?? S.t('misc_unknown');
      }
      final customers = await isar.customerLocals.filter().isActiveEqualTo(true).findAll();
      _customers = customers.map((c) => {'id': c.supabaseId, 'full_name': c.fullName, 'balance': c.balance, 'credit_limit': 0}).toList();
      if (mounted) setState(() => _isLoading = false);
      _searchProduct('');
      _loadTodayInvoices();
      return;
    }

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final profile = await Supabase.instance.client
            .from('user_profiles').select('store_id').eq('id', user.id).single();
        _selectedStoreId = profile['store_id'];

        if (_selectedStoreId != null) {
          final storeRes = await Supabase.instance.client
              .from('stores').select('name').eq('id', _selectedStoreId!).maybeSingle();
          _storeName = storeRes?['name'] ?? S.t('misc_unknown');
        }

        final customersRes = await Supabase.instance.client
            .from('customers').select('id, full_name, balance, credit_limit, loyalty_points, customer_type').eq('is_active', true).order('full_name');
        _customers = customersRes;

        if (mounted) setState(() => _isLoading = false);
        _searchProduct('');
        _loadTodayInvoices();
        _fetchBundles();
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
        .from('inventory').stream(primaryKey: ['id']).eq('store_id', _selectedStoreId!)
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
                final idx = invList.indexWhere((i) => i['store_id'] == _selectedStoreId);
                if (idx >= 0) {
                  invList[idx]['quantity'] = invItem['quantity'];
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
      final variants  = await isar.productVariantLocals.filter().isActiveEqualTo(true).findAll();
      final products  = await isar.productLocals.where().findAll();
      final inventory = await isar.inventoryLocals.where().findAll();
      final productMap = {for (var p in products) p.supabaseId: p};

      final results = variants.where((v) {
        final p = productMap[v.productId];
        if (p == null) return false;
        if (query.isEmpty) return true;
        final q = query.toLowerCase();
        return (v.barcode?.toLowerCase().contains(q) ?? false) || p.name.toLowerCase().contains(q);
      }).where((v) {
        if (_selectedStoreId == null) return true;
        return inventory.any((inv) => inv.variantId == v.supabaseId && inv.storeId == _selectedStoreId);
      }).map((v) {
        final p = productMap[v.productId]!;
        final invs = inventory.where((inv) => inv.variantId == v.supabaseId
            && (_selectedStoreId == null || inv.storeId == _selectedStoreId))
            .map((inv) => {'quantity': inv.quantity, 'store_id': inv.storeId}).toList();
        return {
          'id': v.supabaseId, 'size': v.size, 'color': v.color,
          'barcode': v.barcode, 'sell_price': v.sellPrice,
          'products': {'name': p.name, 'image_url': p.imageUrl},
          'inventory': invs,
        };
      }).toList();

      if (mounted) setState(() { _searchResults = results.take(40).toList(); _isSearching = false; });
      return;
    }

    try {
      var qb = Supabase.instance.client.from('product_variants').select('''
            id, size, color, barcode, sell_price, wholesale_price,
            products!inner(name, image_url, category),
            inventory(quantity, store_id)
          ''').eq('is_active', true);

      if (_selectedStoreId != null) {
        qb = qb.eq('inventory.store_id', _selectedStoreId!);
      }

      if (query.isNotEmpty) {
        qb = qb.or('barcode.ilike.%$query%,products.name.ilike.%$query%');
      }

      final response = await qb.limit(40);
      if (mounted) {
        setState(() { _searchResults = response; _isSearching = false; });
        if (_inventorySubscription == null) _setupInventoryStream();
      }
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
      debugPrint("Search error: $e");
    }
  }

  Future<void> _fetchBundles() async {
    if (_selectedStoreId == null) return;
    try {
      final res = await Supabase.instance.client.rpc('get_store_bundles', params: {
        'p_store_id': _selectedStoreId,
      });
      if (mounted) setState(() => _bundles = List<dynamic>.from(res ?? []));
    } catch (_) {}
  }

  void _addBundleToCart(dynamic bundle) {
    final items = bundle['items'] as List<dynamic>? ?? [];
    if (items.isEmpty) return;
    final price = (bundle['bundle_price'] as num?)?.toDouble() ?? 0;
    final perItemPrice = items.isNotEmpty ? price / items.length : 0.0;
    for (final bi in items) {
      final vid = bi['variant_id'] as String?;
      if (vid == null) continue;
      final qty = (bi['quantity'] as int?) ?? 1;
      for (int i = 0; i < qty; i++) {
        setState(() {
          _cart.add(CartItem(
            variantId: vid,
            productName: bi['product_name'] ?? '',
            size: bi['size'] ?? '',
            color: bi['color'] ?? '',
            quantity: 1,
            unitPrice: perItemPrice,
          ));
        });
      }
    }
    _snack('Pack ${bundle['name']} ajouté au panier', _C.success);
  }

  // ── CART LOGIC ────────────────────────────────
  void _addToCart(dynamic variantData) async {
    if (_selectedStoreId == null) {
      _snack(S.t('pos_select_store_first'), _C.danger);
      return;
    }

    final variantId = variantData['id'];
    final availability = await _getCurrentStock(variantId);

    if (availability <= 0) {
      _snack(S.t('pos_stock_empty_warning'), _C.warning);
      return;
    }

    final alreadyInCart = _cart.where((i) => i.variantId == variantId)
        .fold(0, (int sum, CartItem i) => sum + i.quantity);
    if (alreadyInCart >= availability) {
      _snack('${S.t('pos_stock_insufficient')} $availability ${S.t('pos_stock_available')}', _C.danger);
      return;
    }

    final existIndex = _cart.indexWhere((item) => item.variantId == variantId);
    if (existIndex >= 0) {
      setState(() => _cart[existIndex].quantity++);
    } else {
      final price = _getEffectivePrice(variantData);
      setState(() {
        _cart.add(CartItem(
          variantId:   variantId,
          productName: variantData['products']['name'],
          size:        variantData['size'],
          color:       variantData['color'],
          quantity:    1,
          unitPrice:   price,
        ));
      });
      _cachedStock[variantId] = availability;
    }
    _searchController.clear();
  }

  void _updateCartItem(int index, int qty, double price) {
    setState(() { _cart[index].quantity = qty; _cart[index].unitPrice = price; });
  }

  double get _cartTotal => _cart.fold(0, (sum, item) => sum + item.totalPrice);
  double get _discountedTotal => _cartTotal - _discountAmount;

  List<CartItem> get _filteredCart {
    if (_cartSearchQuery.isEmpty) return _cart;
    final q = _cartSearchQuery.toLowerCase();
    return _cart.where((item) =>
      item.productName.toLowerCase().contains(q) ||
      item.size.toLowerCase().contains(q) ||
      item.color.toLowerCase().contains(q)
    ).toList();
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ));
  }

  double _getEffectivePrice(dynamic variant) {
    if (_isWholesale) {
      final wp = (variant['wholesale_price'] as num?)?.toDouble();
      if (wp != null && wp > 0) return wp;
    }
    return double.tryParse(variant['sell_price']?.toString() ?? '0') ?? 0.0;
  }

  // ── STOCK HELPERS ─────────────────────────────
  Future<int> _getCurrentStock(String variantId) async {
    if (AppSession.isOfflineMode) {
      final isar = await IsarService.getInstance();
      final inv  = await isar.inventoryLocals
          .filter().variantIdEqualTo(variantId).and().storeIdEqualTo(_selectedStoreId!).findFirst();
      return inv?.quantity ?? 0;
    }
    try {
      final result = await Supabase.instance.client
          .from('inventory').select('quantity')
          .eq('variant_id', variantId).eq('store_id', _selectedStoreId!).maybeSingle();
      return (result?['quantity'] as int?) ?? 0;
    } catch (_) { return 0; }
  }

  int _getStockForItem(Map<String, dynamic> item) {
    final invList = (item['inventory'] as List<dynamic>?) ?? [];
    for (final inv in invList) {
      if (inv['store_id'] == _selectedStoreId) return (inv['quantity'] as int?) ?? 0;
    }
    return 0;
  }

  Future<void> _cacheCustomerBalance(String customerId) async {
    if (AppSession.isOfflineMode) {
      final isar = await IsarService.getInstance();
      final c = await isar.customerLocals.filter().supabaseIdEqualTo(customerId).findFirst();
      _selectedCustomerBalance = c?.balance ?? 0;
      _selectedCustomerCreditLimit = 0;
    } else {
      try {
        final res = await Supabase.instance.client
            .from('customers').select('balance, credit_limit').eq('id', customerId).single();
        _selectedCustomerBalance = (res['balance'] as num?)?.toDouble() ?? 0;
        _selectedCustomerCreditLimit = (res['credit_limit'] as num?)?.toDouble() ?? 0;
      } catch (_) { _selectedCustomerBalance = 0; _selectedCustomerCreditLimit = 0; }
    }
  }

  // ── PAYMENT DIALOG ────────────────────────────
  void _showPaymentDialog() {
    if (_cart.isEmpty) return;
    for (var item in _cart) {
      if (item.unitPrice <= 0) {
        _snack(S.t('pos_invalid_price'), _C.danger);
        return;
      }
    }

    final totalAmount = _cartTotal;
    final isRegisteredClient = _selectedCustomerId != null;
    String selectedMethod = 'cash';
    String numpadValue    = totalAmount.toStringAsFixed(2);

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final bool canUseCredit = isRegisteredClient;
          final double cashAmount = selectedMethod == 'cash'
              ? (double.tryParse(numpadValue) ?? totalAmount)
              : (selectedMethod == 'mixed' ? (double.tryParse(numpadValue) ?? 0) : 0);
          final double creditAmount = selectedMethod == 'mixed'
              ? (totalAmount - cashAmount).clamp(0, totalAmount)
              : (selectedMethod == 'credit' ? totalAmount : 0);
          final double change = selectedMethod != 'credit' && cashAmount >= totalAmount
              ? cashAmount - totalAmount : 0;
          final bool isInsufficient =
              selectedMethod != 'credit' && cashAmount > 0 && cashAmount < totalAmount;

          Future<void> handleConfirm() async {
            if (isRegisteredClient && selectedMethod != 'cash' &&
                _selectedCustomerCreditLimit != null && _selectedCustomerCreditLimit! > 0) {
              final newDebt = _selectedCustomerBalance! + creditAmount;
              if (newDebt > _selectedCustomerCreditLimit!) {
                _snack(S.t('pos_credit_limit_exceeded')
                    .replaceAll('{balance}', _selectedCustomerBalance!.toStringAsFixed(2))
                    .replaceAll('{limit}', _selectedCustomerCreditLimit!.toStringAsFixed(2)), _C.danger);
                return;
              }
            }
            final conflicts = <int>{};
            for (int i = 0; i < _cart.length; i++) {
              final currentStock = await _getCurrentStock(_cart[i].variantId);
              if (currentStock < _cart[i].quantity) conflicts.add(i);
            }
            if (conflicts.isNotEmpty) {
              setState(() => _stockConflictItems = conflicts);
              Navigator.pop(context);
              _snack('${S.t('pos_stock_changed_title')}: ${S.t('pos_stock_changed_msg')}', _C.danger);
              return;
            }
            setState(() => _isProcessingPayment = true);
            final paidAmount = selectedMethod == 'cash'
                ? (double.tryParse(numpadValue) ?? totalAmount)
                : (selectedMethod == 'credit' ? 0.0 : (double.tryParse(numpadValue) ?? 0));
            final items = _cart.map((item) => {
              'variant_id': item.variantId, 'quantity': item.quantity,
              'unit_price': item.unitPrice, 'total_price': item.totalPrice,
            }).toList();
            try {
              final invoiceNumber = await _generateInvoiceNumber();
              final DateTime? dueDate = selectedMethod != 'cash'
                  ? DateTime.now().add(const Duration(days: 30))
                  : null;
              await InvoiceService.instance.processSale(
                storeId: _selectedStoreId!, invoiceNumber: invoiceNumber,
                items: items, totalAmount: totalAmount,
                paidAmount: paidAmount, paymentMethod: selectedMethod,
                customerId: _selectedCustomerId,
                discountPercent: _discountMode == 0 ? _discountInput : 0,
                discountAmount: _discountMode == 1 ? _discountAmount : 0,
                dueDate: dueDate,
              );
              if (_isDiscountApplied) _logDiscount(invoiceNumber, items, totalAmount);
              if (_selectedCustomerId != null && paidAmount > 0) {
                try {
                  await Supabase.instance.client.rpc('award_loyalty_points', params: {
                    'p_customer_id': _selectedCustomerId,
                    'p_amount_spent': paidAmount,
                  });
                } catch (_) {}
              }
              setState(() => _isProcessingPayment = false);
              Navigator.pop(context);
              if (mounted) _handlePostSaleAction(invoiceNumber, paidAmount);
            } catch (e) {
              setState(() => _isProcessingPayment = false);
              final msg = e.toString();
              if (msg.contains('CREDIT_LIMIT_EXCEEDED')) {
                final parts = msg.split('|');
                final bal = parts.length > 1 ? parts[1] : '0';
                final lim = parts.length > 2 ? parts[2] : '0';
                _snack(S.t('pos_credit_limit_exceeded').replaceAll('{balance}', bal).replaceAll('{limit}', lim), _C.danger);
              } else {
                _snack('${S.t('pos_error')} $e', _C.danger);
              }
            }
          }

          return Focus(
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
                handleConfirm();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: _C.surface,
            insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 480,
                maxHeight: MediaQuery.of(context).size.height * 0.88,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
                    decoration: const BoxDecoration(
                      color: _C.primary,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                        Text(S.t('pos_cashout_title'),
                            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${totalAmount.toStringAsFixed(2)} ${S.t('misc_currency')}',
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),

                  // Body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(S.t('pos_payment_method'),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                  color: _C.textMid, letterSpacing: 0.6)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _payMethodBtn('cash',   S.t('pos_cash'),   Icons.payments_outlined,     selectedMethod, canUseCredit, setDialogState, () { selectedMethod = 'cash'; numpadValue = totalAmount.toStringAsFixed(2); }),
                              const SizedBox(width: 8),
                              _payMethodBtn('credit', S.t('pos_credit'), Icons.credit_card_outlined,   selectedMethod, canUseCredit, setDialogState, () { selectedMethod = 'credit'; }),
                              const SizedBox(width: 8),
                              _payMethodBtn('mixed',  S.t('pos_mixed'),  Icons.compare_arrows_rounded, selectedMethod, canUseCredit, setDialogState, () { selectedMethod = 'mixed'; numpadValue = totalAmount.toStringAsFixed(2); }),
                            ],
                          ),
                          if (!canUseCredit)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(S.t('pos_credit_client_only'),
                                  style: const TextStyle(color: _C.warning, fontSize: 11)),
                            ),
                          const SizedBox(height: 20),

                          if (selectedMethod == 'cash' || selectedMethod == 'mixed') ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              decoration: BoxDecoration(
                                color: _C.accent.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _C.accent.withOpacity(0.2)),
                              ),
                              child: Column(
                                children: [
                                  Text(S.t('pos_amount_received'),
                                      style: const TextStyle(fontSize: 11, color: _C.textMid)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$numpadValue ${S.t('misc_currency')}',
                                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _C.primary),
                                  ),
                                  if (change > 0) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: _C.success.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${S.t('pos_change_label')} ${change.toStringAsFixed(2)} ${S.t('misc_currency')}',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _C.success),
                                      ),
                                    ),
                                  ],
                                  if (isInsufficient) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: _C.danger.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${S.t('pos_insufficient')} (${(totalAmount - cashAmount).toStringAsFixed(2)} ${S.t('misc_currency')})',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _C.danger),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            PosNumpad(value: numpadValue, onChanged: (v) => setDialogState(() => numpadValue = v)),
                          ],

                          if (selectedMethod == 'credit')
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _C.warning.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _C.warning.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, size: 16, color: _C.warning),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(S.t('pos_credit_note'),
                                      style: const TextStyle(color: _C.warning, fontSize: 12))),
                                ],
                              ),
                            ),

                          if (selectedMethod == 'mixed') ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _C.warning.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(S.t('pos_credit_amount'), style: const TextStyle(fontSize: 13, color: _C.textMid)),
                                  Text('${creditAmount.toStringAsFixed(2)} ${S.t('misc_currency')}',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _C.warning)),
                                ],
                              ),
                            ),
                          ],

                          if (isRegisteredClient && _selectedCustomerBalance != null && selectedMethod != 'cash') ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _C.warning.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _C.warning.withOpacity(0.25)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    const Icon(Icons.account_balance_wallet_outlined, size: 14, color: _C.warning),
                                    const SizedBox(width: 6),
                                    Text(S.t('pos_client_balance_current'),
                                        style: const TextStyle(fontSize: 12, color: _C.textMid)),
                                    const Spacer(),
                                    Text('${_selectedCustomerBalance!.toStringAsFixed(2)} ${S.t('misc_currency')}',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _C.warning)),
                                  ]),
                                  if (_selectedCustomerCreditLimit != null && _selectedCustomerCreditLimit! > 0) ...[
                                    const SizedBox(height: 4),
                                    Row(children: [
                                      Text(S.t('pos_credit_limit'),
                                          style: const TextStyle(fontSize: 12, color: _C.textMid)),
                                      const Spacer(),
                                      Text('${_selectedCustomerCreditLimit!.toStringAsFixed(2)} ${S.t('misc_currency')}',
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _C.accent)),
                                    ]),
                                  ],
                                  const SizedBox(height: 6),
                                  Row(children: [
                                    Text(S.t('pos_balance_new_warning'),
                                        style: const TextStyle(fontSize: 12, color: _C.textMid)),
                                    const Spacer(),
                                    Text(
                                      '${(_selectedCustomerBalance! + creditAmount).toStringAsFixed(2)} ${S.t('misc_currency')}',
                                      style: TextStyle(
                                        fontSize: 13, fontWeight: FontWeight.w700,
                                        color: _selectedCustomerBalance! > 0 ? _C.danger : _C.warning,
                                      ),
                                    ),
                                  ]),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Footer
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: _C.border))),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: _C.border),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(S.t('action_cancel'),
                                style: const TextStyle(color: _C.textMid, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _C.success,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            onPressed: handleConfirm,
                            child: _isProcessingPayment
                                ? const SizedBox(width: 20, height: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(S.t('pos_confirm_payment'),
                                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ),
          );
        },
      ),
    );
  }

  Widget _payMethodBtn(
    String method, String label, IconData icon,
    String selected, bool canUse,
    StateSetter setDialogState, VoidCallback onTap,
  ) {
    final isSelected = selected == method;
    final isDisabled = (method == 'credit' || method == 'mixed') && !canUse;
    return Expanded(
      child: GestureDetector(
        onTap: isDisabled ? null : () => setDialogState(onTap),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? _C.accent : (isDisabled ? _C.bg : _C.surface),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? _C.accent : _C.border),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.white : (isDisabled ? _C.textLight : _C.textMid)),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : (isDisabled ? _C.textLight : _C.textMid),
              )),
            ],
          ),
        ),
      ),
    );
  }

  // ── POST SALE ─────────────────────────────────
  Future<void> _logDiscount(String invoiceNumber, List<Map<String, dynamic>> items, double finalTotal) async {
    final logPayload = {
      'user_id': AppSession.currentUserId, 'action_type': 'REMISE_APPLIQUEE',
      'description': jsonEncode({
        'invoice_number': invoiceNumber,
        'discount_percent': _discountMode == 0 ? _discountInput : null,
        'discount_amount': _discountAmount, 'original_total': _cartTotal, 'final_total': finalTotal,
      }),
    };
    if (AppSession.isOfflineMode) {
      await SyncEngine.instance.enqueue(SyncOperationType.createLogDiscount, logPayload);
    } else {
      try { await Supabase.instance.client.from('activity_logs').insert(logPayload); } catch (_) {}
    }
  }

  void _handlePostSaleAction(String invoiceNumber, double paidAmount) {
    setState(() {
      _cart.clear(); _selectedCustomerId = null; _selectedCustomerBalance = null; _selectedCustomerCreditLimit = null;
      _customerType = null; _customerPoints = 0; _isWholesale = false;
      _stockConflictItems = {}; _cachedStock.clear();
      _isDiscountApplied = false; _discountAmount = 0; _discountInput = 0; _discountMode = 0;
      _cartSearchQuery = ''; _cartSearchController.clear();
    });
    _loadTodayInvoices();

    if (AppSession.autoPrintTicket == true) {
      _snack(S.t('pos_print_auto_msg'), _C.success);
    } else if (AppSession.autoPrintTicket == false) {
      _showPostSaleOverlay(invoiceNumber);
    } else {
      _snack(S.t('pos_sale_success'), _C.success);
    }
  }

  void _showPostSaleOverlay(String invoiceNumber) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        bottom: 16, left: 16, right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: _C.primary,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: _C.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: _C.success, borderRadius: BorderRadius.circular(18)),
                  child: const Icon(Icons.check, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(S.t('pos_sale_success'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                    Text(invoiceNumber, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                  ]),
                ),
                TextButton(
                  onPressed: () { entry.remove(); _snack(S.t('pos_print_auto_msg'), _C.accent); },
                  child: Text(S.t('pos_print_now'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
                TextButton(
                  onPressed: () => entry.remove(),
                  child: Text(S.t('pos_print_ignore'), style: const TextStyle(color: Colors.white60)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 8), () { if (entry.mounted) entry.remove(); });
  }

  // ── QTY CONTROLS ──────────────────────────────
  Widget _buildQtyControls(CartItem item, int cartIndex) {
    final int stockLimit = _cachedStock[item.variantId] ?? 999;
    final bool isMin     = item.quantity <= 1;
    final bool isMax     = item.quantity >= stockLimit;
    final bool isEditing = _editingQtyIndex == cartIndex;
    final qtyController  = TextEditingController(text: item.quantity.toString());

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _qtyBtn(Icons.remove, isMin ? null : () => setState(() { item.quantity--; _editingQtyIndex = null; })),
        const SizedBox(width: 4),
        isEditing
            ? SizedBox(
                width: 40, height: 30,
                child: TextField(
                  controller: qtyController, autofocus: true,
                  keyboardType: TextInputType.number, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _C.textDark),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.zero, isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _C.accent)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _C.accent, width: 1.5)),
                  ),
                  onSubmitted: (val) {
                    final q = int.tryParse(val) ?? 1;
                    setState(() { item.quantity = q.clamp(1, stockLimit); _editingQtyIndex = null; });
                  },
                  onTapOutside: (_) => setState(() => _editingQtyIndex = null),
                ),
              )
            : GestureDetector(
                onTap: () => setState(() => _editingQtyIndex = cartIndex),
                child: Container(
                  width: 40, height: 30, alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _C.chip, borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${item.quantity}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _C.accent)),
                ),
              ),
        const SizedBox(width: 4),
        _qtyBtn(Icons.add, isMax ? null : () => setState(() { item.quantity++; _editingQtyIndex = null; })),
      ],
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: onTap == null ? _C.bg : _C.chip,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: onTap == null ? _C.border : _C.accent.withOpacity(0.3)),
        ),
        child: Icon(icon, size: 14, color: onTap == null ? _C.textLight : _C.accent),
      ),
    );
  }

  // ── MAIN BUILD ────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _C.accent))
                : _activeTab == 0
                    ? _buildSaleTab()
                    : _buildTodaySalesTab(),
          ),
        ],
      ),
    );
  }

  // ── TOP BAR (compact single row) ─────────────
  Widget _buildTopBar() {
    final pending = AppSession.pendingSync;

    return Container(
      color: _C.primary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 50,
          child: Row(
            children: [
              // POS Icon
              const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),

              // Store name chip
              if (_storeName != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.storefront_rounded, color: Colors.white70, size: 13),
                      const SizedBox(width: 5),
                      Text(_storeName!,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),

              const SizedBox(width: 12),

              // Online/offline dot + date (compact)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      color: _isOnline ? _C.success : _C.danger,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _isOnline ? S.t('pos_online_status') : S.t('pos_offline_status'),
                    style: TextStyle(
                        fontSize: 11, color: _isOnline ? _C.success : _C.danger, fontWeight: FontWeight.w600),
                  ),
                  if (!_isOnline && pending > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                          color: _C.warning.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: Text('$pending ops',
                          style: const TextStyle(fontSize: 9, color: _C.warning, fontWeight: FontWeight.w700)),
                    ),
                  ],
                  if (pending > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: _isOnline ? Colors.orange[100] : Colors.red[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$pending ${S.t('pos_pending_ops')}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _isOnline ? Colors.orange[800] : Colors.red[700],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 10),
                  Text(_currentDateTimeStr,
                      style: const TextStyle(fontSize: 11, color: Colors.white60)),
                ],
              ),

              const Spacer(),

              // Print preference toggle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      if (AppSession.autoPrintTicket == true) {
                        AppSession.autoPrintTicket = false;
                      } else {
                        AppSession.autoPrintTicket = true;
                      }
                      AppSession.posTicketPreferenceSet = true;
                    });
                  },
                  icon: Icon(
                    AppSession.autoPrintTicket == true
                        ? Icons.print
                        : Icons.print_disabled,
                    size: 16,
                    color: Colors.white70,
                  ),
                  label: Text(
                    AppSession.autoPrintTicket == true
                        ? S.t('pos_print_auto_short')
                        : S.t('pos_print_manual_short'),
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),

              // Tab switcher — inline buttons
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _topTabBtn(
                      icon: Icons.add_shopping_cart_rounded,
                      label: S.t('pos_new_sale'),
                      isActive: _activeTab == 0,
                      onTap: () => setState(() => _activeTab = 0),
                    ),
                    _topTabBtn(
                      icon: Icons.receipt_long_rounded,
                      label: S.t('pos_today_invoices'),
                      isActive: _activeTab == 1,
                      onTap: () => setState(() => _activeTab = 1),
                      badge: _allInvoices.isNotEmpty ? '${_allInvoices.length}' : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topTabBtn({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    String? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: isActive ? Colors.white : Colors.white60),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? Colors.white : Colors.white60,
                )),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                    color: _C.accent, borderRadius: BorderRadius.circular(10)),
                child: Text(badge, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  SALE TAB
  // ─────────────────────────────────────────────
  Widget _buildSaleTab() {
    return Row(
      children: [
        // ── Left: search + products ──
        Expanded(
          flex: 62,
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: SizedBox(
                  height: 42,
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 13, color: _C.textDark),
                    decoration: InputDecoration(
                      hintText: S.t('pos_search_hint'),
                      hintStyle: const TextStyle(color: _C.textLight, fontSize: 12),
                      prefixIcon: const Icon(Icons.search_rounded, color: _C.textMid, size: 18),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 15, color: _C.textMid),
                              onPressed: () { _searchController.clear(); _searchProduct(''); },
                            )
                          : const Padding(
                              padding: EdgeInsets.all(10),
                              child: Icon(Icons.qr_code_scanner_rounded, color: _C.textLight, size: 16),
                            ),
                      filled: true,
                      fillColor: _C.surface,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _C.border)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _C.border)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _C.accent, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      isDense: true,
                    ),
                    onChanged: _searchProduct,
                  ),
                ),
              ),

              // Bundles carousel
              if (_bundles.isNotEmpty && _searchController.text.isEmpty && !_isSearching)
                SizedBox(
                  height: 90,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                        child: Row(
                          children: [
                            Icon(Icons.inventory_2, size: 14, color: _C.accent),
                            const SizedBox(width: 6),
                            Text('Packs', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _C.textDark)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _bundles.length,
                          itemBuilder: (_, i) {
                            final b = _bundles[i];
                            final price = (b['bundle_price'] as num?)?.toDouble() ?? 0;
                            return GestureDetector(
                              onTap: () => _addBundleToCart(b),
                              child: Container(
                                width: 160,
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _C.chip,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: _C.accent.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(b['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: _C.textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          const Spacer(),
                                          Text('$price ${S.t('misc_currency')}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: _C.accent)),
                                          Text('${(b['items'] as List?)?.length ?? 0} articles', style: TextStyle(fontSize: 10, color: _C.textMid)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 24, height: 24,
                                      decoration: BoxDecoration(color: _C.accent, borderRadius: BorderRadius.circular(6)),
                                      child: const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                                    ),
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
              // Product grid — 4 columns
              Expanded(
                child: _isSearching
                    ? const Center(child: CircularProgressIndicator(color: _C.accent, strokeWidth: 2))
                    : _searchResults.isEmpty && _searchController.text.isNotEmpty
                        ? Center(
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const Icon(Icons.inventory_2_outlined, size: 56, color: _C.border),
                              const SizedBox(height: 12),
                              Text(S.t('pos_no_products'),
                                  style: const TextStyle(fontSize: 14, color: _C.textMid)),
                            ]),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              childAspectRatio: 0.74,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              return _buildProductCard(_searchResults[index] as Map<String, dynamic>);
                            },
                          ),
              ),
            ],
          ),
        ),

        // ── Divider ──
        Container(width: 1, color: _C.border),

        // ── Right: cart ──
        Expanded(flex: 38, child: _buildCartPanel()),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  PRODUCT CARD — Odoo-clean style
  // ─────────────────────────────────────────────
  Widget _buildProductCard(Map<String, dynamic> item) {
    final imageUrl  = item['products']['image_url'] as String?;
    final stock     = _getStockForItem(item);
    final isOut     = stock <= 0;
    final isLow     = stock > 0 && stock <= 3;
    final sellPrice = double.tryParse(item['sell_price']?.toString() ?? '0') ?? 0.0;
    final colorRaw  = item['color'] as String? ?? '';
    final hasArrivage = RegExp(r'\[Arrivage\s+\d+\s*•\s*\d{2}/\d{2}/\d{4}\]').hasMatch(colorRaw);

    return GestureDetector(
      onTap: isOut ? null : () => _addToCart(item),
      child: Container(
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _C.border),
          boxShadow: const [
            BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Image area ──
            Expanded(
              flex: 55,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: const Color(0xFFF3F5F9)),
                    if (imageUrl != null)
                      Image.network(imageUrl, fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const _NoImageWidget())
                    else
                      const _NoImageWidget(),

                    // Out of stock ribbon
                    if (isOut)
                      Container(
                        color: Colors.white.withOpacity(0.75),
                        child: Center(
                          child: Transform.rotate(
                            angle: -0.4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: _C.danger, borderRadius: BorderRadius.circular(4)),
                              child: Text(S.t('pos_out_of_stock').toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontSize: 9,
                                      fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                            ),
                          ),
                        ),
                      ),

                    // Stock badge — bottom right of image
                    Positioned(
                      bottom: 6, right: 6,
                      child: _StockBadge(stock: stock, isOut: isOut, isLow: isLow, pulseVisible: _pulseVisible),
                    ),

                    // NEW arrivage badge
                    if (hasArrivage && !isOut)
                      Positioned(
                        top: 6, left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(color: _C.success, borderRadius: BorderRadius.circular(4)),
                          child: const Text('NEW',
                              style: TextStyle(color: Colors.white, fontSize: 7,
                                  fontWeight: FontWeight.w800, letterSpacing: 0.4)),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Info area ──
            Expanded(
              flex: 45,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      item['products']['name'],
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: _C.textDark),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    // Size · Color
                    Text(
                      '${item['size']} · ${_cleanColor(colorRaw)}',
                      style: const TextStyle(fontSize: 10, color: _C.textMid),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),

                    // Price + Add button — same row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${sellPrice.toStringAsFixed(2)} ${S.t('misc_currency')}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 12,
                              color: isOut ? _C.textLight : _C.accent,
                            ),
                            maxLines: 1,
                          ),
                        ),
                        if (!isOut)
                          GestureDetector(
                            onTap: () => _addToCart(item),
                            child: Container(
                              width: 26, height: 26,
                              decoration: BoxDecoration(
                                color: _C.accent,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                            ),
                          )
                        else
                          Container(
                            width: 26, height: 26,
                            decoration: BoxDecoration(
                              color: _C.bg,
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(color: _C.border),
                            ),
                            child: const Icon(Icons.block_rounded, color: _C.textLight, size: 14),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _cleanColor(String raw) =>
      raw.replaceAll(RegExp(r'\s*\[Arrivage\s+\d+\s*•\s*\d{2}/\d{2}/\d{4}\]'), '').trim();

  // ─────────────────────────────────────────────
  //  CART PANEL — redesigned
  // ─────────────────────────────────────────────
  Widget _buildCartPanel() {
    final displayedCart = _filteredCart;
    final cartIsEmpty   = _cart.isEmpty;

    return Container(
      color: _C.surface,
      child: Column(
        children: [
          // ── Total à payer — always visible at top ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            decoration: BoxDecoration(
              color: _C.primary,
            ),
            child: Row(
              children: [
                const Icon(Icons.shopping_cart_outlined, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Text(S.t('pos_cart_title'),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70)),
                // Item count badge
                if (_cart.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 20, height: 20,
                    decoration: const BoxDecoration(color: _C.accent, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text('${_cart.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                ],
                const Spacer(),
                // Total
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(S.t('pos_total_to_pay'),
                        style: const TextStyle(fontSize: 9, color: Colors.white54, letterSpacing: 0.3)),
                    if (_isDiscountApplied) ...[
                      Text(
                        '${_cartTotal.toStringAsFixed(2)} ${S.t('misc_currency')}',
                        style: const TextStyle(
                          fontSize: 11, color: Colors.white38,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: Colors.white38,
                        ),
                      ),
                    ],
                    Text(
                      '${_discountedTotal.toStringAsFixed(2)} ${S.t('misc_currency')}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Cart search + clear ──
          if (!cartIsEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              color: _C.bg,
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 34,
                      child: TextField(
                        controller: _cartSearchController,
                        style: const TextStyle(fontSize: 12, color: _C.textDark),
                        decoration: InputDecoration(
                          hintText: 'Rechercher dans le panier...',
                          hintStyle: const TextStyle(color: _C.textLight, fontSize: 11),
                          prefixIcon: const Icon(Icons.search_rounded, size: 15, color: _C.textMid),
                          suffixIcon: _cartSearchQuery.isNotEmpty
                              ? GestureDetector(
                                  onTap: () => setState(() { _cartSearchQuery = ''; _cartSearchController.clear(); }),
                                  child: const Icon(Icons.close_rounded, size: 13, color: _C.textMid),
                                )
                              : null,
                          filled: true, fillColor: _C.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _C.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _C.border)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _cartSearchQuery = v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Clear button
                  _showClearConfirm
                      ? _buildClearConfirmRow()
                      : GestureDetector(
                          onTap: () => setState(() {
                            _showClearConfirm = true;
                            _clearConfirmTimer?.cancel();
                            _clearConfirmTimer = Timer(const Duration(seconds: 5), () {
                              if (mounted) setState(() => _showClearConfirm = false);
                            });
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              border: Border.all(color: _C.warning.withOpacity(0.4)),
                              borderRadius: BorderRadius.circular(7),
                              color: _C.warning.withOpacity(0.06),
                            ),
                            child: Text(S.t('pos_cart_clear'),
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _C.warning)),
                          ),
                        ),
                ],
              ),
            ),

          // ── Cart items ──
          Expanded(
            child: cartIsEmpty
                ? Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          color: _C.bg, borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _C.border),
                        ),
                        child: const Icon(Icons.shopping_cart_outlined, size: 32, color: _C.border),
                      ),
                      const SizedBox(height: 12),
                      Text(S.t('pos_cart_empty'),
                          style: const TextStyle(color: _C.textMid, fontSize: 13)),
                    ]),
                  )
                : displayedCart.isEmpty
                    ? const Center(child: Text('Aucun résultat',
                        style: TextStyle(color: _C.textMid, fontSize: 12)))
                    : ListView.separated(
                        itemCount: displayedCart.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: _C.border),
                        itemBuilder: (context, index) {
                          final item = displayedCart[index];
                          // find real index in cart for conflict check
                          final realIndex = _cart.indexOf(item);
                          final hasConflict = _stockConflictItems.contains(realIndex);
                          return _buildCartItemRow(item, realIndex, hasConflict);
                        },
                      ),
          ),

          // ── Footer: client + discount + pay ──
          Container(
            decoration: const BoxDecoration(
              color: _C.surface,
              border: Border(top: BorderSide(color: _C.border)),
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              children: [
                // Client selector — compact
                _buildClientSelector(),
                const SizedBox(height: 10),

                // Discount row
                if (!cartIsEmpty)
                  _isDiscountApplied ? _buildDiscountSummary() : _buildDiscountInput(),

                if (!cartIsEmpty) const SizedBox(height: 12),

                // Pay button — large & prominent
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: (cartIsEmpty || _isProcessingPayment) ? null : _showPaymentDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _C.success,
                      elevation: 0,
                      disabledBackgroundColor: _C.border,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isProcessingPayment
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.payments_outlined, color: Colors.white, size: 20),
                              const SizedBox(width: 10),
                              Text(S.t('pos_pay_btn'),
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                              const SizedBox(width: 10),
                              if (!cartIsEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${_discountedTotal.toStringAsFixed(2)} ${S.t('misc_currency')}',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemRow(CartItem item, int realIndex, bool hasConflict) {
    return Container(
      decoration: hasConflict
          ? const BoxDecoration(border: Border(left: BorderSide(color: _C.danger, width: 3)))
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                              fontWeight: FontWeight.w700, fontSize: 13,
                              color: hasConflict ? _C.danger : _C.textDark),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (hasConflict)
                      const Icon(Icons.warning_amber_rounded, color: _C.danger, size: 15),
                  ],
                ),
                const SizedBox(height: 2),
                Text('${item.size} · ${item.color}',
                    style: const TextStyle(fontSize: 10, color: _C.textMid)),
                const SizedBox(height: 7),
                Row(
                  children: [
                    _buildQtyControls(item, realIndex),
                    const SizedBox(width: 8),
                    // Unit price
                    SizedBox(
                      width: 68, height: 28,
                      child: TextFormField(
                        initialValue: item.unitPrice > 0 ? item.unitPrice.toStringAsFixed(2) : '',
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _C.textDark),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                          isDense: true,
                          hintText: '0.00',
                          hintStyle: const TextStyle(color: _C.textLight, fontSize: 11),
                          filled: true, fillColor: _C.bg,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _C.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _C.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _C.accent, width: 1.5)),
                        ),
                        onChanged: (val) {
                          final p = double.tryParse(val) ?? 0.0;
                          _updateCartItem(realIndex, item.quantity, p);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => setState(() => _cart.remove(item)),
                child: Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: _C.danger.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Icon(Icons.close_rounded, color: _C.danger, size: 13),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${item.totalPrice.toStringAsFixed(2)}',
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 13,
                    color: hasConflict ? _C.danger : _C.textDark),
              ),
              Text(S.t('misc_currency'),
                  style: const TextStyle(fontSize: 9, color: _C.textMid, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Client selector — compact chip style ──────
  Widget _buildClientSelector() {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: _C.bg,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _C.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: _selectedCustomerId,
          icon: const Padding(
            padding: EdgeInsets.only(right: 10),
            child: Icon(Icons.expand_more_rounded, size: 16, color: _C.textMid),
          ),
          style: const TextStyle(fontSize: 12, color: _C.textDark),
          items: [
            DropdownMenuItem(
              value: null,
              child: Row(children: [
                const SizedBox(width: 10),
                const Icon(Icons.person_outline, size: 15, color: _C.textMid),
                const SizedBox(width: 8),
                Text(S.t('pos_walkin_client'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _C.textMid)),
              ]),
            ),
            ..._customers.map((c) {
              final bal = (c['balance'] as num?)?.toDouble() ?? 0;
              final lim = (c['credit_limit'] as num?)?.toDouble() ?? 0;
              final pts = (c['loyalty_points'] as int?) ?? 0;
              final ctype = c['customer_type'] as String? ?? 'retail';
              return DropdownMenuItem(
                value: c['id'] as String,
                child: Row(children: [
                  const SizedBox(width: 10),
                  const Icon(Icons.person_rounded, size: 15, color: _C.accent),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(c['full_name'] as String,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      if (ctype == 'wholesale') ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(3)),
                          child: Text(S.t('pos_customer_type_wholesale'),
                              style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.orange[800])),
                        ),
                      ],
                      if (pts > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(color: Colors.purple[100], borderRadius: BorderRadius.circular(3)),
                          child: Text('$pts pts',
                              style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.purple[800])),
                        ),
                      ],
                    ]),
                    Text('${S.t('pos_customer_balance')} ${bal.toStringAsFixed(0)} ${S.t('misc_currency')}${lim > 0 ? '  ${S.t('pos_customer_credit_limit')} ${lim.toStringAsFixed(0)} ${S.t('misc_currency')}' : ''}',
                        style: TextStyle(fontSize: 9, color: bal > 0 ? _C.warning : _C.textLight)),
                  ]),
                ]),
              );
            }),
          ],
          onChanged: (val) {
            setState(() { _selectedCustomerId = val; _selectedCustomerBalance = null; _selectedCustomerCreditLimit = null; });
            if (val != null) {
              _cacheCustomerBalance(val);
              final c = _customers.firstWhere((c) => c['id'] == val, orElse: () => {});
              final ctype = c['customer_type'] as String? ?? 'retail';
              final pts = (c['loyalty_points'] as int?) ?? 0;
              setState(() { _customerType = ctype; _customerPoints = pts; _isWholesale = ctype == 'wholesale'; });
            } else {
              setState(() { _customerType = null; _customerPoints = 0; _isWholesale = false; });
            }
          },
        ),
      ),
    );
  }

  // ── DISCOUNT ──────────────────────────────────
  Widget _buildDiscountSummary() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _C.success.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _C.success.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_offer_rounded, size: 14, color: _C.success),
          const SizedBox(width: 8),
          Text(
            _discountMode == 0
                ? '-${_discountInput.toStringAsFixed(1)}%'
                : '-${_discountAmount.toStringAsFixed(2)} ${S.t('misc_currency')}',
            style: const TextStyle(fontSize: 12, color: _C.success, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 4),
          Text('remise appliquée', style: const TextStyle(fontSize: 11, color: _C.textMid)),
          const Spacer(),
          Text('-${_discountAmount.toStringAsFixed(2)} ${S.t('misc_currency')}',
              style: const TextStyle(fontSize: 12, color: _C.success, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() { _isDiscountApplied = false; _discountAmount = 0; _discountInput = 0; }),
            child: const Icon(Icons.close_rounded, size: 15, color: _C.danger),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountInput() {
    return Row(
      children: [
        // Mode toggle
        Container(
          height: 34,
          decoration: BoxDecoration(
            color: _C.bg, borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _C.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _discountModeBtn(0, '%'),
              _discountModeBtn(1, S.t('misc_currency')),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 34,
            child: TextField(
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 12, color: _C.textDark),
              decoration: InputDecoration(
                hintText: _discountMode == 0 ? '10' : '500',
                hintStyle: const TextStyle(color: _C.textLight, fontSize: 12),
                filled: true, fillColor: _C.bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _C.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _C.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _C.accent, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _discountInput = double.tryParse(v) ?? 0),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _discountInput <= 0 ? null : () {
            final double effectivePercent;
            if (_discountMode == 0) {
              effectivePercent = _discountInput;
            } else {
              effectivePercent = _cartTotal > 0 ? (_discountInput / _cartTotal) * 100 : 0;
            }
            if (!AppSession.isOwner && effectivePercent > AppSession.maxDiscountPercent) {
              final maxValue = _discountMode == 0
                  ? AppSession.maxDiscountPercent
                  : _cartTotal * (AppSession.maxDiscountPercent / 100);
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(S.t('pos_discount_limit')),
                  content: Text(S.t('pos_discount_exceeds')
                      .replaceAll('{max}', AppSession.maxDiscountPercent.toStringAsFixed(0))),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(S.t('action_cancel')),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _discountInput = _discountMode == 0
                              ? AppSession.maxDiscountPercent
                              : maxValue;
                          _discountAmount = maxValue;
                          _isDiscountApplied = true;
                        });
                        Navigator.pop(ctx);
                      },
                      child: Text(S.t('pos_discount_apply_max')),
                    ),
                  ],
                ),
              );
              return;
            }
            setState(() {
              _discountAmount = _discountMode == 0
                  ? _cartTotal * (_discountInput / 100)
                  : _discountInput;
              if (_discountAmount > _cartTotal) _discountAmount = _cartTotal;
              _isDiscountApplied = true;
            });
          },
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: _discountInput > 0 ? _C.accent : _C.border,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(S.t('pos_discount_apply'),
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: _discountInput > 0 ? Colors.white : _C.textLight)),
          ),
        ),
      ],
    );
  }

  Widget _discountModeBtn(int mode, String label) {
    final isSel = _discountMode == mode;
    return GestureDetector(
      onTap: () => setState(() { _discountMode = mode; _discountInput = 0; }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSel ? _C.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(label, style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: isSel ? Colors.white : _C.textMid)),
      ),
    );
  }

  Widget _buildClearConfirmRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(S.t('pos_cart_clear_confirm'), style: const TextStyle(fontSize: 10, color: _C.danger)),
        GestureDetector(
          onTap: () => setState(() {
            _cart.clear(); _showClearConfirm = false;
            _isDiscountApplied = false; _discountAmount = 0; _discountInput = 0; _discountMode = 0;
          }),
          child: Container(
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: _C.danger, borderRadius: BorderRadius.circular(6)),
            child: Text(S.t('pos_cart_clear_yes'), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ),
        GestureDetector(
          onTap: () => setState(() => _showClearConfirm = false),
          child: Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: _C.bg, borderRadius: BorderRadius.circular(6), border: Border.all(color: _C.border)),
            child: Text(S.t('pos_cart_clear_no'), style: const TextStyle(color: _C.textMid, fontSize: 10)),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  TODAY'S SALES TAB — Odoo-style table
  // ─────────────────────────────────────────────
  Widget _buildTodaySalesTab() {
    final totalPages = _computeTotalPages();

    return Column(
      children: [
        // ── Header bar ──
        Container(
          color: _C.surface,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Column(
            children: [
              // Search
              SizedBox(
                height: 38,
                child: TextField(
                  controller: _invoiceSearchController,
                  style: const TextStyle(fontSize: 13, color: _C.textDark),
                  decoration: InputDecoration(
                    hintText: S.t('pos_inv_search_hint'),
                    hintStyle: const TextStyle(color: _C.textLight, fontSize: 12),
                    prefixIcon: const Icon(Icons.search_rounded, size: 17, color: _C.textMid),
                    suffixIcon: _invoiceSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 14),
                            onPressed: () {
                              _invoiceSearchController.clear();
                              _invoiceSearchQuery = '';
                              setState(() => _applyInvoiceFilters());
                            },
                          )
                        : null,
                    filled: true, fillColor: _C.bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: _C.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: _C.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: _C.accent, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    isDense: true,
                  ),
                  onChanged: (val) {
                    _invoiceSearchQuery = val;
                    _invoiceSearchDebounce?.cancel();
                    _invoiceSearchDebounce = Timer(const Duration(milliseconds: 300), () {
                      if (mounted) setState(() => _applyInvoiceFilters());
                    });
                  },
                ),
              ),

              const SizedBox(height: 10),

              // Filters + total
              Row(
                children: [
                  _filterChip('all',    S.t('pos_inv_filter_all'),    _allInvoices.length),
                  const SizedBox(width: 6),
                  _filterChip('paid',   S.t('pos_inv_filter_paid'),   _allInvoices.where((i) => i['status'] == 'paid').length,    color: _C.success),
                  const SizedBox(width: 6),
                  _filterChip('credit', S.t('pos_inv_filter_credit'), _allInvoices.where((i) => i['status'] == 'partial' || i['status'] == 'unpaid').length, color: _C.warning),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(S.t('pos_today_total'),
                          style: const TextStyle(fontSize: 10, color: _C.textMid)),
                      Text(
                        '${_allInvoices.fold<double>(0, (s, i) => s + ((i['total_amount'] as num?)?.toDouble() ?? 0)).toStringAsFixed(2)} ${S.t('misc_currency')}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _C.textDark),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),

        // ── Table header ──
        Container(
          decoration: const BoxDecoration(
            color: _C.bg,
            border: Border(
              top: BorderSide(color: _C.border),
              bottom: BorderSide(color: _C.border),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
          child: Row(
            children: [
              Expanded(flex: 28, child: _colHeader(S.t('pos_inv_col_num'))),
              Expanded(flex: 20, child: _colHeader(S.t('pos_inv_col_time'), center: true)),
              Expanded(flex: 22, child: _colHeader('Client')),
              Expanded(flex: 18, child: _colHeader(S.t('pos_inv_col_total'), right: true)),
              Expanded(flex: 12, child: _colHeader('Statut', center: true)),
            ],
          ),
        ),

        // ── Table rows ──
        Expanded(
          child: _isLoadingInvoices
              ? const Center(child: CircularProgressIndicator(color: _C.accent, strokeWidth: 2))
              : _filteredInvoices.isEmpty
                  ? Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.receipt_long_outlined, size: 48, color: _C.border),
                        const SizedBox(height: 12),
                        Text(
                          _allInvoices.isEmpty ? S.t('pos_no_today_invoices') : S.t('pos_no_invoice_today'),
                          style: const TextStyle(fontSize: 13, color: _C.textMid),
                        ),
                      ]),
                    )
                  : ListView.builder(
                      itemCount: _getPageInvoices().length,
                      itemBuilder: (context, index) {
                        final inv = _getPageInvoices()[index];
                        return _buildInvoiceTableRow(inv, index);
                      },
                    ),
        ),

        // ── Pagination ──
        if (totalPages > 1) _buildPaginationBar(totalPages),
      ],
    );
  }

  Widget _colHeader(String label, {bool center = false, bool right = false}) {
    return Text(label,
        textAlign: right ? TextAlign.right : (center ? TextAlign.center : TextAlign.left),
        style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: _C.textMid, letterSpacing: 0.3));
  }

  Widget _filterChip(String filter, String label, int count, {Color? color}) {
    final isSelected = _invoiceFilter == filter;
    final c = color ?? _C.accent;
    return GestureDetector(
      onTap: () { _invoiceFilter = filter; setState(() => _applyInvoiceFilters()); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? c.withOpacity(0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? c : _C.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? c : _C.textMid)),
            const SizedBox(width: 5),
            Container(
              width: 17, height: 17,
              decoration: BoxDecoration(
                  color: isSelected ? c : _C.border, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text('$count',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : _C.textMid)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printInvoice(BuildContext ctx, Map<String, dynamic> invoice) async {
    final invoiceId = (invoice['invoice_id'] ?? invoice['id'] ?? '') as String;
    final items = await _fetchInvoiceItems(invoiceId);
    if (items.isEmpty) return;

    final receiptItems = items.map((i) {
      final pv = i['product_variants'] as Map<String, dynamic>?;
      final prod = pv?['products'] as Map<String, dynamic>?;
      return <String, dynamic>{
        'product_name': prod?['name'] ?? '',
        'size': pv?['size'] ?? '',
        'color': pv?['color'] ?? '',
        'quantity': i['quantity'],
        'unit_price': i['unit_price'],
        'total_price': i['total_price'],
      };
    }).toList();

    final total = (invoice['total_amount'] as num?)?.toDouble() ?? 0;
    final paid = (invoice['paid_amount'] as num?)?.toDouble() ?? 0;
    final discount = (invoice['discount'] as num?)?.toDouble() ?? 0;
    final subtotal = total + discount;
    final invNum = invoice['invoice_number'] as String? ?? '';
    final createdAt = invoice['createdAt'] as DateTime? ?? DateTime.now();
    final change = (paid > total ? paid - total : 0).toDouble();

    if (!ctx.mounted) return;
    await ReceiptService.instance.showReceiptBottomSheet(
      ctx,
      storeName: _storeName ?? '',
      invoiceNumber: invNum,
      date: createdAt,
      items: receiptItems,
      subtotal: subtotal,
      discountAmount: discount,
      total: total,
      paid: paid,
      change: change,
    );
  }

  // ── Odoo-style table row ──
  Widget _buildInvoiceTableRow(Map<String, dynamic> inv, int index) {
    final isCredit  = inv['status'] == 'partial' || inv['status'] == 'unpaid';
    final total     = (inv['total_amount'] as num?)?.toDouble() ?? 0;
    final paid      = (inv['paid_amount'] as num?)?.toDouble() ?? 0;
    final remaining = total - paid;
    final createdAt = inv['createdAt'] as DateTime?;
    final invNum    = inv['invoice_number'] as String? ?? '';
    final clientName = _getCustomerName(inv);

    return InkWell(
      onTap: () => _showInvoiceDetail(inv),
      hoverColor: _C.rowHover,
      child: Container(
        decoration: BoxDecoration(
          color: index.isOdd ? _C.rowEven : _C.surface,
          border: const Border(bottom: BorderSide(color: _C.border, width: 0.5)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        child: Row(
          children: [
            // Invoice number
            Expanded(
              flex: 28,
              child: Text(invNum,
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13,
                      color: _C.accent),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            // Time
            Expanded(
              flex: 20,
              child: Text(
                createdAt != null ? _formatInvoiceDateTime(createdAt) : '',
                style: const TextStyle(fontSize: 12, color: _C.textMid),
                textAlign: TextAlign.center,
              ),
            ),
            // Client
            Expanded(
              flex: 22,
              child: Row(
                children: [
                  const Icon(Icons.person_outline, size: 12, color: _C.textLight),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(clientName,
                        style: const TextStyle(fontSize: 12, color: _C.textDark),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            // Amount
            Expanded(
              flex: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${_formatPrice(total)} ${S.t('misc_currency')}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _C.textDark)),
                  if (isCredit && remaining > 0)
                    Text('-${_formatPrice(remaining)} ${S.t('misc_currency')}',
                        style: const TextStyle(fontSize: 10, color: _C.danger, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            // Status + print + refund
            Expanded(
              flex: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isCredit ? _C.warning.withOpacity(0.10) : _C.success.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isCredit ? S.t('pos_inv_credit_status') : S.t('pos_paid'),
                      style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: isCredit ? _C.warning : _C.success),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _printInvoice(context, inv),
                    child: Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(
                        color: _C.bg, borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _C.border),
                      ),
                      child: const Icon(Icons.print_rounded, size: 13, color: _C.textMid),
                    ),
                  ),
                  if (_canRefundInvoice(inv)) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _showRefundDialog(context, inv),
                      child: Container(
                        width: 26, height: 26,
                        decoration: BoxDecoration(
                          color: _C.danger.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _C.danger.withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.replay, size: 13, color: _C.danger),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationBar(int totalPages) {
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: _C.surface,
        border: Border(top: BorderSide(color: _C.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(_pageLabel(totalPages), style: const TextStyle(fontSize: 12, color: _C.textMid)),
          const Spacer(),
          // Page buttons
          ..._buildPageButtons(totalPages),
        ],
      ),
    );
  }

  List<Widget> _buildPageButtons(int totalPages) {
    final buttons = <Widget>[];

    // Prev
    buttons.add(_pageBtn(Icons.chevron_left_rounded,
        _invoiceCurrentPage > 0 ? () => setState(() => _invoiceCurrentPage--) : null));
    buttons.add(const SizedBox(width: 4));

    // Page numbers
    for (int i = 0; i < totalPages && i < 6; i++) {
      final isActive = i == _invoiceCurrentPage;
      buttons.add(GestureDetector(
        onTap: () => setState(() => _invoiceCurrentPage = i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 30, height: 30,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isActive ? _C.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: isActive ? _C.accent : _C.border),
          ),
          alignment: Alignment.center,
          child: Text('${i + 1}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : _C.textMid)),
        ),
      ));
    }

    if (totalPages > 6) {
      buttons.add(const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Text('...', style: TextStyle(color: _C.textMid)),
      ));
    }

    buttons.add(const SizedBox(width: 4));
    // Next
    buttons.add(_pageBtn(Icons.chevron_right_rounded,
        _invoiceCurrentPage < totalPages - 1 ? () => setState(() => _invoiceCurrentPage++) : null));

    return buttons;
  }

  Widget _pageBtn(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: onTap != null ? _C.border : _C.border.withOpacity(0.4)),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: onTap != null ? _C.textMid : _C.textLight),
      ),
    );
  }

  // ── INVOICE DETAIL MODAL ──────────────────────
  Future<void> _showInvoiceDetail(Map<String, dynamic> invoice) async {
    if (!mounted) return;
    final invoiceId = (invoice['invoice_id'] ?? invoice['id'] ?? '') as String;
    final total      = (invoice['total_amount'] as num?)?.toDouble() ?? 0;
    final paid       = (invoice['paid_amount'] as num?)?.toDouble() ?? 0;
    final remaining  = total - paid;
    final isCredit   = invoice['status'] == 'partial' || invoice['status'] == 'unpaid';
    final createdAt  = invoice['createdAt'] as DateTime?;
    final invNum     = invoice['invoice_number'] as String? ?? '';
    final clientName = _getCustomerName(invoice);

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: _C.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 520, maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
                decoration: BoxDecoration(
                  color: isCredit ? _C.warning.withOpacity(0.06) : _C.success.withOpacity(0.06),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  border: const Border(bottom: BorderSide(color: _C.border)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: isCredit ? _C.warning.withOpacity(0.12) : _C.success.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isCredit ? Icons.pending_actions_rounded : Icons.check_circle_rounded,
                        color: isCredit ? _C.warning : _C.success, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(invNum,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _C.textDark)),
                          const SizedBox(height: 2),
                          Text('$clientName  ·  ${createdAt != null ? _formatInvoiceDateTime(createdAt) : ''}',
                              style: const TextStyle(fontSize: 11, color: _C.textMid)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCredit ? _C.warning.withOpacity(0.12) : _C.success.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isCredit ? S.t('pos_inv_credit_status') : S.t('pos_paid'),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: isCredit ? _C.warning : _C.success),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: _C.textMid),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Body
              Flexible(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchInvoiceItems(invoiceId),
                  builder: (ctx, snapshot) {
                    final items     = snapshot.data ?? [];
                    final isLoading = snapshot.connectionState == ConnectionState.waiting;
                    return isLoading
                        ? const Padding(padding: EdgeInsets.all(40),
                            child: Center(child: CircularProgressIndicator(color: _C.accent, strokeWidth: 2)))
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Articles table header
                                if (items.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: const BoxDecoration(
                                      color: _C.bg,
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                                      border: Border(
                                        top: BorderSide(color: _C.border),
                                        left: BorderSide(color: _C.border),
                                        right: BorderSide(color: _C.border),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(child: Text(S.t('pos_inv_articles'),
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                                color: _C.textMid, letterSpacing: 0.3))),
                                        Text('Qté', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _C.textMid)),
                                        const SizedBox(width: 20),
                                        Text('Total', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _C.textMid)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: _C.border),
                                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                                    ),
                                    child: Column(
                                      children: items.asMap().entries.map((entry) {
                                        return Column(children: [
                                          if (entry.key > 0) const Divider(height: 1, color: _C.border),
                                          _buildDetailItemRow(entry.value),
                                        ]);
                                      }).toList(),
                                    ),
                                  ),
                                ] else
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                        color: _C.bg, borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: _C.border)),
                                    child: Row(children: [
                                      const Icon(Icons.info_outline, size: 14, color: _C.textLight),
                                      const SizedBox(width: 8),
                                      Text(S.t('pos_inv_no_items'),
                                          style: const TextStyle(fontSize: 12, color: _C.textMid)),
                                    ]),
                                  ),
                                const SizedBox(height: 16),

                                // Totals
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                      color: _C.bg, borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: _C.border)),
                                  child: Column(
                                    children: [
                                      _detailAmountRow(S.t('label_total'), _formatPrice(total), _C.textDark, false),
                                      const Divider(height: 12, color: _C.border),
                                      _detailAmountRow(S.t('pos_inv_paid_label'), _formatPrice(paid), _C.success, false),
                                      if (remaining > 0) ...[
                                        const Divider(height: 12, color: _C.border),
                                        _detailAmountRow(S.t('pos_inv_remaining_label'), _formatPrice(remaining), _C.danger, true),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Meta
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                      border: Border.all(color: _C.border),
                                      borderRadius: BorderRadius.circular(10)),
                                  child: Column(
                                    children: [
                                      _buildDetailInfoRow(S.t('pos_inv_mode'), _getPaymentMethod(invoice)),
                                      const SizedBox(height: 8),
                                      _buildDetailInfoRow(S.t('pos_inv_seller'), _getSellerName(invoice)),
                                      if (invoice['due_date'] != null) ...[
                                        const SizedBox(height: 8),
                                        _buildDetailInfoRow('Échéance', invoice['due_date'].toString()),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                  },
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: _C.border))),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _printInvoice(context, invoice);
                          },
                          icon: const Icon(Icons.print_rounded, size: 15),
                          label: Text(S.t('pos_inv_reprint'), style: const TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _C.accent,
                            side: const BorderSide(color: _C.accent),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(S.t('action_close'), style: const TextStyle(color: _C.textMid)),
                        ),
                      ],
                    ),
                    if (_canRefundInvoice(invoice))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showRefundDialog(ctx, invoice),
                            icon: const Icon(Icons.undo, size: 16, color: Colors.red),
                            label: Text(
                              S.t('pos_refund_btn'),
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
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
    );
  }

  Widget _detailAmountRow(String label, String value, Color valueColor, bool isBold) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: _C.textMid)),
        Text('$value ${S.t('misc_currency')}',
            style: TextStyle(fontSize: 14,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                color: valueColor)),
      ],
    );
  }

  Widget _buildDetailItemRow(Map<String, dynamic> item) {
    final qty        = item['quantity'] as int? ?? 0;
    final totalPrice = (item['total_price'] as num?)?.toDouble() ?? 0;
    final unitPrice  = (item['unit_price'] as num?)?.toDouble() ?? 0;
    final variant    = item['product_variants'] as Map<String, dynamic>?;
    final product    = variant?['products'] as Map<String, dynamic>?;
    final prodName   = product?['name'] as String? ?? '';
    final size       = variant?['size'] as String? ?? '';
    final color      = variant?['color'] as String? ?? '';
    final label      = prodName + (size.isNotEmpty ? ' · $size' : '') + (color.isNotEmpty ? ' · $color' : '');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _C.textDark),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('${_formatPrice(unitPrice)} ${S.t('misc_currency')} × $qty',
                    style: const TextStyle(fontSize: 11, color: _C.textMid)),
              ],
            ),
          ),
          Text('${_formatPrice(totalPrice)} ${S.t('misc_currency')}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _C.textDark)),
        ],
      ),
    );
  }

  Widget _buildDetailInfoRow(String label, String value) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: _C.textMid)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _C.textDark)),
      ],
    );
  }

  // ── REFUND ────────────────────────────────────
  bool _canRefundInvoice(Map<String, dynamic> invoice) {
    final status = invoice['status'] as String? ?? '';
    if (status == 'refunded' || status == 'partial_refund') return false;
    final createdAt = invoice['createdAt'] as DateTime?;
    if (createdAt == null) return false;
    final now = DateTime.now();
    return createdAt.year == now.year &&
        createdAt.month == now.month &&
        createdAt.day == now.day;
  }

  Future<void> _showRefundDialog(
      BuildContext parentCtx, Map<String, dynamic> invoice) async {
    final invoiceId = (invoice['invoice_id'] ?? invoice['id'] ?? '') as String;
    if (!RefundService.isValidUuid(invoiceId)) {
      _snack('Cette facture n\'est pas encore synchronisée. Veuillez patienter.', _C.danger);
      return;
    }
    final reasonController = TextEditingController();
    bool isProcessing = false;

    final items = await _fetchInvoiceItems(invoiceId);
    if (items.isEmpty || !mounted) return;

    final selectedItems = <int, bool>{};
    for (int i = 0; i < items.length; i++) {
      selectedItems[i] = true;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setRefundState) {
          double refundTotal = 0;
          final refundItems = <Map<String, dynamic>>[];
          for (int i = 0; i < items.length; i++) {
            if (selectedItems[i] == true) {
              final item = items[i];
              final qty = (item['quantity'] as int?) ?? 0;
              final price = (item['unit_price'] as num?)?.toDouble() ?? 0;
              refundTotal += qty * price;
              final variant = item['product_variants'] as Map<String, dynamic>?;
              refundItems.add({
                'variant_id': variant != null ? variant['id'] ?? '' : '',
                'quantity': qty,
                'unit_price': price,
              });
            }
          }

          return AlertDialog(
            title: Text(S.t('pos_refund_title')),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 460,
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        border: const Border(
                          left: BorderSide(color: Colors.red, width: 3),
                        ),
                      ),
                      child: Text(
                        S.t('pos_refund_warning'),
                        style: TextStyle(fontSize: 12, color: Colors.red[800]),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      S.t('pos_refund_select_items'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    ...items.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      final variant =
                          item['product_variants'] as Map<String, dynamic>?;
                      final product =
                          variant?['products'] as Map<String, dynamic>?;
                      final name = product?['name'] as String? ?? '';
                      final size = variant?['size'] as String? ?? '';
                      final qty = (item['quantity'] as int?) ?? 0;
                      final price =
                          (item['unit_price'] as num?)?.toDouble() ?? 0;
                      return CheckboxListTile(
                        dense: true,
                        value: selectedItems[i] ?? false,
                        onChanged: (val) =>
                            setRefundState(() => selectedItems[i] = val ?? false),
                        title: Text('$name $size',
                            style: const TextStyle(fontSize: 13)),
                        subtitle: Text(
                          'x$qty — ${price.toStringAsFixed(2)} ${S.t('misc_currency')}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      );
                    }),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(S.t('pos_refund_total'),
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          '${refundTotal.toStringAsFixed(2)} ${S.t('misc_currency')}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: S.t('pos_refund_reason'),
                        hintText: S.t('pos_refund_reason_hint'),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.all(10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isProcessing ? null : () => Navigator.pop(ctx),
                child: Text(S.t('action_cancel'),
                    style: const TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: (isProcessing || refundItems.isEmpty)
                    ? null
                    : () async {
                        setRefundState(() => isProcessing = true);
                        try {
                          await RefundService.instance.processRefund(
                            invoiceId: invoiceId,
                            items: refundItems,
                            refundAmount: refundTotal,
                            reason: reasonController.text.trim(),
                            storeId: _selectedStoreId!,
                          );
                          if (mounted) {
                            Navigator.pop(ctx);
                            Navigator.pop(parentCtx);
                            _loadTodayInvoices();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(S.t('pos_refund_success')),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setRefundState(() => isProcessing = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${S.t('pos_error')} $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(S.t('pos_refund_confirm')),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _returnAndResell(
      BuildContext ctx, Map<String, dynamic> invoice) async {
    final invoiceId = (invoice['invoice_id'] ?? invoice['id'] ?? '') as String;
    if (!RefundService.isValidUuid(invoiceId)) {
      _snack('Cette facture n\'est pas encore synchronisée. Veuillez patienter.', _C.danger);
      return;
    }
    final items = await _fetchInvoiceItems(invoiceId);
    if (items.isEmpty) return;

    final refundItems = items.map((i) => <String, dynamic>{
      'variant_id': i['product_variants']['id'],
      'quantity': i['quantity'],
      'unit_price': i['unit_price'],
      'total_price': i['total_price'],
    }).toList();

    final refundTotal = refundItems.fold<double>(0, (s, i) => s + (i['total_price'] as num).toDouble());

    try {
      await RefundService.instance.processRefund(
        invoiceId: invoiceId,
        items: refundItems,
        refundAmount: refundTotal.abs(),
        reason: 'Retour + Revente',
        storeId: _selectedStoreId!,
      );
      for (final item in items) {
        final variant = item['product_variants'] as Map<String, dynamic>?;
        if (variant == null) continue;
        final qty = (item['quantity'] as int?) ?? 0;
        for (var i = 0; i < qty; i++) {
          _addToCart(variant);
        }
      }
      if (mounted) {
        _loadTodayInvoices();
        _snack('Retour + Revente effectué', _C.success);
      }
    } catch (e) {
      if (mounted) _snack('${S.t('pos_error')} $e', _C.danger);
    }
  }

  // ── PRINT PREFERENCE ─────────────────────────
  void _showPrintPreferenceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(color: _C.chip, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.print_rounded, size: 28, color: _C.accent),
              ),
              const SizedBox(height: 16),
              Text(S.t('pos_print_title'),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _C.textDark)),
              const SizedBox(height: 8),
              Text(S.t('pos_print_ask'),
                  style: const TextStyle(fontSize: 13, color: _C.textMid), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () { AppSession.autoPrintTicket = false; AppSession.posTicketPreferenceSet = true; Navigator.pop(ctx); },
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: const BorderSide(color: _C.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      child: Text(S.t('pos_print_manual'), style: const TextStyle(fontSize: 13, color: _C.textMid, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () { AppSession.autoPrintTicket = true; AppSession.posTicketPreferenceSet = true; Navigator.pop(ctx); },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _C.accent, elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      child: Text(S.t('pos_print_always'),
                          style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── DATA HELPERS ──────────────────────────────
  String _formatPrice(double price) => price.toStringAsFixed(2);

  Future<String> _generateInvoiceNumber() async {
    final now  = DateTime.now();
    final date = '${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}';
    if (AppSession.isOfflineMode || _selectedStoreId == null) {
      final isar = await IsarService.getInstance();
      final count = await isar.invoiceLocals.where().count();
      return 'FAC-$date-LOCAL-${(count + 1).toString().padLeft(4,'0')}';
    }
    try {
      final result = await Supabase.instance.client
          .rpc('get_next_invoice_number', params: {'p_store_id': _selectedStoreId});
      return result as String;
    } catch (_) {
      final isar = await IsarService.getInstance();
      final count = await isar.invoiceLocals.where().count();
      return 'FAC-$date-LOCAL-${(count + 1).toString().padLeft(4,'0')}';
    }
  }

  Future<void> _loadTodayInvoices() async {
    if (_selectedStoreId == null) return;
    if (mounted) setState(() => _isLoadingInvoices = true);

    final now        = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay   = startOfDay.add(const Duration(days: 1));

    try {
      if (AppSession.isOfflineMode) {
        final isar = await IsarService.getInstance();
        final localInvoices = await isar.invoiceLocals
            .filter().storeIdEqualTo(_selectedStoreId!).and().typeEqualTo('out')
            .and().createdAtGreaterThan(startOfDay).and().createdAtLessThan(endOfDay).findAll();
        final customers = await isar.customerLocals.where().findAll();
        final customerMap = {for (var c in customers) c.supabaseId: c.fullName};
        _allInvoices = localInvoices.reversed.map((inv) => <String, dynamic>{
          'id': inv.supabaseId.isEmpty ? 'local_${inv.isarId}' : inv.supabaseId,
          'invoice_number': inv.invoiceNumber, 'total_amount': inv.totalAmount,
          'paid_amount': inv.paidAmount, 'status': inv.status,
          'createdAt': inv.createdAt, 'customer_name': customerMap[inv.customerId] ?? '', 'user_name': '',
          'due_date': inv.dueDate?.toIso8601String().substring(0, 10),
        }).toList();
      } else {
        final response = await Supabase.instance.client
            .from('invoices').select('''
              id, invoice_number, total_amount, paid_amount, status, created_at, due_date,
              customers!left (full_name),
              user_profiles!left (full_name)
            ''')
            .eq('store_id', _selectedStoreId!).eq('type', 'out')
            .gte('created_at', startOfDay.toIso8601String())
            .lt('created_at', endOfDay.toIso8601String())
            .order('created_at', ascending: false);

        _allInvoices = (response as List<dynamic>).map((inv) {
          final map = Map<String, dynamic>.from(inv as Map);
          map['createdAt'] = inv['created_at'] != null
              ? DateTime.tryParse(inv['created_at'].toString()) : null;
          return map;
        }).toList();
      }
      _applyInvoiceFilters();
    } catch (e) {
      debugPrint('Error loading today invoices: $e');
    } finally {
      if (mounted) setState(() => _isLoadingInvoices = false);
    }
  }

  void _applyInvoiceFilters() {
    _filteredInvoices = _computeFilteredInvoices();
    _invoiceCurrentPage = 0;
  }

  List<Map<String, dynamic>> _computeFilteredInvoices() {
    var result = _allInvoices.toList();
    if (_invoiceFilter == 'paid') {
      result = result.where((inv) => inv['status'] == 'paid').toList();
    } else if (_invoiceFilter == 'credit') {
      result = result.where((inv) => inv['status'] == 'partial' || inv['status'] == 'unpaid').toList();
    }
    if (_invoiceSearchQuery.isNotEmpty) {
      final q = _invoiceSearchQuery.toLowerCase();
      result = result.where((inv) {
        final num  = (inv['invoice_number'] as String? ?? '').toLowerCase();
        final name = _getCustomerName(inv).toLowerCase();
        return num.contains(q) || name.contains(q);
      }).toList();
    }
    return result;
  }

  String _getCustomerName(Map<String, dynamic> inv) {
    final customers = inv['customers'] as Map<String, dynamic>?;
    if (customers != null && customers['full_name'] != null) return customers['full_name'] as String;
    final customerName = inv['customer_name'] as String?;
    if (customerName != null && customerName.isNotEmpty) return customerName;
    return S.t('pos_walkin_client');
  }

  String _formatInvoiceDateTime(DateTime dt) {
    final day    = dt.day.toString().padLeft(2,'0');
    final month  = dt.month.toString().padLeft(2,'0');
    final hour   = dt.hour.toString().padLeft(2,'0');
    final minute = dt.minute.toString().padLeft(2,'0');
    return '$day/$month $hour:$minute';
  }

  int _computeTotalPages() {
    if (_filteredInvoices.isEmpty) return 1;
    return (_filteredInvoices.length / _invoicePageSize).ceil();
  }

  List<Map<String, dynamic>> _getPageInvoices() {
    final start = _invoiceCurrentPage * _invoicePageSize;
    final end   = (start + _invoicePageSize).clamp(0, _filteredInvoices.length);
    if (start >= _filteredInvoices.length) return [];
    return _filteredInvoices.sublist(start, end);
  }

  String _pageLabel(int total) {
    final raw = S.t('pos_inv_page_of');
    return raw.replaceAll('{current}', '${_invoiceCurrentPage + 1}').replaceAll('{total}', '$total');
  }

  Future<List<Map<String, dynamic>>> _fetchInvoiceItems(String invoiceId) async {
    if (AppSession.isOfflineMode) {
      try {
        final isar = await IsarService.getInstance();
        final txs  = await isar.transactionLocals.filter().invoiceIdEqualTo(invoiceId).findAll();
        return txs.map((tx) => <String, dynamic>{
          'quantity': tx.quantity, 'unit_price': tx.unitPrice,
          'total_price': tx.totalPrice, 'product_variants': null,
        }).toList();
      } catch (_) { return []; }
    }
    try {
      final response = await Supabase.instance.client
          .from('transactions').select('''
            quantity, unit_price, total_price,
            product_variants!left (size, color, products!left (name))
          ''').eq('invoice_id', invoiceId).order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (_) { return []; }
  }

  String _getPaymentMethod(Map<String, dynamic> invoice) {
    final status = invoice['status'] as String? ?? '';
    if (status == 'unpaid') return '-';
    final payments = invoice['payments'] as List<dynamic>?;
    if (payments != null && payments.isNotEmpty) {
      return payments.first['payment_method'] as String? ?? 'cash';
    }
    return S.t('pos_cash');
  }

  String _getSellerName(Map<String, dynamic> invoice) {
    final up = invoice['user_profiles'] as Map<String, dynamic>?;
    return up?['full_name'] as String? ?? '';
  }
}

// ─────────────────────────────────────────────
//  HELPER WIDGETS
// ─────────────────────────────────────────────
class _NoImageWidget extends StatelessWidget {
  const _NoImageWidget();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3F5F9),
      child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.image_not_supported_outlined, size: 24, color: _C.border),
          const SizedBox(height: 3),
          const Text('No image', style: TextStyle(fontSize: 8, color: _C.textLight)),
        ]),
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  final int  stock;
  final bool isOut;
  final bool isLow;
  final bool pulseVisible;
  const _StockBadge({required this.stock, required this.isOut, required this.isLow, required this.pulseVisible});

  @override
  Widget build(BuildContext context) {
    final color = isOut ? _C.danger : isLow ? _C.warning : _C.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
        boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 3, offset: const Offset(0, 1))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLow)
            AnimatedOpacity(
              opacity: pulseVisible ? 1.0 : 0.2,
              duration: const Duration(milliseconds: 400),
              child: Container(
                width: 4, height: 4,
                margin: const EdgeInsets.only(right: 3),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              ),
            ),
          Text(
            isOut ? '0' : '$stock',
            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  NUMPAD WIDGET
// ─────────────────────────────────────────────
class PosNumpad extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const PosNumpad({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _row(['1','2','3']),
        const SizedBox(height: 6),
        _row(['4','5','6']),
        const SizedBox(height: 6),
        _row(['7','8','9']),
        const SizedBox(height: 6),
        _row(['C','0','⌫']),
      ],
    );
  }

  Widget _row(List<String> keys) => Row(
    children: keys.map((k) {
      final isClear = k == 'C';
      final isBack  = k == '⌫';
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _NumpadKey(
            label: k,
            isSpecial: isClear,
            onTap: () {
              if (isBack) {
                onChanged(value.length > 1 ? value.substring(0, value.length - 1) : '0');
              } else if (isClear) {
                onChanged('0');
              } else {
                final clean = value.replaceAll(',', '');
                if (clean == '0') {
                  onChanged(k == '.' ? '0.' : k);
                } else {
                  final appended = '$clean$k';
                  if (appended.replaceAll('.', '').length <= 7) onChanged(appended);
                }
              }
            },
          ),
        ),
      );
    }).toList(),
  );
}

class _NumpadKey extends StatelessWidget {
  final String label;
  final bool isSpecial;
  final VoidCallback onTap;
  const _NumpadKey({required this.label, required this.onTap, this.isSpecial = false});

  @override
  Widget build(BuildContext context) {
    final isBack = label == '⌫';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: isSpecial ? _C.danger.withOpacity(0.07) : _C.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSpecial ? _C.danger.withOpacity(0.25) : _C.border),
        ),
        alignment: Alignment.center,
        child: isBack
            ? const Icon(Icons.backspace_outlined, size: 17, color: _C.textMid)
            : Text(label, style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700,
                color: isSpecial ? _C.danger : _C.textDark,
              )),
      ),
    );
  }
}