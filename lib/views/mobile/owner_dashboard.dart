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
  double _salesToday = 0;
  double _salesMonth = 0;
  
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
            _fetchActivities(); // Refresh feed on new insert
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    Supabase.instance.client.removeChannel(_activitySubscription);
    super.dispose();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchSales(),
      _fetchLowStock(),
      _fetchActivities(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchSales() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
      final monthStart = DateTime(now.year, now.month, 1).toIso8601String();

      // Today Sales
      final todayRes = await Supabase.instance.client
          .from('transactions')
          .select('total_price')
          .eq('type', 'out')
          .gte('created_at', todayStart);
          
      double todayTotal = 0;
      for (var row in todayRes) {
        todayTotal += (row['total_price'] as num).toDouble();
      }

      // Month Sales
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
      debugPrint("Error fetching sales: $e");
    }
  }

  Future<void> _fetchLowStock() async {
    try {
      final res = await Supabase.instance.client
          .from('inventory')
          .select('quantity, stores(name), product_variants(size, color, barcode, products(name, image_url))')
          .lt('quantity', 3)
          .order('quantity', ascending: true)
          .limit(10);
          
      if (mounted) {
        setState(() {
          _lowStockAlerts = res;
        });
      }
    } catch (e) {
      debugPrint("Error fetching low stock: $e");
    }
  }

  Future<void> _fetchActivities() async {
    try {
      final res = await Supabase.instance.client
          .from('activity_logs')
          .select('*, user_profiles(full_name, role)')
          .order('created_at', ascending: false)
          .limit(15);
          
      if (mounted) {
        setState(() {
          _recentActivities = res;
        });
      }
    } catch (e) {
      debugPrint("Error fetching activities: $e");
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
                title: const Text('Scanner le Code-barres'),
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

      if (mounted) Navigator.pop(context); // Close loading dialog

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
                  Text('Taille: ${res['size']}'),
                  Text('Couleur: ${res['color']}'),
                  Text('Code-barres: $barcode', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(),
                  const Text('Stocks:', style: TextStyle(fontWeight: FontWeight.bold)),
                   ...inventory.map((inv) {
                     return Text('- ${inv['stores']['name']}: ${inv['quantity']} unités');
                   }),
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
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Tableau de bord (Propriétaire)'),
        backgroundColor: Colors.indigo[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDashboardData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Supabase.instance.client.auth.signOut(),
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchDashboardData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // --- SALES CARDS ---
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: "Ventes Aujourd'hui",
                          value: "${_salesToday.toStringAsFixed(2)} €",
                          icon: Icons.point_of_sale,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildMetricCard(
                          title: "Ventes du Mois",
                          value: "${_salesMonth.toStringAsFixed(2)} €",
                          icon: Icons.calendar_month,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // --- ALERTS ---
                  if (_lowStockAlerts.isNotEmpty) ...[
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Alertes Stock Faible (< 3)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _lowStockAlerts.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final alert = _lowStockAlerts[index];
                          final prodName = alert['product_variants']['products']['name'];
                          final size = alert['product_variants']['size'];
                          final store = alert['stores']['name'];
                          final qty = alert['quantity'];
                          
                          return ListTile(
                            leading: const CircleAvatar(backgroundColor: Colors.redAccent, child: Icon(Icons.inventory, color: Colors.white, size: 20)),
                            title: Text('$prodName (Taille: $size)'),
                            subtitle: Text('Magasin: $store'),
                            trailing: Text('$qty en stock', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16)),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // --- ACTIVITY FEED ---
                  const Row(
                    children: [
                      Icon(Icons.history, color: Colors.indigo),
                      SizedBox(width: 8),
                      Text('Activités Récentes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: _recentActivities.isEmpty
                        ? const Padding(padding: EdgeInsets.all(24), child: Center(child: Text("Aucune activité récente.")))
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _recentActivities.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final log = _recentActivities[index];
                              final date = DateTime.parse(log['created_at']);
                              final user = log['user_profiles']?['full_name'] ?? 'Inconnu';
                              final action = log['action_type'];
                              
                              IconData icon = Icons.info_outline;
                              Color color = Colors.grey;
                              
                              if (action == 'SALE' || action == 'out') {
                                icon = Icons.shopping_cart_checkout;
                                color = Colors.green;
                              } else if (action == 'UPDATE_TRANSACTION') {
                                icon = Icons.edit;
                                color = Colors.orange;
                              } else if (action == 'DELETE_TRANSACTION') {
                                icon = Icons.delete;
                                color = Colors.red;
                              }
                              
                              return ListTile(
                                leading: Icon(icon, color: color),
                                title: Text(log['description'], style: const TextStyle(fontSize: 14)),
                                subtitle: Text('$user • ${timeago.format(date, locale: 'fr')}'),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 80), // Padding for FloatingActionButton
                ],
              ),
            ),
            
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scanBarcode,
        backgroundColor: Colors.indigo[800],
        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
        label: const Text("Scanner un Produit", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildMetricCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border(bottom: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueGrey[900])),
        ],
      ),
    );
  }
}
