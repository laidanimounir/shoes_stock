import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:isar/isar.dart';
import 'dart:async';
import '../../core/app_session.dart';
import '../../core/app_strings.dart';
import '../../local_db/isar_service.dart';
import '../../local_db/collections/product_local.dart';
import '../../local_db/collections/product_variant_local.dart';
import '../../local_db/collections/inventory_local.dart';
import '../../local_db/collections/customer_local.dart';
import '../../local_db/collections/store_local.dart';
import '../../local_db/collections/shift_local.dart';
import '../../services/shift_service.dart';
import '../../models/shift_model.dart';
import 'shift_dialog.dart';
import 'end_of_day_report.dart';
import 'close_shift_screen.dart';
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

  StreamSubscription<List<Map<String, dynamic>>>? _inventorySubscription;

  String _barcodeBuffer = '';
  DateTime? _lastKeyPress;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _fetchInitialData();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _inventorySubscription?.cancel();
    _searchController.dispose();
    super.dispose();
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

        // Check for active shift
        final shiftService = ShiftService();
        final activeShift = await shiftService.getActiveShift(_selectedStoreId!);
        if (activeShift == null) {
          if (mounted) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => ShiftDialog(storeId: _selectedStoreId!),
            );
          }
        } else {
          AppSession.currentShiftId = activeShift.id;
        }
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

          // Check for active shift
          final shiftService = ShiftService();
          final activeShift = await shiftService.getActiveShift(_selectedStoreId!);
          if (activeShift == null) {
            
            // Check for unclosed manual shifts from previous days
            final openShiftsRes = await Supabase.instance.client
                .from('shifts')
                .select()
                .eq('store_id', _selectedStoreId!)
                .eq('status', 'open')
                .order('opened_at', ascending: false)
                .limit(1);

            if (openShiftsRes.isNotEmpty && mounted) {
              final oldShift = ShiftModel.fromJson(openShiftsRes[0]);
              final oldDate = oldShift.openedAt.toLocal();
              final dateStr = "${oldDate.day.toString().padLeft(2, '0')}/${oldDate.month.toString().padLeft(2, '0')}/${oldDate.year}";

              bool handleOldShift = false;
              await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => AlertDialog(
                  title: Text(S.t('shift_previous_unclosed')),
                  content: Text(S.t('shift_previous_unclosed_msg').replaceAll('{date}', dateStr)),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                      },
                      child: Text(S.t('shift_ignore'), style: const TextStyle(color: Colors.grey)),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        handleOldShift = true;
                        Navigator.of(ctx).pop();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                      child: Text(S.t('shift_close_old')),
                    ),
                  ],
                ),
              );

              if (handleOldShift && mounted) {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => CloseShiftScreen(shift: oldShift)),
                );
              }
            }

            if (mounted) {
              await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => ShiftDialog(storeId: _selectedStoreId!),
              );
            }
          } else {
             AppSession.currentShiftId = activeShift.id;
          }
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
    
    if (availability <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(S.t('pos_stock_empty_warning')),
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
          unitPrice: double.tryParse(variantData['sell_price']?.toString() ?? '0') ?? 0.0,
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

  double get _cartTotal => _cart.fold(0, (sum, item) => sum + item.totalPrice);


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
    final paymentController = TextEditingController(text: totalAmount.toStringAsFixed(2));
    final isWalkInCustomer = _selectedCustomerId == null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.indigo[50], borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(S.t('pos_total_to_pay_lbl'), style: const TextStyle(fontSize: 18)),
                    Text('${totalAmount.toStringAsFixed(2)} ${S.t('misc_currency')}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (isWalkInCustomer)
                Text(
                  S.t('pos_walkin_warning'),
                  style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                )
              else
                TextFormField(
                  controller: paymentController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '${S.t('pos_amount_received')} (${S.t('misc_currency')})',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.payments),
                  ),
                ),
              if (!isWalkInCustomer)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    S.t('pos_credit_note'),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(S.t('action_cancel'), style: const TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () {
                double paidAmount = totalAmount;
                if (!isWalkInCustomer) {
                  paidAmount = double.tryParse(paymentController.text) ?? 0;
                }
                Navigator.pop(context);
                _processPayment(totalAmount, paidAmount);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              child: Text(S.t('pos_validate_sale'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }
    );
  }

  
  Future<void> _processPayment(double totalAmount, double paidAmount) async {
    setState(() => _isProcessingPayment = true);
    
    try {
      final invoiceNumber = 'FAC-${DateTime.now().millisecondsSinceEpoch}';

      await InvoiceService.instance.processSale(
        storeId: _selectedStoreId!,
        invoiceNumber: invoiceNumber,
        items: _cart.map((e) => {
          'variant_id': e.variantId,
          'quantity': e.quantity,
          'unit_price': e.unitPrice,
          'total_price': e.totalPrice,
        }).toList(),
        totalAmount: totalAmount,
        paidAmount: paidAmount,
        paymentMethod: 'cash',
        customerId: _selectedCustomerId,
        shiftId: AppSession.currentShiftId,
        notes: 'Paiement à la caisse pour facture $invoiceNumber',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(S.t('pos_sale_success')),
          backgroundColor: Colors.green,
        ));
        setState(() {
          _cart.clear();
          _selectedCustomerId = null; 
          _isProcessingPayment = false;
        });
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() => _isProcessingPayment = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.code == '42501' ? S.t('pos_access_denied') : '${S.t('pos_error')} ${e.message}'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingPayment = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("${S.t('pos_system_error')} $e"),
          backgroundColor: Colors.red,
        ));
      }
    }
  }


  Widget _buildTodaySalesTab() {
    if (_selectedStoreId == null) return Center(child: Text(S.t('pos_no_store_selected')));
    
    final now = DateTime.now();
    final startOfTodayUTC = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(hours: 1)) // convert UTC+1 to UTC
        .toIso8601String();
    final endOfTodayUTC = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(hours: 1))
        .add(const Duration(hours: 24))
        .toIso8601String();

    return FutureBuilder<List<dynamic>>(
      future: Supabase.instance.client
          .from('invoices')
          .select('id, invoice_number, total_amount, paid_amount, status, created_at, customers(full_name)')
          .eq('store_id', _selectedStoreId!)
          .eq('type', 'out')
          .gte('created_at', startOfTodayUTC)
          .lte('created_at', endOfTodayUTC)
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('${S.t('pos_error')} ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }
        
        final sales = snapshot.data ?? [];
        if (sales.isEmpty) {
          return Center(
            child: Text(S.t('pos_no_today_invoices'), style: const TextStyle(fontSize: 18, color: Colors.grey)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: sales.length,
          itemBuilder: (context, index) {
            final sale = sales[index];
            final time = DateTime.parse(sale['created_at']).toLocal();
            final formattedTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
            final customerName = sale['customers']?['full_name'] ?? S.t('pos_walkin_client');
            final total = (sale['total_amount'] as num).toDouble();
            final paid = (sale['paid_amount'] as num).toDouble();
            final bool hasDebt = paid < total;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: hasDebt ? Colors.orange[50] : Colors.green[50],
                  child: Icon(hasDebt ? Icons.pending_actions : Icons.check_circle, color: hasDebt ? Colors.orange : Colors.green),
                ),
                title: Text('${S.t('pos_invoice')} ${sale['invoice_number']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${S.t('pos_client')} $customerName • ${S.t('pos_time')} $formattedTime\n${S.t('pos_status')} ${hasDebt ? S.t('pos_credit_unpaid') : S.t('pos_paid')}'),
                isThreeLine: true,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$total ${S.t('misc_currency')}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    if (hasDebt) Text('${S.t('pos_remaining')} ${total - paid} ${S.t('misc_currency')}', style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            );
          },
        );
      },
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
            TextButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => EndOfDayReport(
                    date: DateTime.now(),
                    shiftId: AppSession.currentShiftId,
                  ),
                );
              },
              icon: const Icon(Icons.assessment, color: Colors.white),
              label: Text(S.t('pos_report_btn'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
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
        body: _isLoading 
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
                                                          Text('${S.t('prod_size')}: ${item['size']} | ${S.t('prod_color')}: ${item['color']}', style: const TextStyle(color: Colors.black54)),
                                                          Text('${S.t('pos_code')}: ${item['barcode'] ?? 'N/A'}', style: const TextStyle(color: Colors.indigo, fontSize: 12)),
                                                        ],
                                                      ),
                                                    ),
                                                    Container(
                                                      color: Colors.indigo[50],
                                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          const Icon(Icons.add_shopping_cart, color: Colors.indigo, size: 18),
                                                          const SizedBox(width: 8),
                                                          Text(S.t('pos_add_btn'), style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
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
                                                  Wrap(
                                                    spacing: 8,
                                                    runSpacing: 8,
                                                    crossAxisAlignment: WrapCrossAlignment.center,
                                                    children: [
                                                      Text(S.t('pos_qty_short'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
                                                      Text(S.t('pos_unit_price'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
                                                Text('${item.totalPrice.toStringAsFixed(2)} ${S.t('misc_currency')}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                              ],
                                            )
                                          ],
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
                                    onChanged: (val) => setState(() => _selectedCustomerId = val),
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
                _buildTodaySalesTab(),
              ],
            ),
      ),
    );
  }
}