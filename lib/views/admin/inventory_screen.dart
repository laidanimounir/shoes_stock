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
                .select('id, size, color, barcode, buy_price, products(name, image_url)')
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
      backgroundColor: _T.bgPage,
      appBar: AppBar(
        title: Text(S.t('inv_dashboard_title'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _T.textPrimary)),
        backgroundColor: _T.bgAppBar,
        elevation: 0,
        foregroundColor: _T.textPrimary,
        actions: [
          if (_stores.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _T.bgTableHeader,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _T.borderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedStoreId,
                  dropdownColor: _T.bgTableHeader,
                  icon: const Icon(Icons.unfold_more_rounded, color: _T.textMuted, size: 16),
                  style: const TextStyle(color: _T.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  items: _stores.map<DropdownMenuItem<String>>((store) {
                    return DropdownMenuItem<String>(
                      value: store['id'],
                      child: Row(children: [
                        const Icon(Icons.warehouse_rounded, color: _T.textMuted, size: 16),
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
            icon: const Icon(Icons.download_rounded, color: _T.textSecondary),
            tooltip: S.t('action_export'),
            onPressed: _showExportOptions,
          ),
          IconButton(
            icon: const Icon(Icons.print_rounded, color: _T.textSecondary),
            tooltip: 'Imprimer Barcodes',
            onPressed: _filteredInventory.isNotEmpty ? () => _showBulkBarcodeDialog() : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _T.textSecondary),
            tooltip: S.t('action_refresh'),
            onPressed: _fetchInventoryData,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _T.accentGold))
          : _stores.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.warehouse_outlined, size: 48, color: _T.textMuted),
                      const SizedBox(height: 14),
                      Text(S.t('inv_no_store_msg'),
                          style: const TextStyle(fontSize: 16, color: _T.textSecondary)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    if (AppSession.isEmployee)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        color: _T.accentGold.withValues(alpha: 0.1),
                        child: Row(
                          children: [
                            const Icon(Icons.visibility_rounded, size: 16, color: _T.accentGold),
                            const SizedBox(width: 8),
                            Text(S.t('inv_read_only'),
                                style: const TextStyle(
                                    color: _T.accentGold, fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                      ),
                    Expanded(
                      child: AppSession.isEmployee ? _buildEmployeeView() : _buildOwnerView(),
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
                    _buildStatCard(S.t('inv_stat_total_products'), '$_totalProducts', Icons.category_rounded, _T.accentBlue),
                    _buildStatCard(S.t('inv_stat_total_stock'), '$_totalStock ${S.t('inv_units')}', Icons.inventory_2_rounded, _T.statusPaidText),
                    _buildStatCard(S.t('inv_stat_total_value'), '${_totalValue.toStringAsFixed(2)} ${S.t('misc_currency')}', Icons.account_balance_wallet_rounded, _T.accentGold),
                    _buildStatCard(S.t('inv_stat_low_stock'), '$_lowStockCount', Icons.warning_amber_rounded, _T.statusUnpaidText),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      hintText: S.t('inv_search_hint'),
                      hintStyle: const TextStyle(color: _T.textMuted, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, color: _T.textMuted, size: 18),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
                    color: _T.bgCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _T.borderColor),
                  ),
                  child: _filteredInventory.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.inventory_2_outlined, size: 48, color: _T.textMuted),
                              const SizedBox(height: 12),
                              Text(S.t('inv_no_products'),
                                  style: const TextStyle(color: _T.textSecondary, fontSize: 15)),
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
              color: _T.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _T.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: _T.statusUnpaidBg,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: _T.statusUnpaidText),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          S.t('inv_low_stock_alerts'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, color: _T.statusUnpaidText, fontSize: 15),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _T.statusUnpaidText,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('$_lowStockCount',
                            style: const TextStyle(color: _T.bgPage, fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 250,
                  child: _lowStockAlerts.isEmpty
                      ? Center(
                          child: Text(S.t('inv_no_alerts'),
                              style: const TextStyle(color: _T.statusPaidText, fontWeight: FontWeight.w700)))
                      : ListView.separated(
                          padding: const EdgeInsets.all(8),
                          itemCount: _lowStockAlerts.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: _T.borderColor),
                          itemBuilder: (context, index) {
                            final alert = _lowStockAlerts[index];
                            final variant = alert['product_variants'] ?? {};
                            final name = variant['products']?['name'] ?? S.t('misc_unknown');
                            final size = variant['size'] ?? '-';
                            final qty = alert['quantity'] ?? 0;
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                backgroundColor: _T.statusUnpaidBg,
                                radius: 16,
                                child: Text('$qty',
                                    style: const TextStyle(
                                        color: _T.statusUnpaidText, fontWeight: FontWeight.w700, fontSize: 12)),
                              ),
                              title: Text(name,
                                  style: const TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w700, color: _T.textPrimary)),
                              subtitle: Text('${S.t('prod_size')}: $size',
                                  style: const TextStyle(fontSize: 11, color: _T.textSecondary)),
                            );
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  color: _T.bgPage,
                  child: Row(
                    children: [
                      const Icon(Icons.swap_vert_rounded, color: _T.accentBlue),
                      const SizedBox(width: 8),
                      Text(
                        S.t('inv_recent_movements'),
                        style: const TextStyle(fontWeight: FontWeight.w700, color: _T.accentBlue, fontSize: 15),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _recentMovements.isEmpty
                      ? Center(
                          child: Text(S.t('inv_no_movements'),
                              style: const TextStyle(color: _T.textMuted)))
                      : ListView.separated(
                          padding: const EdgeInsets.all(8),
                          itemCount: _recentMovements.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: _T.borderColor),
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
                                backgroundColor: isIn ? const Color(0xFF0D1F3A) : _T.statusPaidBg,
                                radius: 16,
                                child: Icon(
                                  isIn ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                  color: isIn ? _T.accentBlue : _T.statusPaidText,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                '$productName ($size)',
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w700, color: _T.textPrimary),
                              ),
                              subtitle: Text(
                                '${isIn ? S.t('inv_mov_in') : S.t('inv_mov_out')} ${S.t('misc_by')} $userName • ${date != null ? timeago.format(date, locale: AppSession.locale.value == 'ar' ? 'ar' : 'fr') : ''}',
                                style: const TextStyle(fontSize: 11, color: _T.textSecondary),
                              ),
                              trailing: Text(
                                '${isIn ? "+" : "-"}$qty',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: isIn ? _T.accentBlue : _T.statusPaidText,
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
                hintText: S.t('inv_search_hint'),
                hintStyle: const TextStyle(color: _T.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: _T.textMuted, size: 18),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
        ),
        Expanded(
          child: _filteredInventory.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 48, color: _T.textMuted),
                      const SizedBox(height: 12),
                      Text(S.t('inv_no_products'),
                          style: const TextStyle(color: _T.textSecondary, fontSize: 15)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _filteredInventory.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = _filteredInventory[index];
                    final variant = item['product_variants'] ?? {};
                    final product = variant['products'] ?? {};
                    final qty = (item['quantity'] as int?) ?? 0;
                    final isLow = qty < 3;

                    return Card(
                      margin: EdgeInsets.zero,
                      color: _T.bgCard,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: _T.borderColor),
                      ),
                      child: ListTile(
                        onTap: () => _showVariantHistory(item),
                        leading: CircleAvatar(
                          backgroundColor: isLow ? _T.statusUnpaidBg : const Color(0xFF0D1F3A),
                          child: Icon(
                            isLow ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
                            color: isLow ? _T.statusUnpaidText : _T.accentBlue,
                          ),
                        ),
                        title: Text(
                          product['name'] ?? S.t('misc_unknown'),
                          style: const TextStyle(fontWeight: FontWeight.w700, color: _T.textPrimary),
                        ),
                        subtitle: Text(
                          '${S.t('prod_size')}: ${variant['size'] ?? '-'} | ${S.t('prod_color')}: ${variant['color'] ?? '-'}',
                          style: const TextStyle(fontSize: 12, color: _T.textSecondary),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isLow ? _T.statusUnpaidBg : _T.statusPaidBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isLow ? _T.statusUnpaidText : _T.statusPaidText),
                          ),
                          child: Text(
                            '$qty',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: isLow ? _T.statusUnpaidText : _T.statusPaidText,
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
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: _T.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(S.t('inv_adjust_title'),
              style: const TextStyle(color: _T.textPrimary, fontWeight: FontWeight.w800, fontSize: 17)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${item['product_variants']?['products']?['name'] ?? ''} (${item['product_variants']?['size'] ?? ''})',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: _T.textPrimary)),
              const SizedBox(height: 4),
              Text('${S.t('label_stock')}: ${item['quantity']}',
                  style: const TextStyle(color: _T.textSecondary, fontSize: 13)),
              const SizedBox(height: 14),
              _themedField(
                controller: qtyCtrl,
                label: S.t('inv_adjust_qty'),
                hint: 'Ex: -5 ou +10',
                icon: Icons.exposure_rounded,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: reason,
                dropdownColor: _T.bgTableHeader,
                style: const TextStyle(color: _T.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  labelText: S.t('inv_adjust_reason'),
                  labelStyle: const TextStyle(color: _T.textSecondary, fontSize: 13),
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
                items: [
                  DropdownMenuItem(value: 'breakage', child: Text(S.t('inv_reason_breakage'))),
                  DropdownMenuItem(value: 'theft', child: Text(S.t('inv_reason_theft'))),
                  DropdownMenuItem(value: 'counting', child: Text(S.t('inv_reason_counting'))),
                  DropdownMenuItem(value: 'other', child: Text(S.t('inv_reason_other'))),
                ],
                onChanged: (v) => setDialogState(() => reason = v ?? 'other'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(S.t('action_cancel'), style: const TextStyle(color: _T.textSecondary)),
            ),
            if (AppSession.isOwner)
              ElevatedButton(
                onPressed: () async {
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
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(S.t('inv_adjusted')),
                        backgroundColor: _T.statusPaidBg,
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.all(12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ));
                    }
                    _fetchInventoryData();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('$e'),
                        backgroundColor: _T.statusUnpaidBg,
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.all(12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ));
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _T.accentGold,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(S.t('inv_adjust_confirm'),
                    style: const TextStyle(color: _T.bgPage, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _themedField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: _T.textPrimary, fontSize: 14),
      cursorColor: _T.accentGold,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: _T.textSecondary, fontSize: 13),
        hintStyle: const TextStyle(color: _T.textMuted, fontSize: 13),
        prefixIcon: Icon(icon, color: _T.textMuted, size: 18),
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

  Future<void> _showBulkBarcodeDialog() async {
    final items = _filteredInventory;
    if (items.isEmpty) return;

    final controllers = items.map((_) => TextEditingController(text: '1')).toList();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _T.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Imprimer ${items.length} étiquettes',
            style: const TextStyle(color: _T.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
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
          SnackBar(
            content: const Text('Aucun code-barres valide'),
            backgroundColor: _T.statusUnpaidBg,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
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
        SnackBar(
          content: Text(S.t('misc_online_only')),
          backgroundColor: _T.statusPartialBg,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
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
        final res = await Supabase.instance.client.rpc('get_variant_movement_history', params: {
          'p_variant_id': variantId,
          'p_store_id': _selectedStoreId,
          'p_limit': limit,
          'p_offset': offset,
        });
        final data = res as Map<String, dynamic>;
        final newMovements = (data['movements'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
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
      backgroundColor: _T.bgCard,
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
                      decoration: const BoxDecoration(
                        color: _T.bgAppBar,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: _T.textMuted,
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
                                    color: _T.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _T.bgTableHeader,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: _T.borderColor),
                                ),
                                child: Text(
                                  '$currentQty ${S.t('inv_units')}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: _T.accentBlue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${S.t('prod_barcode')}: ${variant['barcode'] ?? '-'} | ${S.t('prod_size')}: ${variant['size'] ?? '-'} | ${S.t('prod_color')}: ${variant['color'] ?? '-'}',
                            style: const TextStyle(color: _T.textSecondary, fontSize: 13),
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
                                  const Icon(Icons.history_rounded, size: 48, color: _T.textMuted),
                                  const SizedBox(height: 12),
                                  Text(S.t('inv_no_movements'),
                                      style: const TextStyle(color: _T.textSecondary, fontSize: 15)),
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
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: _T.bgTableHeader,
                                                foregroundColor: _T.textPrimary,
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                    side: const BorderSide(color: _T.borderColor)),
                                              ),
                                              icon: const Icon(Icons.expand_more_rounded, size: 18),
                                              label: Text(S.t('action_load_more')),
                                            ),
                                          ),
                                        )
                                      : Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Center(
                                            child: Text(
                                              S.t('misc_end_of_list'),
                                              style: const TextStyle(color: _T.textMuted),
                                            ),
                                          ),
                                        );
                                }

                                final mov = movements[index];
                                final type = mov['type'] as String? ?? '';
                                final qtyChange = (mov['quantity_change'] as num?)?.toInt() ?? 0;
                                final dateStr = mov['date'] as String? ?? '';
                                final date = DateTime.tryParse(dateStr);
                                final performedBy = mov['performed_by'] as String? ?? S.t('misc_system');

                                IconData icon;
                                Color iconColor;
                                String label;
                                switch (type) {
                                  case 'in':
                                    icon = Icons.arrow_downward_rounded;
                                    iconColor = _T.accentBlue;
                                    label = S.t('inv_mov_in');
                                  case 'out':
                                    icon = Icons.arrow_upward_rounded;
                                    iconColor = _T.statusPaidText;
                                    label = S.t('inv_mov_out');
                                  case 'return':
                                    icon = Icons.replay_rounded;
                                    iconColor = _T.statusRefundedText;
                                    label = S.t('inv_mov_return');
                                  default:
                                    icon = Icons.swap_horiz_rounded;
                                    iconColor = _T.accentGold;
                                    label = type;
                                }

                                final displayQty = type == 'out' ? -qtyChange : qtyChange;

                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    backgroundColor: iconColor.withValues(alpha: 0.12),
                                    child: Icon(icon, color: iconColor, size: 20),
                                  ),
                                  title: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: iconColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          label,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: iconColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${displayQty >= 0 ? '+' : ''}$displayQty',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: displayQty >= 0 ? _T.statusPaidText : _T.statusUnpaidText,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    '${date != null ? timeago.format(date, locale: AppSession.locale.value == 'ar' ? 'ar' : 'fr') : ''} • $performedBy',
                                    style: const TextStyle(fontSize: 11, color: _T.textSecondary),
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
      backgroundColor: _T.bgCard,
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
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: _T.textPrimary),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded, color: _T.statusUnpaidText),
              title: const Text('PDF', style: TextStyle(color: _T.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _exportAsPdf();
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_rounded, color: _T.statusPaidText),
              title: const Text('Excel', style: TextStyle(color: _T.textPrimary)),
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
            SnackBar(
              content: Text(S.t('inv_no_products')),
              backgroundColor: _T.statusPartialBg,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
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
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: _T.statusUnpaidBg,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
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
            SnackBar(
              content: Text(S.t('inv_no_products')),
              backgroundColor: _T.statusPartialBg,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
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
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: _T.statusUnpaidBg,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Widget _buildInventoryList() {
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: _filteredInventory.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: _T.borderColor),
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
              color: isLow ? _T.statusUnpaidBg : const Color(0xFF0D1F3A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: product['image_url'] != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(product['image_url'], fit: BoxFit.cover),
                  )
                : Icon(Icons.image_not_supported_rounded,
                    color: isLow ? _T.statusUnpaidText : _T.accentBlue),
          ),
          title: Text(
            product['name'] ?? S.t('misc_unknown'),
            style: const TextStyle(fontWeight: FontWeight.w700, color: _T.textPrimary),
          ),
          subtitle: Text(
            '${S.t('prod_size')}: ${variant['size'] ?? '-'} | ${S.t('prod_color')}: ${variant['color'] ?? '-'} | ${S.t('prod_barcode')}: ${variant['barcode'] ?? '-'}',
            style: const TextStyle(fontSize: 12, color: _T.textSecondary),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (AppSession.isOwner)
                IconButton(
                  icon: const Icon(Icons.tune_rounded, size: 18, color: _T.accentGold),
                  tooltip: S.t('inv_adjust'),
                  onPressed: () => _showAdjustDialog(item),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isLow ? _T.statusUnpaidBg : _T.statusPaidBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isLow ? _T.statusUnpaidText : _T.statusPaidText),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLow) const Icon(Icons.warning_amber_rounded, size: 16, color: _T.statusUnpaidText),
                    if (isLow) const SizedBox(width: 4),
                    Text(
                      '$qty',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: isLow ? _T.statusUnpaidText : _T.statusPaidText,
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
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        color: _T.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _T.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: const Border(left: BorderSide(color: _T.accentGold, width: 3)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: const TextStyle(color: _T.textMuted, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(value,
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}