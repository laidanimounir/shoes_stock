import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../desktop/refund_modal.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final supabase = Supabase.instance.client;
  List<dynamic> _sales = [];
  List<dynamic> _stores = [];
  bool _isLoading = true;
  
  String? _userRole;
  String? _userStoreId;
  String? _filterStoreId; 

  @override
  void initState() {
    super.initState();
    _initAndFetch();
  }

  Future<void> _initAndFetch() async {
    try {
      final user = supabase.auth.currentUser;
      final profile = await supabase.from('user_profiles').select().eq('id', user!.id).single();
      
      _userRole = profile['role'];
      _userStoreId = profile['store_id'];

      if (_userRole == 'owner') {
        _stores = await supabase.from('stores').select('id, name').order('name');
      } else {
        _filterStoreId = _userStoreId; 
      }
      await _fetchSales();
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> _fetchSales() async {
    setState(() => _isLoading = true);
    try {
    
      var query = supabase.from('transactions').select('''
        id, invoice_number, invoice_id, quantity, total_price, created_at, type,
        product_variants(id, products(name), size, color),
        customers(full_name),
        stores(name),
        invoices(status)
      ''').eq('type', 'out'); 

      if (_filterStoreId != null) {
        query = query.eq('store_id', _filterStoreId!);
      }

      final res = await query.order('created_at', ascending: false);
      setState(() {
        _sales = res;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Historique des Ventes'),
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
        actions: [
          if (_userRole == 'owner')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DropdownButton<String?>(
                dropdownColor: Colors.indigo[800],
                style: const TextStyle(color: Colors.white),
                underline: const SizedBox(),
                value: _filterStoreId,
                hint: const Text("Tous les Magasins", style: TextStyle(color: Colors.white70)),
                items: [
                  const DropdownMenuItem(value: null, child: Text("Tous les Magasins")),
                  ..._stores.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name'] as String))),
                ],
                onChanged: (val) {
                  setState(() => _filterStoreId = val);
                  _fetchSales();
                },
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sales.isEmpty
              ? const Center(child: Text("Aucune vente trouvée."))
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: _sales.length,
                  itemBuilder: (context, index) {
                    final s = _sales[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const Icon(Icons.receipt, color: Colors.indigo),
                        title: Text("${s['product_variants']['products']['name']} (${s['product_variants']['size']})"),
                        subtitle: Text(
                          "Facture: ${s['invoice_number']}\n"
                          "Client: ${s['customers']?['full_name'] ?? 'Passager'} | Magasin: ${s['stores']['name']}",
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("${s['total_price']} DA", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            if (s['invoices']?['status'] == 'paid') ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.assignment_return, color: Colors.red),
                                tooltip: "إرجاع",
                                onPressed: () async {
                                  final result = await showDialog(
                                    context: context,
                                    builder: (_) => RefundModal(invoice: s),
                                  );
                                  if (result == true) {
                                    _fetchSales();
                                  }
                                },
                              ),
                            ]
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}