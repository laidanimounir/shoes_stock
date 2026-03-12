import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GestionFournisseursScreen extends StatefulWidget {
  const GestionFournisseursScreen({super.key});

  @override
  State<GestionFournisseursScreen> createState() => _GestionFournisseursScreenState();
}

class _GestionFournisseursScreenState extends State<GestionFournisseursScreen> {
  List<dynamic> _suppliers = [];
  List<dynamic> _filteredSuppliers = [];
  bool _isLoading = true;
  bool _showOnlyWithDebt = false;

  @override
  void initState() {
    super.initState();
    _fetchSuppliers();
  }

  Future<void> _fetchSuppliers() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('suppliers')
          .select()
          .eq('is_active', true) 
          .order('company_name', ascending: true);
          
      if (mounted) {
        setState(() {
          _suppliers = res;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Error fetching suppliers: $e");
    }
  }

  void _applyFilters() {
    if (_showOnlyWithDebt) {
      _filteredSuppliers = _suppliers.where((s) => (s['balance'] as num? ?? 0) > 0).toList();
    } else {
      _filteredSuppliers = List.from(_suppliers);
    }
  }

  void _showAddEditDialog([Map<String, dynamic>? supplier]) {
    final isEdit = supplier != null;
    final nameCtrl = TextEditingController(text: supplier?['company_name'] ?? '');
    final contactCtrl = TextEditingController(text: supplier?['contact_name'] ?? '');
    final phoneCtrl = TextEditingController(text: supplier?['phone'] ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Modifier le Fournisseur' : 'Nouveau Fournisseur'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nom de la société', prefixIcon: Icon(Icons.business), border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: contactCtrl,
                decoration: const InputDecoration(labelText: 'Nom du contact', prefixIcon: Icon(Icons.person), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Téléphone', prefixIcon: Icon(Icons.phone), border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              try {
          
                final Map<String, dynamic> data = {
                  'company_name': nameCtrl.text.trim(),
                  'contact_name': contactCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                };
                
                if (isEdit) {
                  await Supabase.instance.client.from('suppliers').update(data).eq('id', supplier['id']);
                } else {
                
                  data['balance'] = 0;
                  data['is_active'] = true;
                  await Supabase.instance.client.from('suppliers').insert(data);
                }
                
                _fetchSuppliers();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(isEdit ? 'Modifié avec succès.' : 'Ajouté avec succès.'),
                    backgroundColor: Colors.green,
                  ));
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            child: Text(isEdit ? 'Modifier' : 'Ajouter'),
          ),
        ],
      ),
    );
  }

 
  Future<void> _deleteSupplier(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archiver le fournisseur'),
        content: const Text('Voulez-vous masquer ce fournisseur ? (Ses anciennes factures seront conservées).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text('Archiver'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    try {
     
      await Supabase.instance.client.from('suppliers').update({'is_active': false}).eq('id', id);
      _fetchSuppliers();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fournisseur archivé.'), backgroundColor: Colors.orange));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    }
  }

  
  void _openSupplierProfile(Map<String, dynamic> supplier) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => SupplierProfileScreen(supplier: supplier)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Gestion des Fournisseurs'),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
        actions: [
        
          Row(
            children: [
              const Text("Seulement endettés", style: TextStyle(color: Colors.white)),
              Switch(
                value: _showOnlyWithDebt,
                activeColor: Colors.orange,
                onChanged: (val) {
                  setState(() {
                    _showOnlyWithDebt = val;
                    _applyFilters();
                  });
                },
              ),
            ],
          ),
          IconButton(icon: const Icon(Icons.add), tooltip: 'Ajouter', onPressed: () => _showAddEditDialog()),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredSuppliers.isEmpty
              ? Center(child: Text(_showOnlyWithDebt ? 'Aucun fournisseur avec des dettes.' : 'Aucun fournisseur.', style: const TextStyle(fontSize: 18, color: Colors.grey)))
              : ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: _filteredSuppliers.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final s = _filteredSuppliers[index];
                    final double balance = (s['balance'] as num?)?.toDouble() ?? 0.0;
                    final bool hasDebt = balance > 0;

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                        border: Border(left: BorderSide(color: hasDebt ? Colors.red : Colors.green, width: 6)), // مؤشر بصري للديون
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        onTap: () => _openSupplierProfile(s), // فتح الملف التفصيلي
                        title: Text(s['company_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        subtitle: Text('Contact: ${s['contact_name'] ?? '-'} • Tél: ${s['phone'] ?? '-'}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                      
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text("Dettes (Crédit)", style: TextStyle(fontSize: 12, color: Colors.grey)),
                                Text(
                                  '${balance.toStringAsFixed(2)} €',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: hasDebt ? Colors.red : Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 24),
                            IconButton(icon: const Icon(Icons.edit, color: Colors.orange), onPressed: () => _showAddEditDialog(s)),
                            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteSupplier(s['id'])),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// -----------------------------------------------------------------------------
// (Supplier Profile) بالتبويبات
// -----------------------------------------------------------------------------
class SupplierProfileScreen extends StatefulWidget {
  final Map<String, dynamic> supplier;
  const SupplierProfileScreen({super.key, required this.supplier});

  @override
  State<SupplierProfileScreen> createState() => _SupplierProfileScreenState();
}

class _SupplierProfileScreenState extends State<SupplierProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _invoices = [];
  List<dynamic> _payments = [];
  bool _isLoading = true;
  double _currentBalance = 0.0;

  String? _userRole;
  String? _userStoreId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentBalance = (widget.supplier['balance'] as num?)?.toDouble() ?? 0.0;
    _loadProfileAndFetch();
  }

  Future<void> _loadProfileAndFetch() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final profile = await Supabase.instance.client
            .from('user_profiles')
            .select('role, store_id')
            .eq('id', user.id)
            .single();
        _userRole = profile['role'];
        _userStoreId = profile['store_id'];
      }
    } catch (e) {
      debugPrint("Error loading user profile: $e");
    }
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    setState(() => _isLoading = true);
    final supplierId = widget.supplier['id'];
    
    try {
      var invoicesQuery = Supabase.instance.client.from('invoices')
          .select('*, user_profiles(full_name)')
          .eq('supplier_id', supplierId)
          .eq('type', 'in');

      var paymentsQuery = Supabase.instance.client.from('payments')
          .select('*, user_profiles(full_name)')
          .eq('supplier_id', supplierId);

      // Employee: filter by store_id
      if (_userRole == 'employee' && _userStoreId != null) {
        invoicesQuery = invoicesQuery.eq('store_id', _userStoreId!);
        paymentsQuery = paymentsQuery.eq('store_id', _userStoreId!);
      }

      final invoicesRes = await invoicesQuery.order('created_at', ascending: false);
      final paymentsRes = await paymentsQuery.order('payment_date', ascending: false);

      if (mounted) {
        setState(() {
          _invoices = invoicesRes;
          _payments = paymentsRes;

          if (_userRole == 'employee' && _userStoreId != null) {
            // Employee: compute balance from filtered invoices/payments
            double totalInvoiced = 0.0;
            for (var inv in _invoices) {
              totalInvoiced += (inv['total_amount'] as num?)?.toDouble() ?? 0.0;
            }
            double totalPaid = 0.0;
            for (var pay in _payments) {
              totalPaid += (pay['amount'] as num?)?.toDouble() ?? 0.0;
            }
            _currentBalance = totalInvoiced - totalPaid;
          } else {
            // Owner: read global balance from DB
            _fetchGlobalBalance(supplierId);
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Error fetching profile: $e");
    }
  }

  Future<void> _fetchGlobalBalance(String supplierId) async {
    try {
      final balanceRes = await Supabase.instance.client.from('suppliers')
          .select('balance')
          .eq('id', supplierId)
          .single();
      if (mounted) {
        setState(() {
          _currentBalance = (balanceRes['balance'] as num?)?.toDouble() ?? 0.0;
        });
      }
    } catch (e) {
      debugPrint("Error fetching global balance: $e");
    }
  }

  
  void _showAddPaymentDialog() {
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouveau Versement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Dette actuelle: ${_currentBalance.toStringAsFixed(2)} €", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 16),
            TextFormField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Montant versé', border: OutlineInputBorder(), prefixIcon: Icon(Icons.euro)),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes / Motif', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text);
              if (amount == null || amount <= 0) return;
              Navigator.pop(ctx);
              
              try {
                final user = Supabase.instance.client.auth.currentUser;
             
                await Supabase.instance.client.from('payments').insert({
                  'supplier_id': widget.supplier['id'],
                  'user_id': user?.id,
                  'amount': amount,
                  'payment_method': 'cash',
                  'notes': notesCtrl.text.isEmpty ? 'Versement manuel' : notesCtrl.text,
                });
                
                _fetchProfileData();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Versement enregistré.'), backgroundColor: Colors.green));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            child: const Text('Confirmer le paiement', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.supplier['company_name']),
        backgroundColor: Colors.teal[900],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.orange,
          tabs: const [
            Tab(icon: Icon(Icons.receipt), text: "Factures d'achat"),
            Tab(icon: Icon(Icons.payments), text: "Historique des Versements"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildInvoicesTab(),
                _buildPaymentsTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPaymentDialog,
        backgroundColor: Colors.orange,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Verser un montant", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildInvoicesTab() {
    if (_invoices.isEmpty) return const Center(child: Text("Aucune facture d'achat pour ce fournisseur."));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _invoices.length,
      itemBuilder: (context, index) {
        final inv = _invoices[index];
        final total = (inv['total_amount'] as num?)?.toDouble() ?? 0;
        final paid = (inv['paid_amount'] as num?)?.toDouble() ?? 0;
        final date = DateTime.parse(inv['created_at']).toLocal();
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.receipt, color: Colors.white)),
            title: Text(inv['invoice_number'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${date.day}/${date.month}/${date.year} • Par: ${inv['user_profiles']['full_name']}"),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("Total: ${total.toStringAsFixed(2)} €", style: const TextStyle(fontWeight: FontWeight.bold)),
                Text("Payé: ${paid.toStringAsFixed(2)} €", style: TextStyle(color: paid < total ? Colors.red : Colors.green, fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentsTab() {
    if (_payments.isEmpty) return const Center(child: Text("Aucun versement enregistré."));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _payments.length,
      itemBuilder: (context, index) {
        final pay = _payments[index];
        final amount = (pay['amount'] as num?)?.toDouble() ?? 0;
        final date = DateTime.parse(pay['payment_date']).toLocal();
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.monetization_on, color: Colors.white)),
            title: Text("Versement de ${amount.toStringAsFixed(2)} €", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            subtitle: Text("${date.day}/${date.month}/${date.year} • Motif: ${pay['notes']}"),
          ),
        );
      },
    );
  }
}