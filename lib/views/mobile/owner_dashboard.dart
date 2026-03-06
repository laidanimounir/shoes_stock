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
  // البيانات العامة للمقاييس
  double _salesToday = 0;
  double _salesMonth = 0;

  // بيانات المتاجر للكاروسيل
  List<Map<String, dynamic>> _storePerformance = [];
  int _currentStorePage = 0;
  final PageController _pageController = PageController(viewportFraction: 0.85);

  // القوائم الأخرى
  List<dynamic> _lowStockAlerts = [];
  List<dynamic> _recentActivities = [];

  bool _isLoading = true;
  late final RealtimeChannel _activitySubscription;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('fr', timeago.FrMessages());
    _fetchDashboardData();
    _setupRealtime();
  }

  void _setupRealtime() {
    _activitySubscription = Supabase.instance.client
        .channel('public:activity_logs')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'activity_logs',
          callback: (payload) {
            _fetchActivities(); // تحديث السجل عند إضافة نشاط جديد
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    Supabase.instance.client.removeChannel(_activitySubscription);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    await Future.wait([
      _fetchOverallSales(),
      _fetchStorePerformance(),
      _fetchLowStock(),
      _fetchActivities(),
    ]);

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchOverallSales() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
      final monthStart = DateTime(now.year, now.month, 1).toIso8601String();

      // إجمالي مبيعات اليوم (كل المتاجر)
      final todayRes = await Supabase.instance.client
          .from('transactions')
          .select('total_price')
          .eq('type', 'out')
          .gte('created_at', todayStart);

      double todayTotal = 0;
      for (var row in todayRes) {
        todayTotal += (row['total_price'] as num).toDouble();
      }

      // إجمالي مبيعات الشهر (كل المتاجر)
      final monthRes = await Supabase.instance.client
          .from('transactions')
          .select('total_price')
          .eq('type', 'out')
          .gte('created_at', monthStart);

      double monthTotal = 0;
      for (var row in monthRes) {
        monthTotal += (row['total_price'] as num).toDouble();
      }

      if (mounted) {
        setState(() {
          _salesToday = todayTotal;
          _salesMonth = monthTotal;
        });
      }
    } catch (e) {
      debugPrint("Error overall sales: $e");
    }
  }

  Future<void> _fetchStorePerformance() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();

      // 1. جلب قائمة المتاجر
      final stores = await Supabase.instance.client.from('stores').select('id, name');
      
      List<Map<String, dynamic>> tempPerformance = [];

      for (var store in stores) {
        // 2. حساب مبيعات كل متجر لليوم
        final res = await Supabase.instance.client
            .from('transactions')
            .select('total_price')
            .eq('type', 'out')
            .eq('store_id', store['id'])
            .gte('created_at', todayStart);

        double total = 0;
        for (var row in res) {
          total += (row['total_price'] as num).toDouble();
        }

        tempPerformance.add({
          'id': store['id'],
          'name': store['name'],
          'today_sales': total,
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
    } catch (e) {
      debugPrint("Error low stock: $e");
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
    } catch (e) {
      debugPrint("Error activities: $e");
    }
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
                title: const Text('Scanner un Produit'),
                automaticallyImplyLeading: false,
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Produit introuvable.'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) {
            final inventory = res['inventory'] as List<dynamic>? ?? [];
            return AlertDialog(
              title: Text(res['products']['name']),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (res['products']['image_url'] != null)
                    Center(child: Image.network(res['products']['image_url'], height: 100)),
                  const SizedBox(height: 16),
                  Text('Taille: ${res['size']} | Couleur: ${res['color']}'),
                  const Divider(),
                  const Text('État des Stocks:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...inventory.map((inv) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• ${inv['stores']['name']}: ${inv['quantity']} unités'),
                  )),
                ],
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
        title: const Text('Tableau de Bord Mâitre'),
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchDashboardData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchDashboardData,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 20),
                children: [
                  // --- CAROUSEL DES MAGASINS ---
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Text("Performance par Magasin", 
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                  ),
                  SizedBox(
                    height: 170,
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
                  
                  // Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _storePerformance.asMap().entries.map((entry) {
                      return Container(
                        width: 7.0,
                        height: 7.0,
                        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.indigo.withOpacity(_currentStorePage == entry.key ? 0.9 : 0.2),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  // --- GLOBAL METRICS ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(child: _buildMetricCard("Aujourd'hui", "${_salesToday.toStringAsFixed(2)} €", Icons.today, Colors.green)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildMetricCard("Ce Mois", "${_salesMonth.toStringAsFixed(2)} €", Icons.calendar_month, Colors.blue)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- LOW STOCK SECTION ---
                  if (_lowStockAlerts.isNotEmpty) ...[
                    _buildSectionHeader("Alertes Stock Faible", Icons.warning_amber_rounded, Colors.red),
                    _buildLowStockList(),
                  ],

                  const SizedBox(height: 24),

                  // --- ACTIVITY FEED ---
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
              const SizedBox(width: 40), // Space for FAB
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
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(store['name'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const Icon(Icons.storefront, color: Colors.white60),
            ],
          ),
          const Spacer(),
          const Text("Recettes du jour", style: TextStyle(color: Colors.white70, fontSize: 13)),
          Text("${store['today_sales'].toStringAsFixed(2)} €", 
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
            title: Text("${alert['product_variants']['products']['name']} (${alert['product_variants']['size']})"),
            subtitle: Text("Magasin: ${alert['stores']['name']}"),
            trailing: Text("${alert['quantity']} restants", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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
            leading: const Icon(Icons.notifications_none, size: 20),
            title: Text(log['description'], style: const TextStyle(fontSize: 13)),
            subtitle: Text("${log['user_profiles']['full_name']} • ${timeago.format(date, locale: 'fr')}"),
          );
        },
      ),
    );
  }
}