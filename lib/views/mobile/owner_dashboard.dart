import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mobile_scanner/mobile_scanner.dart';

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  // مؤشرات مالية عامة (Global KPIs)
  double _salesToday = 0;
  double _profitToday = 0;
  double _customerDebt = 0;
  double _supplierDebt = 0;

  // أداء الفروع
  List<Map<String, dynamic>> _storePerformance = [];
  int _currentStorePage = 0;
  final PageController _pageController = PageController(viewportFraction: 0.85);

  // القوائم
  List<dynamic> _lowStockAlerts = [];
  List<dynamic> _recentActivities = [];

  bool _isLoading = true;
  late final RealtimeChannel _dashboardSubscription;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('fr', timeago.FrMessages());
    _fetchDashboardData();
    _setupRealtime();
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
        _fetchGlobalFinancials(),
        _fetchStorePerformance(),
        _fetchLowStock(),
        _fetchActivities(),
      ]);
    } catch (e) {
      debugPrint("Dashboard update error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchGlobalFinancials() async {
    try {
      final today = DateTime.now();
      // تم إزالة toUtc() ليتطابق 100% مع توقيت الكمبيوتر (الـ POS)
      final todayStart = DateTime(today.year, today.month, today.day).toIso8601String();

      final todayRes = await Supabase.instance.client
          .from('transactions')
          .select('quantity, total_price, product_variants(buy_price)')
          .eq('type', 'out')
          .gte('created_at', todayStart);

      double todaySales = 0;
      double todayProfit = 0;

      for (var row in todayRes) {
        double total = (row['total_price'] as num?)?.toDouble() ?? 0.0;
        int qty = (row['quantity'] as num?)?.toInt() ?? 0;
        
        double buyPrice = 0.0;
        final pv = row['product_variants'];
        if (pv != null) {
          if (pv is Map) {
            buyPrice = (pv['buy_price'] as num?)?.toDouble() ?? 0.0;
          } else if (pv is List && pv.isNotEmpty) {
            buyPrice = (pv[0]['buy_price'] as num?)?.toDouble() ?? 0.0;
          }
        }
        
        todaySales += total;
        todayProfit += (total - (buyPrice * qty));
      }

      final custRes = await Supabase.instance.client.from('customers').select('balance').eq('is_active', true);
      double cDebt = custRes.fold(0.0, (sum, c) => sum + ((c['balance'] as num?)?.toDouble() ?? 0.0));

      final suppRes = await Supabase.instance.client.from('suppliers').select('balance').eq('is_active', true);
      double sDebt = suppRes.fold(0.0, (sum, s) => sum + ((s['balance'] as num?)?.toDouble() ?? 0.0));

      if (mounted) {
        setState(() {
          _salesToday = todaySales;
          _profitToday = todayProfit;
          _customerDebt = cDebt;
          _supplierDebt = sDebt;
        });
      }
    } catch (e) {
      debugPrint("Error global financials: $e");
    }
  }

  Future<void> _fetchStorePerformance() async {
    try {
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day).toIso8601String();

      final stores = await Supabase.instance.client.from('stores').select('id, name').eq('is_active', true);
      List<Map<String, dynamic>> tempPerformance = [];

      for (var store in stores) {
        final transRes = await Supabase.instance.client
            .from('transactions')
            .select('quantity, total_price, product_variants(buy_price)')
            .eq('type', 'out')
            .eq('store_id', store['id'])
            .gte('created_at', todayStart);

        double storeSales = 0;
        double storeProfit = 0;
        for (var row in transRes) {
          double total = (row['total_price'] as num?)?.toDouble() ?? 0.0;
          int qty = (row['quantity'] as num?)?.toInt() ?? 0;
          
          double buyPrice = 0.0;
          final pv = row['product_variants'];
          if (pv != null) {
            if (pv is Map) buyPrice = (pv['buy_price'] as num?)?.toDouble() ?? 0.0;
            else if (pv is List && pv.isNotEmpty) buyPrice = (pv[0]['buy_price'] as num?)?.toDouble() ?? 0.0;
          }

          storeSales += total;
          storeProfit += (total - (buyPrice * qty));
        }

        final invRes = await Supabase.instance.client
            .from('inventory')
            .select('quantity, product_variants(buy_price)')
            .eq('store_id', store['id'])
            .gt('quantity', 0);

        double stockValue = 0;
        for (var i in invRes) {
          int qty = (i['quantity'] as num?)?.toInt() ?? 0;
          double buyPrice = 0.0;
          final pv = i['product_variants'];
          if (pv != null) {
            if (pv is Map) buyPrice = (pv['buy_price'] as num?)?.toDouble() ?? 0.0;
            else if (pv is List && pv.isNotEmpty) buyPrice = (pv[0]['buy_price'] as num?)?.toDouble() ?? 0.0;
          }
          stockValue += (qty * buyPrice);
        }

        tempPerformance.add({
          'id': store['id'],
          'name': store['name'],
          'today_sales': storeSales,
          'today_profit': storeProfit,
          'stock_value': stockValue,
        });
      }

      if (mounted) {
        setState(() {
          _storePerformance = tempPerformance;
        });
      }
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
    } catch (e) {}
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
                title: const Text('Scanner (Mode Propriétaire)'),
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produit introuvable.'), backgroundColor: Colors.red));
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
                    Text('Taille: ${res['size']} | Couleur: ${res['color']} | Code: $barcode', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Divider(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Prix Achat:'), Text('$buyP DA', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))]),
                          const SizedBox(height: 4),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Prix Vente:'), Text('$sellP DA', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))]),
                          const Divider(),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Marge Nette:'), Text('+$margin DA', style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold))]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Stocks par magasin:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    ...inventory.map((inv) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('• ${inv['stores']['name']}'),
                          Text('${inv['quantity']} unités', style: TextStyle(fontWeight: FontWeight.bold, color: (inv['quantity'] as int) > 0 ? Colors.green : Colors.red)),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))
              ],
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Tableau de Bord Mâitre', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh), 
            onPressed: () => _fetchDashboardData(isRefresh: true) // تحديث يدوي سريع
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _fetchDashboardData(isRefresh: true),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 20),
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Text("Santé Financière (Aujourd'hui)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(child: _buildMetricCard("Chiffre d'Affaires", "${_salesToday.toStringAsFixed(0)} DA", Icons.point_of_sale, Colors.blue)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildMetricCard("Bénéfice Net", "+${_profitToday.toStringAsFixed(0)} DA", Icons.trending_up, Colors.green)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(child: _buildMetricCard("Créances Clients", "${_customerDebt.toStringAsFixed(0)} DA", Icons.account_balance_wallet, Colors.orange)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildMetricCard("Dettes Fournisseurs", "${_supplierDebt.toStringAsFixed(0)} DA", Icons.money_off, Colors.red)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Text("Performance par Magasin", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                  ),
                  SizedBox(
                    height: 200, 
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _storePerformance.length,
                      onPageChanged: (int index) => setState(() => _currentStorePage = index),
                      itemBuilder: (context, index) {
                        final store = _storePerformance[index];
                        return _buildStoreCard(store);
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _storePerformance.asMap().entries.map((entry) {
                      return Container(
                        width: 8.0,
                        height: 8.0,
                        margin: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.indigo.withOpacity(_currentStorePage == entry.key ? 0.9 : 0.2),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  if (_lowStockAlerts.isNotEmpty) ...[
                    _buildSectionHeader("Alertes Stock Faible", Icons.warning_amber_rounded, Colors.red),
                    _buildLowStockList(),
                  ],
                  const SizedBox(height: 24),
                  _buildSectionHeader("Activités Récentes", Icons.history, Colors.indigo),
                  _buildActivityList(),
                  const SizedBox(height: 80), 
                ],
              ),
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
              IconButton(icon: const Icon(Icons.dashboard, color: Colors.indigo), onPressed: () {}),
              IconButton(icon: const Icon(Icons.inventory_2_outlined), onPressed: () {}),
              const SizedBox(width: 40),
              IconButton(icon: const Icon(Icons.analytics_outlined), onPressed: () {}),
              IconButton(icon: const Icon(Icons.person_outline), onPressed: () {}),
            ],
          ),
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
                  const Text("Ventes du jour", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text("${store['today_sales'].toStringAsFixed(0)} DA", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("Bénéfice net", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text("+${store['today_profit'].toStringAsFixed(0)} DA", style: const TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Valeur du Stock:", style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text("${store['stock_value'].toStringAsFixed(0)} DA", style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
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
            subtitle: Text("Magasin: ${alert['stores']['name']}", style: const TextStyle(fontSize: 12)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12)),
              child: Text("${alert['quantity']} restants", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
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