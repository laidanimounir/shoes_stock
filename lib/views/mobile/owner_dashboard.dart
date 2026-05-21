import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/app_strings.dart';
import '../../core/app_session.dart';
import '../../core/app_colors.dart';
import '../../widgets/offline_banner.dart';
import '../../local_db/isar_service.dart';
import '../../local_db/collections/inventory_local.dart';
import '../../local_db/collections/product_local.dart';
import '../../local_db/collections/product_variant_local.dart';
import '../../local_db/collections/store_local.dart';

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  double _salesToday = 0;
  double _profitToday = 0;
  double _customerDebt = 0;
  double _supplierDebt = 0;

  List<Map<String, dynamic>> _storePerformance = [];
  int _currentStorePage = 0;
  final PageController _pageController = PageController(viewportFraction: 0.85);

  List<dynamic> _lowStockAlerts = [];
  List<dynamic> _recentActivities = [];
  List<Map<String, dynamic>> _debtors = [];

  List<dynamic> _stores = [];
  String? _selectedStoreId;
  List<Map<String, dynamic>> _chartData = [];
  String _chartPeriod = 'month';
  List<Map<String, dynamic>> _topProducts = [];

  bool _isLoading = true;
  late final RealtimeChannel _dashboardSubscription;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('fr', timeago.FrMessages());
    _checkAccess();
    _fetchDashboardData();
    _setupRealtime();
  }

  void _checkAccess() {
    if (!AppSession.isOwner) {
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

  void _setupRealtime() {
    _dashboardSubscription = Supabase.instance.client
        .channel('public:mobile_dashboard')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transactions',
          callback: (payload) => _fetchDashboardData(isRefresh: true),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'payments',
          callback: (payload) => _fetchDashboardData(isRefresh: true),
        )
        .subscribe();
  }

  @override
  void dispose() {
    Supabase.instance.client.removeChannel(_dashboardSubscription);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchDashboardData({bool isRefresh = false}) async {
    if (!mounted) return;
    if (!isRefresh) setState(() => _isLoading = true);
    try {
      await Future.wait([
        _fetchStores(),
        _fetchGlobalFinancials(),
        _fetchStorePerformance(),
        _fetchLowStock(),
        _fetchActivities(),
        _fetchChartData(),
        _fetchTopProducts(),
      ]);
    } catch (e) {
      debugPrint("Dashboard update error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchGlobalFinancials() async {
    try {
      final res = await Supabase.instance.client.rpc('get_owner_financial_summary');
      if (mounted) {
        setState(() {
          _salesToday = (res['today_revenue'] as num?)?.toDouble() ?? 0;
          _profitToday = (res['today_profit'] as num?)?.toDouble() ?? 0;
          _customerDebt = (res['customer_debt'] as num?)?.toDouble() ?? 0;
          _supplierDebt = (res['supplier_debt'] as num?)?.toDouble() ?? 0;
          _debtors = List<Map<String, dynamic>>.from(res['debtors'] ?? []);
        });
      }
    } catch (e) {
      debugPrint("Error global financials: $e");
    }
  }

  Future<void> _fetchStorePerformance() async {
    try {
      final res = await Supabase.instance.client.rpc('get_store_performance');
      final list = List<Map<String, dynamic>>.from(res ?? []);
      if (mounted) setState(() => _storePerformance = list);
    } catch (e) {
      debugPrint("Error store performance: $e");
    }
  }

  Future<void> _fetchLowStock() async {
    try {
      final res = await Supabase.instance.client
          .from('inventory')
          .select('quantity, stores(name), product_variants(size, color, products(name))')
          .lt('quantity', 3)
          .order('quantity', ascending: true)
          .limit(10);
      if (mounted) setState(() => _lowStockAlerts = res);
    } catch (e) {
      // Offline fallback from Isar
      try {
        final isar = await IsarService.getInstance();
        final items = await isar.inventoryLocals.where().findAll();
        final low = items.where((i) => i.quantity < 3).take(10).toList();
        if (mounted) {
          setState(() => _lowStockAlerts = low.map((i) => {
            'quantity': i.quantity,
            'stores': {'name': i.storeId ?? ''},
            'product_variants': {
              'size': '',
              'color': '',
              'products': {'name': ''},
            },
          }).toList());
        }
      } catch (_) {}
    }
  }

  Future<void> _fetchActivities() async {
    try {
      final res = await Supabase.instance.client
          .from('activity_logs')
          .select('*, user_profiles(full_name)')
          .order('created_at', ascending: false)
          .limit(15);
      if (mounted) setState(() => _recentActivities = res);
    } catch (e) {}
  }

  Future<void> _fetchStores() async {
    try {
      final res = await Supabase.instance.client
          .from('stores')
          .select()
          .eq('is_active', true)
          .order('name');
      if (mounted) setState(() => _stores = res);
    } catch (e) {
      debugPrint('Error fetching stores: $e');
    }
  }

  Future<void> _fetchChartData() async {
    try {
      final res = await Supabase.instance.client.rpc('get_revenue_chart_data', params: {
        'p_store_id': _selectedStoreId,
        'p_period': _chartPeriod,
      });
      if (mounted) {
        setState(() => _chartData = List<Map<String, dynamic>>.from(res ?? []));
      }
    } catch (e) {
      debugPrint('Error fetching chart data: $e');
    }
  }

  Future<void> _fetchTopProducts() async {
    try {
      final res = await Supabase.instance.client.rpc('get_top_products', params: {
        'p_store_id': _selectedStoreId,
      });
      if (mounted) {
        setState(() => _topProducts = List<Map<String, dynamic>>.from(res ?? []));
      }
    } catch (e) {
      debugPrint('Error fetching top products: $e');
    }
  }

  // ─── WhatsApp / SMS ─────────────────────────────────────────
  String _cleanPhone(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[\s\-\.\(\)]'), '');
    if (cleaned.startsWith('00213')) {
      cleaned = '+213${cleaned.substring(5)}';
    } else if (cleaned.startsWith('0')) {
      cleaned = '+213${cleaned.substring(1)}';
    } else if (!cleaned.startsWith('+')) {
      cleaned = '+213$cleaned';
    }
    return cleaned;
  }

  Future<void> _sendWhatsApp(String name, String phone, double balance) async {
    final cleanedPhone = _cleanPhone(phone).replaceAll('+', '');
    final message = S.t('contact_whatsapp_msg')
        .replaceAll('{name}', name)
        .replaceAll('{amount}', '${balance.toStringAsFixed(0)} ${S.t('misc_currency')}');
    final url = Uri.parse('https://wa.me/$cleanedPhone?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _sendSMS(String name, String phone, double balance) async {
    final cleanedPhone = _cleanPhone(phone);
    final message = S.t('contact_sms_msg')
        .replaceAll('{name}', name)
        .replaceAll('{amount}', '${balance.toStringAsFixed(0)} ${S.t('misc_currency')}');
    final url = Uri.parse('sms:$cleanedPhone?body=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Widget _buildContactButtons(String? phone, String name, double balance) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chat, color: Colors.green, size: 20),
          tooltip: 'WhatsApp',
          onPressed: () {
            if (phone == null || phone.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(S.t('contact_no_phone')), backgroundColor: Colors.orange),
              );
              return;
            }
            _sendWhatsApp(name, phone, balance);
          },
        ),
        IconButton(
          icon: const Icon(Icons.sms, color: Colors.blue, size: 20),
          tooltip: 'SMS',
          onPressed: () {
            if (phone == null || phone.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(S.t('contact_no_phone')), backgroundColor: Colors.orange),
              );
              return;
            }
            _sendSMS(name, phone, balance);
          },
        ),
      ],
    );
  }

  Widget _buildDebtorsList() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _debtors.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final debtor = _debtors[index];
          final name = debtor['full_name'] ?? '—';
          final phone = debtor['phone'] as String?;
          final balance = (debtor['balance'] as num?)?.toDouble() ?? 0;
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange[50],
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(color: Colors.orange[800], fontWeight: FontWeight.bold)),
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text("${balance.toStringAsFixed(0)} ${S.t('misc_currency')}",
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 12)),
            trailing: _buildContactButtons(phone, name, balance),
          );
        },
      ),
    );
  }

  // ─── زر Inventory ───────────────────────────────────────────
  void _showInventory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _InventorySheet(),
    );
  }

  // ─── زر Analytics ───────────────────────────────────────────
  void _showAnalytics() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AnalyticsSheet(),
    );
  }

  // ─── زر Profile ─────────────────────────────────────────────
  void _showProfile() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ProfileSheet(),
    );
  }

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
                backgroundColor: Colors.indigo[900],
                foregroundColor: Colors.white,
                actions: [
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
                ],
              ),
              Expanded(
                child: MobileScanner(
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty) {
                      final barcode = barcodes.first.rawValue;
                      if (barcode != null) {
                        Navigator.pop(context);
                        _showProductDetailsFromBarcode(barcode);
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

  Future<void> _showProductDetailsFromBarcode(String barcode) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final res = await Supabase.instance.client
          .from('product_variants')
          .select('*, products(name, image_url), inventory(quantity, stores(name))')
          .eq('barcode', barcode)
          .maybeSingle();

      if (mounted) Navigator.pop(context);

      if (res == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.t('owner_product_not_found')), backgroundColor: Colors.red));
        return;
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) {
            final inventory = res['inventory'] as List<dynamic>? ?? [];
            final buyP = (res['buy_price'] as num?)?.toDouble() ?? 0.0;
            final sellP = (res['sell_price'] as num?)?.toDouble() ?? 0.0;
            final margin = sellP - buyP;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(res['products']['name'], style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (res['products']['image_url'] != null)
                      Center(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(res['products']['image_url'], height: 120))),
                    const SizedBox(height: 16),
                    Text('${S.t('pos_size')}: ${res['size']} | ${S.t('pos_color')}: ${res['color']} | ${S.t('pos_code')}: $barcode', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Divider(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(S.t('owner_buy_price')), Text('$buyP ${S.t('misc_currency')}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))]),
                          const SizedBox(height: 4),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(S.t('owner_sell_price')), Text('$sellP ${S.t('misc_currency')}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))]),
                          const Divider(),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(S.t('owner_net_margin')), Text('+$margin ${S.t('misc_currency')}', style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold))]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(S.t('owner_stocks_per_store'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    ...inventory.map((inv) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('• ${inv['stores']['name']}'),
                          Text('${inv['quantity']} ${S.t('inv_units')}', style: TextStyle(fontWeight: FontWeight.bold, color: (inv['quantity'] as int) > 0 ? Colors.green : Colors.red)),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(S.t('action_close')))
              ],
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${S.t('pos_error')} $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(S.t('owner_dash_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_stores.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _selectedStoreId,
                    dropdownColor: Colors.indigo[800],
                    icon: const Icon(Icons.store_outlined, color: Colors.white, size: 16),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Tous', style: TextStyle(color: Colors.white70, fontSize: 12))),
                      ..._stores.map((s) => DropdownMenuItem(
                            value: s['id'] as String?,
                            child: Text(s['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 12)),
                          )),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedStoreId = val);
                      _fetchDashboardData(isRefresh: true);
                    },
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchDashboardData(isRefresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => _fetchDashboardData(isRefresh: true),
                    child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 20),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Text(S.t('owner_financial_health'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(child: _buildMetricCard(S.t('dash_revenue'), "${_salesToday.toStringAsFixed(0)} ${S.t('misc_currency')}", Icons.point_of_sale, Colors.blue)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildMetricCard(S.t('dash_net_profit'), "+${_profitToday.toStringAsFixed(0)} ${S.t('misc_currency')}", Icons.trending_up, Colors.green)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(child: _buildMetricCard(S.t('dash_customer_debt'), "${_customerDebt.toStringAsFixed(0)} ${S.t('misc_currency')}", Icons.account_balance_wallet, Colors.orange)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildMetricCard(S.t('dash_supplier_debt'), "${_supplierDebt.toStringAsFixed(0)} ${S.t('misc_currency')}", Icons.money_off, Colors.red)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_debtors.isNotEmpty) ...[
                    _buildSectionHeader(S.t('contact_debt_list_title'), Icons.people_outline, Colors.orange),
                    _buildDebtorsList(),
                  ],
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Text(S.t('owner_store_performance'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                  ),
                  SizedBox(
                    height: 200,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _storePerformance.length,
                      onPageChanged: (int index) => setState(() => _currentStorePage = index),
                      itemBuilder: (context, index) => _buildStoreCard(_storePerformance[index]),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _storePerformance.asMap().entries.map((entry) {
                      return Container(
                        width: 8.0, height: 8.0,
                        margin: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.indigo.withOpacity(_currentStorePage == entry.key ? 0.9 : 0.2),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionHeader(S.t('dash_revenue_chart'), Icons.bar_chart, Colors.blue),
                  _buildChartCard(),
                  const SizedBox(height: 16),
                  _buildSectionHeader(S.t('dash_top_products_title'), Icons.star, Colors.orange),
                  _buildTopProductsCard(),
                  const SizedBox(height: 16),
                  if (_lowStockAlerts.isNotEmpty) ...[
                    _buildSectionHeader(S.t('inv_low_stock_alerts'), Icons.warning_amber_rounded, Colors.red),
                    _buildLowStockList(),
                  ],
                  const SizedBox(height: 24),
                  _buildSectionHeader(S.t('owner_recent_activities'), Icons.history, Colors.indigo),
                  _buildActivityList(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _scanBarcode,
        backgroundColor: Colors.indigo[900],
        child: const Icon(Icons.qr_code_scanner, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: const Icon(Icons.dashboard, color: Colors.indigo),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.inventory_2_outlined),
                tooltip: S.t('owner_inventory'),
                onPressed: _showInventory, // ✅ مربوط
              ),
              const SizedBox(width: 40),
              IconButton(
                icon: const Icon(Icons.analytics_outlined),
                tooltip: S.t('owner_analytics'),
                onPressed: _showAnalytics, // ✅ مربوط
              ),
              IconButton(
                icon: const Icon(Icons.person_outline),
                tooltip: S.t('owner_profile'),
                onPressed: _showProfile, // ✅ مربوط
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartCard() {
    final data = _chartData;
    final maxRevenue = data.fold<double>(0, (p, v) {
      final rev = (v['revenue'] as num?)?.toDouble() ?? 0;
      return p > rev ? p : rev;
    });
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(S.t('dash_revenue_chart'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.indigo)),
                Row(
                  children: [
                    _periodChip('week', S.t('dash_week')),
                    const SizedBox(width: 4),
                    _periodChip('month', S.t('dash_month')),
                    const SizedBox(width: 4),
                    _periodChip('3months', S.t('dash_3months')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: data.isEmpty
                  ? Center(child: Text(S.t('dash_no_data'), style: const TextStyle(color: Colors.grey)))
                  : LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: maxRevenue > 0 ? (maxRevenue / 4).ceilToDouble() : 1,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Colors.grey[200]!,
                            strokeWidth: 0.5,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                final v = value.toInt();
                                return Text('$v',
                                    style: const TextStyle(color: Colors.grey, fontSize: 9));
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: (data.length / 5).ceilToDouble().clamp(1, double.infinity),
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                                final day = data[idx]['day'] as String? ?? '';
                                final parts = day.split('-');
                                final label = parts.length >= 3 ? '${parts[2]}/${parts[1]}' : day;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(label,
                                      style: const TextStyle(color: Colors.grey, fontSize: 9)),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: List.generate(data.length, (i) {
                              final rev = (data[i]['revenue'] as num?)?.toDouble() ?? 0;
                              return FlSpot(i.toDouble(), rev);
                            }),
                            isCurved: true,
                            color: Colors.blue,
                            barWidth: 2.5,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: data.length <= 31,
                              getDotPainter: (spot, percent, barData, index) {
                                if (index == data.length - 1) {
                                  return FlDotCirclePainter(
                                    radius: 4, color: Colors.blue,
                                    strokeWidth: 2, strokeColor: Colors.white,
                                  );
                                }
                                return FlDotCirclePainter(
                                  radius: 2, color: Colors.blue.withOpacity(0.5), strokeWidth: 0,
                                );
                              },
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.blue.withOpacity(0.08),
                            ),
                          ),
                        ],
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                              final rev = spot.y.toInt();
                              return LineTooltipItem(
                                '$rev ${S.t('misc_currency')}',
                                const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _periodChip(String period, String label) {
    final isSelected = _chartPeriod == period;
    return GestureDetector(
      onTap: () {
        setState(() => _chartPeriod = period);
        _fetchChartData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? Colors.blue.withOpacity(0.4) : Colors.grey[300]!,
            width: 0.8,
          ),
        ),
        child: Text(label,
            style: TextStyle(
              color: isSelected ? Colors.blue : Colors.grey,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
            )),
      ),
    );
  }

  Widget _buildTopProductsCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _topProducts.isEmpty
            ? Center(child: Text(S.t('dash_no_products_sold'), style: const TextStyle(color: Colors.grey)))
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _topProducts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final p = _topProducts[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text('${index + 1}',
                                style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p['product_name'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(p['variant_info'] ?? '',
                                  style: const TextStyle(color: Colors.grey, fontSize: 10)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${p['total_sold'] ?? 0}',
                                style: const TextStyle(color: Colors.blue, fontSize: 13, fontWeight: FontWeight.bold)),
                            Text(S.t('dash_item_count'),
                                style: const TextStyle(color: Colors.grey, fontSize: 9)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildStoreCard(Map<String, dynamic> store) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo[900]!, Colors.indigo[600]!],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(store['name'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
              const Icon(Icons.storefront, color: Colors.white60),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(S.t('dash_today_sales'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  Text("${store['today_sales'].toStringAsFixed(0)} ${S.t('misc_currency')}", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(S.t('dash_net_profit'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  Text("+${store['today_profit'].toStringAsFixed(0)} ${S.t('misc_currency')}", style: const TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(S.t('dash_stock_value'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text("${store['stock_value'].toStringAsFixed(0)} ${S.t('misc_currency')}", style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        border: Border(bottom: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              CircleAvatar(radius: 4, backgroundColor: color),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildLowStockList() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _lowStockAlerts.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final alert = _lowStockAlerts[index];
          return ListTile(
            title: Text("${alert['product_variants']['products']['name']} (${alert['product_variants']['size']})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text("${S.t('label_store')}: ${alert['stores']['name']}", style: const TextStyle(fontSize: 12)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12)),
              child: Text("${alert['quantity']} ${S.t('owner_qty_remaining')}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActivityList() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _recentActivities.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final log = _recentActivities[index];
          final date = DateTime.parse(log['created_at']);
          return ListTile(
            leading: CircleAvatar(backgroundColor: Colors.indigo[50], child: const Icon(Icons.notifications_none, size: 20, color: Colors.indigo)),
            title: Text(log['description'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: Text("${log['user_profiles']['full_name']} • ${timeago.format(date, locale: 'fr')}", style: const TextStyle(fontSize: 11)),
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// 📦 INVENTORY SHEET
// ════════════════════════════════════════════════════════════
class _InventorySheet extends StatefulWidget {
  const _InventorySheet();

  @override
  State<_InventorySheet> createState() => _InventorySheetState();
}

class _InventorySheetState extends State<_InventorySheet> {
  List<dynamic> _inventory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchInventory();
  }

  Future<void> _fetchInventory() async {
    try {
      final res = await Supabase.instance.client
          .from('inventory')
          .select('quantity, stores(name), product_variants(size, color, products(name))')
          .order('quantity', ascending: true);
      if (mounted) setState(() { _inventory = res; _isLoading = false; });
    } catch (e) {
      // Offline fallback from Isar
      try {
        final isar = await IsarService.getInstance();
        final items = await isar.inventoryLocals.where().findAll();
        items.sort((a, b) => a.quantity.compareTo(b.quantity));
        final allVariants = await isar.productVariantLocals.where().findAll();
        final allProducts = await isar.productLocals.where().findAll();
        final result = <Map<String, dynamic>>[];
        for (final item in items) {
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
            'stores': {'name': item.storeId ?? ''},
            'product_variants': {
              'size': variant?.size ?? '', 'color': variant?.color ?? '',
              'products': {'name': prod?.name ?? ''},
            },
          });
        }
        if (mounted) setState(() { _inventory = result; _isLoading = false; });
      } catch (_) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.inventory_2, color: Colors.indigo[900], size: 22),
                    const SizedBox(width: 10),
                    Text(S.t('owner_inv_all_stores'),
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.indigo[900])),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Liste
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _inventory.isEmpty
                        ? Center(child: Text(S.t('owner_no_items_stock')))
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: _inventory.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                            itemBuilder: (context, index) {
                              final item = _inventory[index];
                              final qty = (item['quantity'] as num?)?.toInt() ?? 0;
                              final isLow = qty < 3;
                              final productName = item['product_variants']?['products']?['name'] ?? '—';
                              final size = item['product_variants']?['size'] ?? '';
                              final color = item['product_variants']?['color'] ?? '';
                              final storeName = item['stores']?['name'] ?? '—';

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isLow ? Colors.red[50] : Colors.indigo[50],
                                  child: Icon(
                                    isLow ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                                    color: isLow ? Colors.red : Colors.indigo,
                                    size: 20,
                                  ),
                                ),
                                title: Text('$productName  •  ${S.t('pos_size')} $size',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text('$storeName  |  ${S.t('pos_color')}: $color',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isLow ? Colors.red[50] : Colors.green[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text('$qty ${S.t('inv_units')}',
                                      style: TextStyle(
                                        color: isLow ? Colors.red : Colors.green[700],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      )),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════
// 📊 ANALYTICS SHEET
// ════════════════════════════════════════════════════════════
class _AnalyticsSheet extends StatefulWidget {
  const _AnalyticsSheet();

  @override
  State<_AnalyticsSheet> createState() => _AnalyticsSheetState();
}

class _AnalyticsSheetState extends State<_AnalyticsSheet> {
  bool _isLoading = true;

  double _salesToday = 0;
  double _salesThisMonth = 0;
  double _salesLastMonth = 0;

  List<Map<String, dynamic>> _topProducts = [];
  List<Map<String, dynamic>> _storeComparison = [];

  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    try {
      // RPC 1: ملخص المبيعات + مقارنة المتاجر
      final summary = await Supabase.instance.client.rpc('get_analytics_summary');
      _salesToday = (summary['today_sales'] as num?)?.toDouble() ?? 0;
      _salesThisMonth = (summary['this_month_sales'] as num?)?.toDouble() ?? 0;
      _salesLastMonth = (summary['last_month_sales'] as num?)?.toDouble() ?? 0;

      // مقارنة المتاجر
      final storeList = List<Map<String, dynamic>>.from(summary['store_comparison'] ?? []);
      final maxSales = storeList.fold(0.0, (max, s) => (s['sales'] as num).toDouble() > max ? (s['sales'] as num).toDouble() : max);
      for (var s in storeList) {
        s['ratio'] = maxSales > 0 ? (s['sales'] as num).toDouble() / maxSales : 0.0;
      }
      _storeComparison = storeList;

      // RPC 2: Top 5 products
      final topRes = await Supabase.instance.client.rpc('get_top_products_this_month');
      _topProducts = List<Map<String, dynamic>>.from(topRes ?? []).map((e) => {
        'name': e['product_name'],
        'size': e['size'],
        'qty': e['total_sold'],
      }).toList();

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthDiff = _salesLastMonth > 0
        ? ((_salesThisMonth - _salesLastMonth) / _salesLastMonth * 100)
        : 0.0;
    final isUp = monthDiff >= 0;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        width: 40, height: 4,
                        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    // Header
                    Row(
                      children: [
                        Icon(Icons.analytics, color: Colors.indigo[900], size: 22),
                        const SizedBox(width: 10),
                        Text(S.t('owner_analytics'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.indigo[900])),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Section 1: Ventes ──
                    _sectionTitle(S.t('owner_sales_section'), Icons.point_of_sale, Colors.blue),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _analyticsCard(S.t('dash_today'), "${_salesToday.toStringAsFixed(0)} ${S.t('misc_currency')}", Colors.blue)),
                        const SizedBox(width: 12),
                        Expanded(child: _analyticsCard(S.t('dash_this_month'), "${_salesThisMonth.toStringAsFixed(0)} ${S.t('misc_currency')}", Colors.indigo)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isUp ? Colors.green[50] : Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${S.t('owner_vs_last_month')} (${_salesLastMonth.toStringAsFixed(0)} ${S.t('misc_currency')})',
                              style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                          Row(
                            children: [
                              Icon(isUp ? Icons.trending_up : Icons.trending_down,
                                  color: isUp ? Colors.green : Colors.red, size: 18),
                              const SizedBox(width: 4),
                              Text('${monthDiff.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    color: isUp ? Colors.green[700] : Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  )),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Section 2: Top Produits ──
                    _sectionTitle(S.t('owner_top_5_products'), Icons.star, Colors.orange),
                    const SizedBox(height: 12),
                    ..._topProducts.asMap().entries.map((entry) {
                      final i = entry.key;
                      final p = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.orange[100],
                              child: Text('${i + 1}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text('${p['name']}  ${S.t('pos_size')} ${p['size']}',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            ),
                            Text('${p['qty']} ${S.t('owner_qty_sold')}',
                                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 24),

                    // ── Section 3: Comparaison Magasins ──
                    _sectionTitle(S.t('owner_store_comp_today'), Icons.storefront, Colors.purple),
                    const SizedBox(height: 12),
                    ..._storeComparison.map((store) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(store['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('${(store['sales'] as double).toStringAsFixed(0)} ${S.t('misc_currency')}',
                                    style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                              value: (store['ratio'] as double).clamp(0.0, 1.0),
                              backgroundColor: Colors.grey[200],
                              color: Colors.purple,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 30),
                  ],
                ),
        );
      },
    );
  }

  Widget _sectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _analyticsCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// 👤 PROFILE SHEET
// ════════════════════════════════════════════════════════════
class _ProfileSheet extends StatefulWidget {
  const _ProfileSheet();

  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  String _fullName = '';
  String _email = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final res = await Supabase.instance.client
          .from('user_profiles')
          .select('full_name')
          .eq('id', user.id)
          .single();
      if (mounted) {
        setState(() {
          _fullName = res['full_name'] ?? '';
          _email = user.email ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _changePassword() {
    final newPassCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscure1 = true;
    bool obscure2 = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(S.t('owner_change_password'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: newPassCtrl,
                obscureText: obscure1,
                decoration: InputDecoration(
                  labelText: S.t('owner_new_password'),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(obscure1 ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setDialogState(() => obscure1 = !obscure1),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: obscure2,
                decoration: InputDecoration(
                  labelText: S.t('owner_confirm_password'),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(obscure2 ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setDialogState(() => obscure2 = !obscure2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.t('action_cancel'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo[900], foregroundColor: Colors.white),
              onPressed: () async {
                if (newPassCtrl.text.isEmpty || newPassCtrl.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.t('owner_min_chars')), backgroundColor: Colors.orange));
                  return;
                }
                if (newPassCtrl.text != confirmCtrl.text) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.t('owner_passwords_mismatch')), backgroundColor: Colors.red));
                  return;
                }
                try {
                  await Supabase.instance.client.auth.updateUser(
                    UserAttributes(password: newPassCtrl.text),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.t('owner_password_changed')), backgroundColor: Colors.green));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${S.t('pos_error')} $e'), backgroundColor: Colors.red));
                  }
                }
              },
              child: Text(S.t('action_confirm')),
            ),
          ],
        ),
      ),
    );
  }

  void _signOut() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(S.t('auth_logout')),
        content: Text(S.t('auth_logout_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.t('action_cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await Supabase.instance.client.auth.signOut();
            },
            child: Text(S.t('auth_logout')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.75,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        width: 40, height: 4,
                        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Avatar + Nom
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: Colors.indigo[900],
                            child: Text(
                              _fullName.isNotEmpty ? _fullName[0].toUpperCase() : 'P',
                              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(_fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.indigo[50],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(S.t('owner_role_label'), style: TextStyle(color: Colors.indigo[900], fontWeight: FontWeight.w600, fontSize: 12)),
                          ),
                          const SizedBox(height: 4),
                          Text(_email, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Divider(),
                    const SizedBox(height: 12),
                    // Changer mot de passe
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      tileColor: Colors.grey[50],
                      leading: Icon(Icons.lock_outline, color: Colors.indigo[900]),
                      title: Text(S.t('owner_change_password'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: _changePassword,
                    ),
                    const SizedBox(height: 12),
                    // Déconnexion
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      tileColor: Colors.red[50],
                      leading: const Icon(Icons.logout, color: Colors.red),
                      title: Text(S.t('auth_logout'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                      onTap: _signOut,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
        );
      },
    );
  }
}