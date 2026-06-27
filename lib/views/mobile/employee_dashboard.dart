import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import '../../core/app_strings.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../theme/app_colors.dart';
import '../../core/app_session.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../theme/app_colors.dart';
import '../../shared/widgets/language_toggle_button.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../local_db/isar_service.dart';
import '../../local_db/collections/product_local.dart';
import '../../local_db/collections/product_variant_local.dart';
import '../../local_db/collections/inventory_local.dart';
import '../../local_db/collections/customer_local.dart';
import '../../local_db/collections/transaction_local.dart';
import '../../services/debt_recovery_service.dart';
import 'expenses_screen.dart';
import 'activity_logs_screen.dart';
import '../admin/notifications_screen.dart';
import '../../services/notification_service.dart';
import '../../services/refund_service.dart';

class EmployeeDashboard extends StatefulWidget {
  const EmployeeDashboard({super.key});

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<Map<String, dynamic>> _fetchCommission() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return {};
      final res = await Supabase.instance.client.rpc('get_employee_commission_summary', params: {
        'p_user_id': userId,
        'p_period': 'month',
      });
      return Map<String, dynamic>.from(res as Map);
    } catch (_) {
      return {};
    }
  }

  void _checkAccess() {
    if (!AppSession.isEmployee) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Text(S.t('auth_access_denied_mobile')),
            content: Text(S.t('owner_role_label')),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Supabase.instance.client.auth.signOut();
                },
                child: Text(S.t('auth_logout')),
              ),
            ],
          ),
        );
      });
    }
  }

  void _showMyDailyReport(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (dialogCtx) => _DailyReportDialog(userId: AppSession.currentUserId ?? ''),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _PosTab(),
      _ProductsTab(),
      _InventoryTab(),
      _CustomersTab(),
      _SalesTab(),
    ];

    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: AppColors.mobileBackground),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.mobileTextMuted,
                    child: Icon(Icons.person, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 12),
                  Text(S.t('dash_employee_dashboard'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            FutureBuilder<Map<String, dynamic>>(
              future: _fetchCommission(),
              builder: (ctx, snap) {
                final comm = snap.data;
                final total = (comm?['total_commission'] as num?)?.toDouble() ?? 0;
                final rate = (comm?['avg_commission_rate'] as num?)?.toDouble() ?? 0;
                return ListTile(
                  leading: Icon(Icons.monetization_on, color: AppColors.warning),
                  title: Text('Commission: ${total.toStringAsFixed(0)} DA'),
                  subtitle: Text('Taux: $rate%'),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.receipt_long, color: AppColors.mobileBackground),
              title: Text('Mon Rapport du Jour'),
              onTap: () {
                Navigator.pop(context);
                _showMyDailyReport(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.money_off, color: AppColors.mobileBackground),
              title: Text(S.t('nav_expenses')),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpensesScreen()));
              },
            ),
            ListTile(
              leading: Icon(Icons.notifications, color: AppColors.mobileBackground),
              title: Text(S.t('nav_activity')),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivityLogsScreen()));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.danger),
              title: Text(S.t('auth_logout'), style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(S.t('auth_logout')),
                    content: Text(S.t('logout_confirm_msg')),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(S.t('action_cancel')),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(S.t('auth_logout'), style: const TextStyle(color: AppColors.danger)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await Supabase.instance.client.auth.signOut();
                }
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: Text(S.t('owner_dash_title')),
        backgroundColor: AppColors.mobileBackground,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: NotificationService.instance.unreadCount,
            builder: (context, count, _) {
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const NotificationsScreen()),
                      );
                    },
                  ),
                  if (count > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const LanguageToggleButton(),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: screens[_currentIndex]),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.mobileBackground,
        onTap: (i) => setState(() => _currentIndex = i),
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.point_of_sale), label: S.t('nav_pos')),
          BottomNavigationBarItem(icon: const Icon(Icons.inventory_2), label: S.t('nav_products')),
          BottomNavigationBarItem(icon: const Icon(Icons.inventory), label: S.t('nav_inventory')),
          BottomNavigationBarItem(icon: const Icon(Icons.people), label: S.t('nav_clients')),
          BottomNavigationBarItem(icon: const Icon(Icons.history), label: S.t('nav_sales')),
        ],
      ),
    );
  }
}

