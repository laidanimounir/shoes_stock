import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:isar/isar.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/app_session.dart';
import '../../core/app_strings.dart';
import '../../services/report_service.dart';
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
  final List<dynamic> _lowStockAlerts = [];
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

      final List<Map<String, dynamic>> enrichedData = localInventory.map((item) {
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
      }).where((item) => item != null).map((item) => item!).toList().cast<Map<String, dynamic>>();

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
      backgroundColor: Color(0xFF0A0A14),
      appBar: AppBar(
        title: Text(S.t('inv_dashboard_title')),
        backgroundColor: Color(0xFF0F0F1C),
        foregroundColor: Color(0xFFEEEEFF),
        actions: [
          if (_stores.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Color(0xFFEEEEFF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedStoreId,
                  dropdownColor: Color(0xFF0F0F1C),
                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFEEEEFF)),
                  style: const TextStyle(color: Color(0xFFEEEEFF), fontSize: 14, fontWeight: FontWeight.bold),
                  items: _stores.map<DropdownMenuItem<String>>((store) {
                    return DropdownMenuItem<String>(
                      value: store['id'],
                      child: Row(children: [
                        const Icon(Icons.warehouse, color: Color(0xFF9090A8), size: 18),
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
            icon: const Icon(Icons.download),
            tooltip: S.t('action_export'),
            onPressed: _showExportOptions,
          ),
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Imprimer Barcodes',
            onPressed: _filteredInventory.isNotEmpty ? () => _showBulkBarcodeDialog() : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: S.t('action_refresh'),
            onPressed: _fetchInventoryData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stores.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.warehouse_outlined, size: 80, color: Color(0xFF9090A8)),
                      const SizedBox(height: 16),
                      Text(S.t('inv_no_store_msg'), style: const TextStyle(fontSize: 18, color: Color(0xFF9090A8))),
                    ],
                  ),
                )
              : Column(
                  children: [
                    if (AppSession.isEmployee)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        color: Color(0xFFF0A500).withValues(alpha: 0.1),
                        child: Row(
                          children: [
                            const Icon(Icons.visibility, size: 16, color: Color(0xFFF0A500)),
                            const SizedBox(width: 8),
                            Text(S.t('inv_read_only'), style: const TextStyle(color: Color(0xFFF0A500), fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                      ),
                    Expanded(
                      child: AppSession.isEmployee
                          ? _buildEmployeeView()
                          : _buildOwnerView(),
                    ),
                  ],
                ),
              );
  }

  Widget _buildOwnerView() {
    return Row(
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
                    _buildStatCard(S.t('inv_stat_total_products'), '$_totalProducts', Icons.category, Color(0xFF58A6FF)),
                    _buildStatCard(S.t('inv_stat_total_stock'), '$_totalStock ${S.t('inv_units')}', Icons.inventory_2, Color(0xFF4ADE80)),
                    _buildStatCard(S.t('inv_stat_total_value'), '${_totalValue.toStringAsFixed(2)} ${S.t('misc_currency')}', Icons.account_balance_wallet, Color(0xFFF0A500)),
                    _buildStatCard(S.t('inv_stat_low_stock'), '$_lowStockCount', Icons.warning_amber, Color(0xFFF87171)),
                  ],
                ),
              ),

         
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(0xFFEEEEFF),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Color(0xFF0A0A14).withValues(alpha: 0.05), blurRadius: 10)],
                  ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: S.t('inv_search_hint'),
                        prefixIcon: const Icon(Icons.search),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
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
                    color: Color(0xFFEEEEFF),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Color(0xFF0A0A14).withValues(alpha: 0.05), blurRadius: 10)],
                  ),
                  child: _filteredInventory.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.inventory_2_outlined, size: 64, color: Color(0xFF9090A8)),
                              const SizedBox(height: 12),
                              Text(S.t('inv_no_products'), style: const TextStyle(color: Color(0xFF9090A8), fontSize: 16)),
                            ],
                          ),
                        )
                      : _buildInventoryList(),
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
              color: Color(0xFFEEEEFF),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Color(0xFF0A0A14).withValues(alpha: 0.05), blurRadius: 10)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(0xFF2B0D0D),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFF87171)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          S.t('inv_low_stock_alerts'),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF87171), fontSize: 16),
                        ),
                      ),
                      Chip(
                        label: Text('$_lowStockCount'),
                        backgroundColor: Color(0xFFF87171),
                        labelStyle: const TextStyle(color: Color(0xFFEEEEFF), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(
                  height: 250,
                  child: _lowStockAlerts.isEmpty
                      ? Center(child: Text(S.t('inv_no_alerts'), style: const TextStyle(color: Color(0xFF4ADE80), fontWeight: FontWeight.bold)))
                      : ListView.separated(
                          padding: const EdgeInsets.all(8),
                          itemCount: _lowStockAlerts.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final alert = _lowStockAlerts[index];
                            final variant = alert['product_variants'] ?? {};
                            final name = variant['products']?['name'] ?? S.t('misc_unknown');
                            final size = variant['size'] ?? '-';
                            final qty = alert['quantity'] ?? 0;
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                backgroundColor: Color(0xFF2B0D0D),
                                radius: 16,
                                child: Text('$qty', style: const TextStyle(color: Color(0xFFF87171), fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              title: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              subtitle: Text('${S.t('prod_size')}: $size', style: const TextStyle(fontSize: 11)),
                            );
                          },
                        ),
                ),

            
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Color(0xFF0A0A14),
                  child: Row(
                    children: [
                      const Icon(Icons.swap_vert, color: Color(0xFF58A6FF)),
                      const SizedBox(width: 8),
                      Text(
                        S.t('inv_recent_movements'),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF58A6FF), fontSize: 16),
                      ),
                    ],
                  ),
                ),
            
                Expanded(
                  child: _recentMovements.isEmpty
                      ? Center(child: Text(S.t('inv_no_movements'), style: const TextStyle(color: Color(0xFF9090A8))))
                      : ListView.separated(
                          padding: const EdgeInsets.all(8),
                          itemCount: _recentMovements.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final mov = _recentMovements[index];
                            final isIn = mov['type'] == 'in';
                            final productName = mov['product_variants']?['products']?['name'] ?? S.t('misc_unknown');
                            final size = mov['product_variants']?['size'] ?? '-';
                            final userName = mov['user_profiles']?['full_name'] ?? S.t('misc_system');
                            final date = DateTime.tryParse(mov['created_at'] ?? '');
                            final qty = mov['quantity'] ?? 0;

                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                backgroundColor: isIn ? Color(0xFF0D1F3A) : Color(0xFF0D2B1A),
                                radius: 16,
                                child: Icon(
                                  isIn ? Icons.arrow_downward : Icons.arrow_upward,
                                  color: isIn ? Color(0xFF58A6FF) : Color(0xFF4ADE80),
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                '$productName ($size)',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '${isIn ? S.t('inv_mov_in') : S.t('inv_mov_out')} ${S.t('misc_by')} $userName • ${date != null ? timeago.format(date, locale: AppSession.locale.value == 'ar' ? 'ar' : 'fr') : ''}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: Text(
                                '${isIn ? "+" : "-"}$qty',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isIn ? Color(0xFF58A6FF) : Color(0xFF4ADE80),
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
    );
  }

  Widget _buildEmployeeView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: S.t('inv_search_hint'),
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),
        Expanded(
          child: _filteredInventory.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 64, color: Color(0xFF9090A8)),
                      const SizedBox(height: 12),
                      Text(S.t('inv_no_products'), style: const TextStyle(color: Color(0xFF9090A8), fontSize: 16)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _filteredInventory.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _filteredInventory[index];
                    final variant = item['product_variants'] ?? {};
                    final product = variant['products'] ?? {};
                    final qty = (item['quantity'] as int?) ?? 0;
                    final isLow = qty < 3;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Color(0xFF1E1E35)),
                      ),
                      child: ListTile(
                        onTap: () => _showVariantHistory(item),
                        leading: CircleAvatar(
                          backgroundColor: isLow ? Color(0xFF2B0D0D) : Color(0xFF0D1F3A),
                          child: Icon(
                            isLow ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
                            color: isLow ? Color(0xFFF87171) : Color(0xFF58A6FF),
                          ),
                        ),
                        title: Text(
                          product['name'] ?? S.t('misc_unknown'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${S.t('prod_size')}: ${variant['size'] ?? '-'} | ${S.t('prod_color')}: ${variant['color'] ?? '-'}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isLow ? Color(0xFF2B0D0D) : Color(0xFF0D2B1A),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isLow ? Color(0xFFF87171) : Color(0xFF4ADE80)),
                          ),
                          child: Text(
                            '$qty',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: isLow ? Color(0xFFF87171) : Color(0xFF4ADE80),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showAdjustDialog(Map<String, dynamic> item) {
    final qtyCtrl = TextEditingController();
    String reason = 'other';
    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(S.t('inv_adjust_title')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${item['product_variants']?['products']?['name'] ?? ''} (${item['product_variants']?['size'] ?? ''})',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('${S.t('label_stock')}: ${item['quantity']}'),
          const SizedBox(height: 12),
          TextField(controller: qtyCtrl, keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: S.t('inv_adjust_qty'), hintText: 'Ex: -5 ou +10', border: const OutlineInputBorder())),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: reason,
            decoration: InputDecoration(labelText: S.t('inv_adjust_reason'), border: const OutlineInputBorder()),
            items: [
              DropdownMenuItem(value: 'breakage', child: Text(S.t('inv_reason_breakage'))),
              DropdownMenuItem(value: 'theft', child: Text(S.t('inv_reason_theft'))),
              DropdownMenuItem(value: 'counting', child: Text(S.t('inv_reason_counting'))),
              DropdownMenuItem(value: 'other', child: Text(S.t('inv_reason_other'))),
            ],
            onChanged: (v) => setDialogState(() => reason = v ?? 'other'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.t('action_cancel'))),
          if (AppSession.isOwner)
            ElevatedButton(onPressed: () async {
              final delta = int.tryParse(qtyCtrl.text);
              if (delta == null || delta == 0) return;
              try {
                await Supabase.instance.client.rpc('adjust_inventory', params: {
                  'p_variant_id': item['variant_id'],
                  'p_store_id': _selectedStoreId,
                  'p_quantity_delta': delta,
                  'p_reason': reason,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.t('inv_adjusted')), backgroundColor: Color(0xFF4ADE80)));
                }
                _fetchInventoryData();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Color(0xFFF87171)));
              }
            }, child: Text(S.t('inv_adjust_confirm'))),
        ],
      ),
    ));
  }

  Future<void> _showBulkBarcodeDialog() async {
    final items = _filteredInventory;
    if (items.isEmpty) return;

    final controllers = items
        .map((_) => TextEditingController(text: '1'))
        .toList();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Imprimer ${items.length} étiquettes'),
        content: SizedBox(
          width: 400,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: items.length,
            itemBuilder: (_, i) {
              final item = items[i];
              final variant = item['product_variants'] ?? {};
              final product = variant['products'] ?? {};
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${product['name']} / ${variant['size']} / ${variant['color']}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    SizedBox(
                      width: 70,
                      child: TextField(
                        controller: controllers[i],
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Qté',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Imprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final barcodeItems = <BarcodeItem>[];
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final variant = item['product_variants'] ?? {};
      final product = variant['products'] ?? {};
      final barcode = (variant['barcode'] as String?)?.trim();
      final qty = int.tryParse(controllers[i].text) ?? 1;
      if (qty > 0 && barcode != null && barcode.isNotEmpty) {
        barcodeItems.add(BarcodeItem(
          variantId: item['variant_id'] ?? '',
          barcode: barcode,
          productName: product['name'] ?? '',
          size: variant['size'] ?? '',
          color: variant['color'] ?? '',
          price: (variant['sell_price'] as num?)?.toDouble() ?? 0,
          quantity: qty,
        ));
      }
    }

    if (barcodeItems.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun code-barres valide'), backgroundColor: Color(0xFFF87171)),
        );
      }
      return;
    }

    final pdfBytes = await ReportService.instance.generateBulkBarcodePdf(barcodeItems);
    await Printing.layoutPdf(onLayout: (_) => pdfBytes);
  }

  Future<void> _showVariantHistory(Map<String, dynamic> item) async {
    if (AppSession.isOfflineMode) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.t('misc_online_only')), backgroundColor: Color(0xFFF0A500)),
      );
      return;
    }

    final variant = item['product_variants'] ?? {};
    final product = variant['products'] ?? {};
    final variantId = item['variant_id'];
    final currentQty = (item['quantity'] as int?) ?? 0;

    final movements = <Map<String, dynamic>>[];
    bool isLoading = false;
    bool hasMore = true;
    int offset = 0;
    const limit = 50;

    Future<void> loadMore() async {
      if (isLoading || !hasMore) return;
      isLoading = true;
      try {
        final res = await Supabase.instance.client
            .rpc('get_variant_movement_history', params: {
          'p_variant_id': variantId,
          'p_store_id': _selectedStoreId,
          'p_limit': limit,
          'p_offset': offset,
        });
        final data = res as Map<String, dynamic>;
        final newMovements = (data['movements'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        final total = data['total'] as int? ?? 0;
        movements.addAll(newMovements);
        offset += limit;
        hasMore = movements.length < total;
      } catch (e) {
        debugPrint('Error loading movement history: $e');
      } finally {
        isLoading = false;
      }
    }

    await loadMore();

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (ctx, scrollController) {
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      decoration: BoxDecoration(
                        color: Color(0xFF0F0F1C),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Color(0xFF606078),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  product['name'] ?? S.t('misc_unknown'),
                                  style: const TextStyle(
                                    color: Color(0xFFEEEEFF),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Color(0xFFEEEEFF),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$currentQty ${S.t('inv_units')}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Color(0xFF58A6FF),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${S.t('prod_barcode')}: ${variant['barcode'] ?? '-'} | ${S.t('prod_size')}: ${variant['size'] ?? '-'} | ${S.t('prod_color')}: ${variant['color'] ?? '-'}',
                            style: const TextStyle(
                                color: Color(0xFF9090A8), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: movements.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.history,
                                      size: 64, color: Color(0xFF9090A8)),
                                  const SizedBox(height: 12),
                                  Text(S.t('inv_no_movements'),
                                      style: const TextStyle(color: Color(0xFF9090A8), fontSize: 16)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: movements.length + 1,
                              itemBuilder: (ctx, index) {
                                if (index == movements.length) {
                                  return hasMore
                                      ? Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Center(
                                            child: ElevatedButton.icon(
                                              onPressed: () async {
                                                await loadMore();
                                                setSheetState(() {});
                                              },
                                              icon: const Icon(Icons.expand_more),
                                              label: Text(S.t('action_load_more')),
                                            ),
                                          ),
                                        )
                                      : Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Center(
                                            child: Text(
                                              S.t('misc_end_of_list'),
                                              style: const TextStyle(color: Color(0xFF9090A8)),
                                            ),
                                          ),
                                        );
                                }

                                final mov = movements[index];
                                final type = mov['type'] as String? ?? '';
                                final qtyChange =
                                    (mov['quantity_change'] as num?)?.toInt() ?? 0;
                                final dateStr = mov['date'] as String? ?? '';
                                final date = DateTime.tryParse(dateStr);
                                final performedBy =
                                    mov['performed_by'] as String? ??
                                        S.t('misc_system');

                                IconData icon;
                                Color iconColor;
                                String label;
                                switch (type) {
                                  case 'in':
                                    icon = Icons.arrow_downward;
                                    iconColor = Color(0xFF58A6FF);
                                    label = S.t('inv_mov_in');
                                  case 'out':
                                    icon = Icons.arrow_upward;
                                    iconColor = Color(0xFF4ADE80);
                                    label = S.t('inv_mov_out');
                                  case 'return':
                                    icon = Icons.replay;
                                    iconColor = Color(0xFFFBBF24);
                                    label = S.t('inv_mov_return');
                                  default:
                                    icon = Icons.swap_horiz;
                                    iconColor = Color(0xFFF0A500);
                                    label = type;
                                }

                                final displayQty = type == 'out'
                                    ? -qtyChange
                                    : qtyChange;

                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    backgroundColor: iconColor.withValues(alpha: 0.1),
                                    child: Icon(icon,
                                        color: iconColor, size: 20),
                                  ),
                                  title: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: iconColor.withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          label,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: iconColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${displayQty >= 0 ? '+' : ''}$displayQty',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: displayQty >= 0
                                              ? Color(0xFF4ADE80)
                                              : Color(0xFFF87171),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    '${date != null ? timeago.format(date, locale: AppSession.locale.value == 'ar' ? 'ar' : 'fr') : ''} • $performedBy',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                S.t('action_export'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Color(0xFFF87171)),
              title: const Text('PDF'),
              onTap: () {
                Navigator.pop(ctx);
                _exportAsPdf();
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Color(0xFF4ADE80)),
              title: const Text('Excel'),
              onTap: () {
                Navigator.pop(ctx);
                _exportAsExcel();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _exportAsPdf() async {
    try {
      final items = _filteredInventory.cast<Map<String, dynamic>>();
      if (items.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.t('inv_no_products')), backgroundColor: Color(0xFFF0A500)),
          );
        }
        return;
      }
      final store = _stores.firstWhere((s) => s['id'] == _selectedStoreId);
      final storeName = store['name'] ?? '';
      final bytes = await ReportService.instance.generateInventoryPdf(items, storeName);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/inventory_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Inventory Report');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Color(0xFFF87171)),
        );
      }
    }
  }

  Future<void> _exportAsExcel() async {
    try {
      final items = _filteredInventory.cast<Map<String, dynamic>>();
      if (items.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.t('inv_no_products')), backgroundColor: Color(0xFFF0A500)),
          );
        }
        return;
      }
      final bytes = await ReportService.instance.generateInventoryExcel(items);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/inventory_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Inventory Report');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Color(0xFFF87171)),
        );
      }
    }
  }

  Widget _buildInventoryList() {
    return ListView.separated(
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
          onTap: () => _showVariantHistory(item),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isLow ? Color(0xFF2B0D0D) : Color(0xFF0D1F3A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: product['image_url'] != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(product['image_url'], fit: BoxFit.cover),
                  )
                : Icon(Icons.image_not_supported, color: isLow ? Color(0xFFF87171) : Color(0xFF58A6FF)),
          ),
          title: Text(
            product['name'] ?? S.t('misc_unknown'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '${S.t('prod_size')}: ${variant['size'] ?? '-'} | ${S.t('prod_color')}: ${variant['color'] ?? '-'} | ${S.t('prod_barcode')}: ${variant['barcode'] ?? '-'}',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (AppSession.isOwner)
                IconButton(
                  icon: const Icon(Icons.tune, size: 18, color: Color(0xFFF0A500)),
                  tooltip: S.t('inv_adjust'),
                  onPressed: () => _showAdjustDialog(item),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isLow ? Color(0xFF2B0D0D) : Color(0xFF0D2B1A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isLow ? Color(0xFFF87171) : Color(0xFF4ADE80)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLow) const Icon(Icons.warning_amber, size: 16, color: Color(0xFFF87171)),
                    if (isLow) const SizedBox(width: 4),
                    Text(
                      '$qty',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: isLow ? Color(0xFFF87171) : Color(0xFF4ADE80),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 220, 
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFEEEEFF),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Color(0xFF0A0A14).withValues(alpha: 0.05), blurRadius: 8)],
        border: Border(bottom: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded( 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFF9090A8), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
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