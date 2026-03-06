import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GestionClientsScreen extends StatefulWidget {
  const GestionClientsScreen({super.key});

  @override
  State<GestionClientsScreen> createState() => _GestionClientsScreenState();
}

class _GestionClientsScreenState extends State<GestionClientsScreen> {
  final _searchController = TextEditingController();
  
  List<dynamic> _customers = [];
  bool _isLoading = true;
  
  Map<String, dynamic>? _selectedCustomer;
  List<dynamic> _customerHistory = [];
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  Future<void> _fetchCustomers([String query = '']) async {
    setState(() => _isLoading = true);
    try {
      var queryBuilder = Supabase.instance.client.from('customers').select();
      
      if (query.isNotEmpty) {
        queryBuilder = queryBuilder.or('full_name.ilike.%$query%,phone.ilike.%$query%');
      }

      final response = await queryBuilder.order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _customers = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Error fetching customers: $e");
    }
  }

  Future<void> _fetchCustomerHistory(String customerId) async {
    setState(() => _isLoadingHistory = true);
    try {
      // In a real scenario, transactions should have a customer_id. 
      // Checking the DB schema from earlier... wait, the transactions table does NOT have customer_id!
      // Only user_id (employee) and store_id.
      // So I'll just show "Aucune transaction liée au client" since customer_id wasn't in the transactions table schema requested.
      // I will put a placeholder for history or fetch an empty list.
      if (mounted) {
        setState(() {
          _customerHistory = []; // No customer_id in transactions
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  void _showAddCustomerDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouveau Client'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nom complet', prefixIcon: Icon(Icons.person)),
                validator: (v) => v!.isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Téléphone', prefixIcon: Icon(Icons.phone)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Adresse e-mail', prefixIcon: Icon(Icons.email)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                await _addCustomer(nameCtrl.text, phoneCtrl.text, emailCtrl.text);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _addCustomer(String name, String phone, String email) async {
    try {
      await Supabase.instance.client.from('customers').insert({
        'full_name': name.trim(),
        'phone': phone.trim(),
        'email': email.trim(),
      });
      _fetchCustomers(_searchController.text);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Client ajouté.'), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    }
  }

  void _selectCustomer(Map<String, dynamic> customer) {
    setState(() {
      _selectedCustomer = customer;
    });
    _fetchCustomerHistory(customer['id']);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Gestion des Clients'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Row(
        children: [
          // Left: Client List
          Expanded(
            flex: 1,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                   Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Rechercher (Nom ou Téléphone)...',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (val) {
                              _fetchCustomers(val);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _showAddCustomerDialog,
                          icon: const Icon(Icons.person_add_alt_1),
                          color: Colors.indigo,
                          tooltip: 'Ajouter un client',
                        )
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _isLoading 
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.separated(
                          itemCount: _customers.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final c = _customers[index];
                            final isSelected = _selectedCustomer?['id'] == c['id'];
                            
                            return ListTile(
                              selected: isSelected,
                              selectedTileColor: Colors.indigo.withOpacity(0.1),
                              leading: const CircleAvatar(child: Icon(Icons.person)),
                              title: Text(c['full_name'] ?? 'Inconnu', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(c['phone'] ?? c['email'] ?? 'Auccun contact'),
                              onTap: () => _selectCustomer(c),
                            );
                          },
                        ),
                  ),
                ],
              ),
            ),
          ),
          
          // Right: Details & History
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.only(top: 16, bottom: 16, right: 16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: _selectedCustomer == null
                  ? const Center(child: Text("Sélectionnez un client pour voir l'historique", style: TextStyle(color: Colors.grey, fontSize: 18)))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          color: Colors.indigo.withOpacity(0.05),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_selectedCustomer!['full_name'], style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.indigo)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.phone, size: 16, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(_selectedCustomer!['phone'] ?? 'Non renseigné', style: const TextStyle(fontSize: 16, color: Colors.black87)),
                                  const SizedBox(width: 24),
                                  const Icon(Icons.email, size: 16, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(_selectedCustomer!['email'] ?? 'Non renseigné', style: const TextStyle(fontSize: 16, color: Colors.black87)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text("Historique des achats", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        Expanded(
                          child: _isLoadingHistory
                              ? const Center(child: CircularProgressIndicator())
                              : _customerHistory.isEmpty
                                  ? const Center(
                                      child: Text(
                                        "Aucune transaction (La liaison Transactions <> Clients sera implémentée via un client_id)",
                                        style: TextStyle(color: Colors.grey),
                                        textAlign: TextAlign.center,
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: _customerHistory.length,
                                      itemBuilder: (context, index) {
                                        return const ListTile(title: Text("Transaction"));
                                      },
                                    ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