class _PosTab extends StatefulWidget {
  @override
  State<_PosTab> createState() => _PosTabState();
}

class _PosTabState extends State<_PosTab> {
  void _scanBarcode() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.8,
          child: Column(
            children: [
              AppBar(
                title: Text(S.t('owner_scanner_title')),
                automaticallyImplyLeading: false,
                backgroundColor: AppColors.mobileBackground,
                foregroundColor: Colors.white,
                actions: [
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
                ],
              ),
              Expanded(
                child: MobileScanner(
                  onDetect: (capture) {
                    final barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty) {
                      final barcode = barcodes.first.rawValue;
                      if (barcode != null) {
                        Navigator.pop(context);
                        _lookupBarcode(barcode);
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _lookupBarcode(String barcode) async {
    try {
      final res = await Supabase.instance.client
          .from('product_variants')
          .select('id, size, color, sell_price, buy_price, products(name, image_url), inventory!inner(quantity, store_id)')
          .eq('barcode', barcode)
          .eq('inventory.store_id', AppSession.currentStoreId!)
          .maybeSingle();

      if (res == null || !mounted) return;
      final qty = (res['inventory']?['quantity'] as int?) ?? 0;

      if (mounted) {
        _showProductDetail(res['products']['name'], res['size'], res['color'], (res['sell_price'] as num?)?.toDouble() ?? 0, qty, res['products']['image_url']);
      }
    } catch (_) {
      // Offline: try Isar
      try {
        final isar = await IsarService.getInstance();
        final allVariants = await isar.productVariantLocals.where().findAll();
        final variant = allVariants.cast<ProductVariantLocal?>().firstWhere(
          (v) => v?.barcode == barcode,
          orElse: () => null,
        );
        if (variant == null || !mounted) return;
        final storeId = AppSession.currentStoreId;
        final allInv = await isar.inventoryLocals.where().findAll();
        final invItems = allInv.where((i) => i.variantId == variant.supabaseId && (storeId == null || i.storeId == storeId)).toList();
        final qty = invItems.fold<int>(0, (s, i) => s + i.quantity);
        final allProducts = await isar.productLocals.where().findAll();
        final prod = allProducts.cast<ProductLocal?>().firstWhere(
          (p) => p?.supabaseId == variant.productId,
          orElse: () => null,
        );
        _showProductDetail(prod?.name ?? '', variant.size, variant.color, variant.sellPrice, qty, prod?.imageUrl);
      } catch (e, s) { debugPrint('[EmployeeDashboard] error: $e\n$s'); }
    }
  }

  void _showProductDetail(String name, String size, String color, double price, int qty, String? imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(name),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (imageUrl != null) ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(imageUrl, height: 80)),
          const SizedBox(height: 8),
          Text('${S.t('prod_size')}: $size | ${S.t('prod_color')}: $color'),
          Text('${S.t('prod_sell_short')}${price.toStringAsFixed(0)} ${S.t('misc_currency')}'),
          Text('${S.t('label_stock')}: $qty'),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.t('action_close')))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.qr_code_scanner, size: 80, color: AppColors.mobilePrimaryLight),
          const SizedBox(height: 16),
          Text(S.t('owner_scanner_hint'), style: const TextStyle(color: AppColors.mobileTextSecondary)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _scanBarcode,
            icon: const Icon(Icons.qr_code_scanner),
            label: Text(S.t('owner_scanner_start')),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.mobileBackground, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _ProductsTab extends StatefulWidget {
  @override
  State<_ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<_ProductsTab> {
  List<dynamic> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final res = await Supabase.instance.client
          .from('products')
          .select('''
            id, name,
            product_variants(id, size, color, barcode, sell_price, is_active,
              inventory!inner(quantity, store_id)
            )
          ''')
          .eq('is_active', true)
          .eq('product_variants.is_active', true)
          .eq('product_variants.inventory.store_id', AppSession.currentStoreId!);
      if (mounted) setState(() { _products = res; _isLoading = false; });
    } catch (_) {
      // Offline fallback from Isar
      try {
        final isar = await IsarService.getInstance();
        final storeId = AppSession.currentStoreId;
        final allProducts = await isar.productLocals.where().findAll();
        final products = allProducts.where((p) => p.isActive).toList();
        final allVariants = await isar.productVariantLocals.where().findAll();
        final allInv = await isar.inventoryLocals.where().findAll();
        final result = <Map<String, dynamic>>[];
        for (final p in products) {
          final variants = allVariants.where((v) => v.productId == p.supabaseId && v.isActive).toList();
          final mappedVariants = <Map<String, dynamic>>[];
          for (final v in variants) {
            final inv = allInv.where((i) => i.variantId == v.supabaseId && (storeId == null || i.storeId == storeId)).toList();
            final qty = inv.fold<int>(0, (s, i) => s + i.quantity);
            mappedVariants.add({
              'id': v.supabaseId, 'size': v.size, 'color': v.color, 'barcode': v.barcode,
              'sell_price': v.sellPrice, 'is_active': true,
              'inventory': [{'quantity': qty, 'store_id': storeId}],
            });
          }
          result.add({'id': p.supabaseId, 'name': p.name, 'product_variants': mappedVariants});
        }
        if (mounted) setState(() { _products = result; _isLoading = false; });
      } catch (_) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Padding(padding: EdgeInsets.all(16), child: AppShimmerListTile());
    if (_products.isEmpty) return Center(child: Text(S.t('prod_no_results')));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final p = _products[index];
        final variants = (p['product_variants'] as List?)?.where((v) => v['is_active'] == true).toList() ?? [];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            title: Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            children: variants.map<Widget>((v) {
              final qty = (v['inventory'] is List ? (v['inventory'] as List).fold(0, (s, i) => s + ((i['quantity'] as int?) ?? 0)) : (v['inventory']?['quantity'] as int?) ?? 0);
              return ListTile(
                title: Text('${v['size']} - ${v['color']}'),
                subtitle: Text('${S.t('prod_sell_price')}: ${v['sell_price']} ${S.t('misc_currency')}'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: qty > 0 ? AppColors.successLight : AppColors.dangerLight, borderRadius: BorderRadius.circular(8)),
                  child: Text('$qty', style: TextStyle(fontWeight: FontWeight.bold, color: qty > 0 ? AppColors.success : AppColors.danger)),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _InventoryTab extends StatefulWidget {
  @override
  State<_InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<_InventoryTab> {
  List<dynamic> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final res = await Supabase.instance.client
          .from('inventory')
          .select('quantity, product_variants!inner(id, size, color, products!inner(name))')
          .eq('store_id', AppSession.currentStoreId!)
          .order('quantity');
      if (mounted) setState(() { _items = res; _isLoading = false; });
    } catch (_) {
      // Offline fallback from Isar
      try {
        final isar = await IsarService.getInstance();
        final storeId = AppSession.currentStoreId;
        var allInv = await isar.inventoryLocals.where().findAll();
        if (storeId != null) {
          allInv = allInv.where((i) => i.storeId == storeId).toList();
        }
        allInv.sort((a, b) => a.quantity.compareTo(b.quantity));
        final allVariants = await isar.productVariantLocals.where().findAll();
        final allProducts = await isar.productLocals.where().findAll();
        final result = <Map<String, dynamic>>[];
        for (final item in allInv) {
          final variant = allVariants.cast<ProductVariantLocal?>().firstWhere(
            (v) => v?.supabaseId == item.variantId,
            orElse: () => null,
          );
          final prod = variant != null ? allProducts.cast<ProductLocal?>().firstWhere(
            (p) => p?.supabaseId == variant.productId,
            orElse: () => null,
          ) : null;
          result.add({
            'quantity': item.quantity,
            'product_variants': {
              'id': variant?.supabaseId ?? '', 'size': variant?.size ?? '', 'color': variant?.color ?? '',
              'products': {'name': prod?.name ?? ''},
            },
          });
        }
        if (mounted) setState(() { _items = result; _isLoading = false; });
      } catch (_) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Padding(padding: EdgeInsets.all(16), child: AppShimmerListTile());
    if (_items.isEmpty) return Center(child: Text(S.t('inv_no_products')));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final v = item['product_variants'];
        final qty = (item['quantity'] as int?) ?? 0;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(v['products']['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${S.t('prod_size')}: ${v['size']} | ${S.t('prod_color')}: ${v['color']}'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: qty < 3 ? AppColors.dangerLight : AppColors.successLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: qty < 3 ? AppColors.danger : AppColors.success)),
            ),
          ),
        );
      },
    );
  }
}

class _CustomersTab extends StatefulWidget {
  @override
  State<_CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<_CustomersTab> {
  List<dynamic> _customers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final res = await Supabase.instance.client
          .from('customers')
          .select()
          .eq('is_active', true)
          .order('full_name');
      if (mounted) setState(() { _customers = res; _isLoading = false; });
    } catch (_) {
      // Offline fallback from Isar
      try {
        final isar = await IsarService.getInstance();
        final allCustomers = await isar.customerLocals.where().findAll();
        final customers = allCustomers.where((c) => c.isActive).toList();
        customers.sort((a, b) => a.fullName.compareTo(b.fullName));
        if (mounted) setState(() { _customers = customers.map((c) => {
          'id': c.supabaseId, 'full_name': c.fullName, 'phone': c.phone,
          'balance': c.balance, 'is_active': c.isActive,
        }).toList(); _isLoading = false; });
      } catch (_) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _addCustomer() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.t('cust_add')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Téléphone', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.t('action_cancel'))),
          ElevatedButton(onPressed: () async {
            if (nameCtrl.text.isEmpty) return;
            Navigator.pop(ctx);
            try {
              await Supabase.instance.client.from('customers').insert({'full_name': nameCtrl.text.trim(), 'phone': phoneCtrl.text.trim(), 'balance': 0, 'is_active': true});
              try {
                await Supabase.instance.client.from('activity_logs').insert({
                  'user_id': AppSession.currentUserId,
                  'action_type': 'add_customer',
                  'description': 'Nouveau client: ${nameCtrl.text.trim()}',
                });
              } catch (e, s) { debugPrint('[EmployeeDashboard] error: $e\n$s'); }
              _fetch();
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
            }
          }, child: Text(S.t('action_save'))),
        ],
      ),
    );
  }

  void _recordPayment(Map<String, dynamic> customer) {
    final amountCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.t('cust_receive_payment')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${S.t('pos_credit')}: ${(customer['balance'] as num?)?.toDouble() ?? 0} ${S.t('misc_currency')}'),
          const SizedBox(height: 12),
          TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Montant', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.t('action_cancel'))),
          ElevatedButton(onPressed: () async {
            final amount = double.tryParse(amountCtrl.text);
            if (amount == null || amount <= 0) return;
            Navigator.pop(ctx);
            try {
              await DebtRecoveryService.instance.recordDebtPayment(customerId: customer['id'], amount: amount, paymentMethod: 'cash', storeId: AppSession.currentStoreId ?? '', notes: 'Paiement mobile employee');
              _fetch();
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
            }
          }, child: Text(S.t('action_confirm'))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Padding(padding: EdgeInsets.all(16), child: AppShimmerListTile());
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(child: Text('${_customers.length} ${S.t('nav_clients')}', style: const TextStyle(fontWeight: FontWeight.bold))),
              IconButton(icon: const Icon(Icons.person_add), onPressed: _addCustomer),
            ],
          ),
        ),
        Expanded(
          child: _customers.isEmpty
              ? Center(child: Text(S.t('cust_no_results')))
              : ListView.builder(
                  itemCount: _customers.length,
                  itemBuilder: (context, index) {
                    final c = _customers[index];
                    final balance = (c['balance'] as num?)?.toDouble() ?? 0;
                    return ListTile(
                      title: Text(c['full_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(c['phone'] ?? ''),
                      trailing: balance > 0
                          ? Row(mainAxisSize: MainAxisSize.min, children: [
                              Text('${balance.toStringAsFixed(0)} ${S.t('misc_currency')}', style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              IconButton(icon: const Icon(Icons.payments, color: AppColors.success), onPressed: () => _recordPayment(c)),
                            ])
                          : const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SalesTab extends StatefulWidget {
  @override
  State<_SalesTab> createState() => _SalesTabState();
}

class _SalesTabState extends State<_SalesTab> {
  List<dynamic> _sales = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final res = await Supabase.instance.client
          .from('transactions')
          .select('id, invoice_number, invoice_id, quantity, total_price, created_at, type, invoices(status), product_variants(id, products(name), size, color)')
          .eq('type', 'out')
          .eq('store_id', AppSession.currentStoreId!)
          .order('created_at', ascending: false)
          .limit(50);
      if (mounted) setState(() { _sales = res; _isLoading = false; });
    } catch (_) {
      // Offline fallback from Isar
      try {
        final isar = await IsarService.getInstance();
        final storeId = AppSession.currentStoreId;
        var allTxns = await isar.transactionLocals.where().findAll();
        if (storeId != null) {
          allTxns = allTxns.where((t) => t.storeId == storeId).toList();
        }
        final txns = allTxns.where((t) => t.type == 'out').toList();
        txns.sort((a, b) {
          final aDate = a.createdAt ?? DateTime(2000);
          final bDate = b.createdAt ?? DateTime(2000);
          return bDate.compareTo(aDate);
        });
        final result = txns.take(50).map((t) {
          return {
            'id': t.isarId, 'invoice_number': t.invoiceNumber, 'invoice_id': t.invoiceId,
            'quantity': t.quantity, 'total_price': t.totalPrice, 'created_at': (t.createdAt ?? DateTime(2000)).toIso8601String(),
            'type': t.type, 'invoices': {'status': ''},
            'product_variants': {'id': '', 'products': {'name': ''}, 'size': '', 'color': ''},
          };
        }).toList();
        if (mounted) setState(() { _sales = result; _isLoading = false; });
      } catch (_) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _refund(Map<String, dynamic> sale) async {
    final createdAtStr = sale['created_at'] as String?;
    if (createdAtStr == null) return;
    final hoursSince = DateTime.now().difference(DateTime.parse(createdAtStr)).inHours;

    if (hoursSince > 48) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.t('refund_48h_blocked')), backgroundColor: AppColors.danger),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.t('refund_title')),
        content: Text('${S.t('refund_original_invoice')} ${sale['invoice_number']}\n${S.t('refund_total_amount')} ${sale['total_price']} ${S.t('misc_currency')}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.t('action_cancel'))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white), child: Text(S.t('refund_confirm'))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final invoiceId = sale['invoice_id'] ?? sale['id'];
      final items = [{'variant_id': sale['product_variants']?['id'] ?? sale['variant_id'], 'quantity': sale['quantity']}];
      final response = await RefundService.instance.processRefund(
        invoiceId: invoiceId,
        items: items,
        refundAmount: (sale['total_price'] as num?)?.toDouble() ?? 0,
        reason: 'Mobile employee refund',
        storeId: AppSession.currentStoreId ?? '',
      );
      try {
        await Supabase.instance.client.from('activity_logs').insert({
          'user_id': AppSession.currentUserId, 'action_type': 'refund',
          'description': 'Refund from mobile — invoice ${sale['invoice_number']} (employee)',
          'invoice_id': invoiceId, 'amount': sale['total_price'],
        });
      } catch (e, s) { debugPrint('[EmployeeDashboard] error: $e\n$s'); }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${S.t('refund_success')} $response'), backgroundColor: AppColors.success));
      _fetch();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Padding(padding: EdgeInsets.all(16), child: AppShimmerListTile());
    if (_sales.isEmpty) return Center(child: Text(S.t('label_no_data')));
    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _sales.length,
        itemBuilder: (context, index) {
          final s = _sales[index];
          final status = s['invoices']?['status'] as String?;
          final isRefunded = status == 'refunded';
          return Card(
            child: ListTile(
              title: Text('${s['product_variants']?['products']?['name'] ?? ''} (${s['product_variants']?['size'] ?? ''})'),
              subtitle: Text('${s['invoice_number']} • ${s['created_at']?.toString().substring(0, 10) ?? ''}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('${s['total_price']} ${S.t('misc_currency')}', style: TextStyle(decoration: isRefunded ? TextDecoration.lineThrough : null, color: isRefunded ? AppColors.danger : Colors.black)),
                if (status == 'paid')
                  IconButton(icon: const Icon(Icons.assignment_return, color: AppColors.danger, size: 20), onPressed: () => _refund(s)),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _DailyReportDialog extends StatefulWidget {
  final String userId;
  const _DailyReportDialog({required this.userId});

  @override
  State<_DailyReportDialog> createState() => _DailyReportDialogState();
}

class _DailyReportDialogState extends State<_DailyReportDialog> {
  Map<String, dynamic>? _report;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final res = await Supabase.instance.client.rpc('get_cashier_session_report', params: {
        'p_user_id': widget.userId,
        'p_store_id': AppSession.currentStoreId,
        'p_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      });
      if (mounted) setState(() { _report = Map<String, dynamic>.from(res as Map); _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.receipt_long, color: AppColors.mobilePrimary, size: 20),
          const SizedBox(width: 8),
          const Text('Mon Rapport du Jour', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: _loading
            ? const SizedBox(height: 80, child: const Padding(padding: EdgeInsets.all(16), child: AppShimmerListTile()))
            : _report == null
                ? const Text('Erreur lors du chargement du rapport.')
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _mr('Ventes', '${(_report!['total_sales'] as num?)?.toInt() ?? 0}'),
                        _mr('Revenu', '${(_report!['total_revenue'] as num?)?.toDouble() ?? 0} DA'),
                        _mr('Remise moy.', '${(_report!['avg_discount'] as num?)?.toDouble() ?? 0}%'),
                        const Divider(height: 12),
                        _mr('Factures', '${(_report!['total_invoices'] as num?)?.toInt() ?? 0}'),
                        _mr('Remboursements', '${(_report!['total_refunds'] as num?)?.toInt() ?? 0}'),
                        const Divider(height: 12),
                        _mr('Espèces', '${(_report!['cash_collected'] as num?)?.toDouble() ?? 0} DA'),
                        _mr('Crédit', '${(_report!['credit_given'] as num?)?.toDouble() ?? 0} DA'),
                        if (((_report!['top_product_name'] as String?) ?? '').isNotEmpty) ...[
                          const Divider(height: 12),
                          _mr('Top produit', '${_report!['top_product_name']} (${_report!['top_product_qty']})'),
                        ],
                      ],
                    ),
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
      ],
    );
  }

  Widget _mr(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: AppColors.mobileTextSecondary)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}