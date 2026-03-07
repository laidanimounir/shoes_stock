import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  
  List<dynamic> _stores = [];
  String? _selectedStoreId; 


  double _todaySales = 0.0;
  double _todayProfit = 0.0;
  double _customerDebt = 0.0;
  double _supplierDebt = 0.0;
  
 
  double _stockValue = 0.0;
  int _activeCustomers = 0;
  int _activeSuppliers = 0;

  @override
  void initState() {
    super.initState();
    _initDashboard();
  }

  Future<void> _initDashboard() async {
    await _fetchStores();
    await _fetchDashboardStats();
  }

  Future<void> _fetchStores() async {
    try {
      final res = await Supabase.instance.client
          .from('stores')
          .select()
          .eq('is_active', true)
          .order('name');
      if (mounted) {
        setState(() {
          _stores = res;
       
          _selectedStoreId = null; 
        });
      }
    } catch (e) {
      debugPrint('Error fetching stores: $e');
    }
  }

  Future<void> _fetchDashboardStats() async {
    setState(() => _isLoading = true);
    
    try {
 
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();
      
      var transQuery = Supabase.instance.client
          .from('transactions')
          .select('quantity, total_price, product_variants(buy_price)')
          .eq('type', 'out')
          .gte('created_at', startOfDay);
          
      if (_selectedStoreId != null) {
        transQuery = transQuery.eq('store_id', _selectedStoreId!);
      }
      
      final transRes = await transQuery;
      
      double sales = 0;
      double profit = 0;
      
      for (var t in transRes) {
        double totalPrice = (t['total_price'] as num?)?.toDouble() ?? 0.0;
        int qty = (t['quantity'] as num?)?.toInt() ?? 0;
        double buyPrice = (t['product_variants']?['buy_price'] as num?)?.toDouble() ?? 0.0;
        
        sales += totalPrice;
       
        double cost = buyPrice * qty;
        profit += (totalPrice - cost);
      }

    
      final custRes = await Supabase.instance.client.from('customers').select('balance').eq('is_active', true);
      double cDebt = custRes.fold(0.0, (sum, c) => sum + ((c['balance'] as num?)?.toDouble() ?? 0.0));

   
      final suppRes = await Supabase.instance.client.from('suppliers').select('balance').eq('is_active', true);
      double sDebt = suppRes.fold(0.0, (sum, s) => sum + ((s['balance'] as num?)?.toDouble() ?? 0.0));


      var invQuery = Supabase.instance.client
          .from('inventory')
          .select('quantity, product_variants(buy_price)')
          .gt('quantity', 0);
          
      if (_selectedStoreId != null) {
        invQuery = invQuery.eq('store_id', _selectedStoreId!);
      }
      
      final invRes = await invQuery;
      double stockVal = 0;
      for (var i in invRes) {
        int qty = (i['quantity'] as num?)?.toInt() ?? 0;
        double buyPrice = (i['product_variants']?['buy_price'] as num?)?.toDouble() ?? 0.0;
        stockVal += (qty * buyPrice);
      }

      if (mounted) {
        setState(() {
          _todaySales = sales;
          _todayProfit = profit;
          _customerDebt = cDebt;
          _supplierDebt = sDebt;
          _stockValue = stockVal;
          _activeCustomers = custRes.length;
          _activeSuppliers = suppRes.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching dashboard stats: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Tableau de Bord (Vue d\'ensemble)'),
        backgroundColor: Colors.indigo[800],
        foregroundColor: Colors.white,
        actions: [
   
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedStoreId,
                dropdownColor: Colors.indigo[800],
                icon: const Icon(Icons.store, color: Colors.white),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Tous les magasins (Global)')),
                  ..._stores.map((s) => DropdownMenuItem(value: s['id'] as String?, child: Text(s['name']))),
                ],
                onChanged: (val) {
                  setState(() => _selectedStoreId = val);
                  _fetchDashboardStats();
                },
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchDashboardStats),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
               
                  const Text('Indicateurs Financiers', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _buildKpiCard('Chiffre d\'affaires (Aujourd\'hui)', '$_todaySales DA', Icons.point_of_sale, Colors.blue),
                      _buildKpiCard('Bénéfice Net (Aujourd\'hui)', '+$_todayProfit DA', Icons.trending_up, Colors.green),
                      _buildKpiCard('Créances Clients (Crédits)', '$_customerDebt DA', Icons.account_balance_wallet, Colors.orange),
                      _buildKpiCard('Dettes Fournisseurs', '$_supplierDebt DA', Icons.money_off, Colors.red),
                    ],
                  ),
                  
                  const SizedBox(height: 48),

              
                  const Text('Statistiques du Magasin', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _buildKpiCard('Valeur Globale du Stock', '$_stockValue DA', Icons.inventory, Colors.teal),
                      _buildKpiCard('Clients Actifs', '$_activeCustomers', Icons.people, Colors.purple),
                      _buildKpiCard('Fournisseurs Actifs', '$_activeSuppliers', Icons.local_shipping, Colors.brown),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 280, 
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border(left: BorderSide(color: color, width: 6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis)),
              CircleAvatar(backgroundColor: color.withOpacity(0.1), radius: 18, child: Icon(icon, color: color, size: 20)),
            ],
          ),
          const SizedBox(height: 16),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}