import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GestionEmployesScreen extends StatefulWidget {
  const GestionEmployesScreen({super.key});

  @override
  State<GestionEmployesScreen> createState() => _GestionEmployesScreenState();
}

class _GestionEmployesScreenState extends State<GestionEmployesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  
  bool _isLoading = false;
  List<dynamic> _stores = [];
  String? _selectedStoreId;

  List<dynamic> _employees = [];
  bool _isLoadingEmployees = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  String? _userRole;

  Future<void> _fetchData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final profile = await Supabase.instance.client
            .from('user_profiles')
            .select('role')
            .eq('id', user.id)
            .single();
        if (mounted) setState(() => _userRole = profile['role']);
      }
    } catch (_) {}

    await Future.wait([
      _fetchStores(),
      _fetchEmployees(),
    ]);
  }

  Future<void> _fetchStores() async {
    try {
      final response = await Supabase.instance.client.from('stores').select();
      if (mounted) {
        setState(() {
          _stores = response;
          if (_stores.isNotEmpty && _selectedStoreId == null) {
            _selectedStoreId = _stores.first['id'];
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching stores: $e");
    }
  }

  Future<void> _fetchEmployees() async {
    setState(() => _isLoadingEmployees = true);
    try {
      final response = await Supabase.instance.client
          .from('user_profiles')
          .select('*, stores(name)')
          .eq('role', 'employee')
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _employees = response;
          _isLoadingEmployees = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingEmployees = false);
      }
      debugPrint("Error fetching employees: $e");
    }
  }

  Future<void> _createEmployee() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStoreId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Veuillez sélectionner un magasin.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _isLoading = true);

    final session = Supabase.instance.client.auth.currentSession;

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'create_employee',
        headers: {
          'Authorization': 'Bearer ${session?.accessToken}'
        },
        body: {
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'full_name': _nameController.text.trim(),
          'store_id': _selectedStoreId,
        },
      );

      if (response.status == 200 && response.data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Employé créé avec succès !'), backgroundColor: Colors.green),
          );
          _formKey.currentState!.reset();
          _emailController.clear();
          _passwordController.clear();
          _nameController.clear();
          _fetchEmployees(); // Refresh the list
        }
      } else {
        final errorMsg = response.data['error']?.toString().toLowerCase() ?? '';
        if (errorMsg.contains('already registered') || errorMsg.contains('email exists')) {
          throw Exception('already_exists');
        } else {
          throw Exception(errorMsg);
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = "Erreur: $e";
        if (e.toString().contains('already_exists')) {
          errorMessage = "Cet e-mail est déjà utilisé.";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteEmployee(String employeeId) async {
    // Confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Voulez-vous vraiment supprimer cet employé ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final session = Supabase.instance.client.auth.currentSession;

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'delete_employee',
        headers: {
          'Authorization': 'Bearer ${session?.accessToken}'
        },
        body: {'employee_id': employeeId},
      );

      if (response.status == 200 && response.data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Employé supprimé avec succès.'), backgroundColor: Colors.green),
          );
          _fetchEmployees(); // Refresh the list
        }
      } else {
        throw Exception(response.data['error'] ?? 'Erreur inconnue');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la suppression : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Gestion des Employés'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left side: Create Employee Form
          if (_userRole == 'owner')
            Expanded(
              flex: 1,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, spreadRadius: 2),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          "Ajouter un employé",
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: 'Nom complet', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                          validator: (v) => v!.isEmpty ? 'Ce champ est requis' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(labelText: 'Adresse e-mail', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) => v!.isEmpty || !v.contains('@') ? 'Email invalide' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          decoration: const InputDecoration(labelText: 'Mot de passe', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
                          obscureText: true,
                          // No password strength restrictions requested
                          validator: (v) => v!.isEmpty ? 'Ce champ est requis' : null,
                        ),
                        const SizedBox(height: 16),
                        if (_stores.isNotEmpty)
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _selectedStoreId,
                            decoration: const InputDecoration(labelText: 'Affecter au magasin', border: OutlineInputBorder(), prefixIcon: Icon(Icons.store)),
                            items: _stores.map((store) {
                              return DropdownMenuItem<String>(
                                value: store['id'],
                                child: Text(store['name']),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedStoreId = val),
                          )
                        else
                          const Center(child: CircularProgressIndicator()),
                        const SizedBox(height: 32),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _createEmployee,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: _isLoading
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Créer l\'employé', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          
          // Right side: Employee List
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.only(top: 24, right: 24, bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, spreadRadius: 2),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.black12)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.people_alt, color: Colors.blueAccent),
                        SizedBox(width: 12),
                        Text(
                          "Liste des employés",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _isLoadingEmployees
                        ? const Center(child: CircularProgressIndicator())
                        : _employees.isEmpty
                            ? const Center(child: Text("Aucun employé trouvé."))
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: _employees.length,
                                separatorBuilder: (context, index) => const Divider(),
                                itemBuilder: (context, index) {
                                  final emp = _employees[index];
                                  final storeName = emp['stores']?['name'] ?? 'Aucun magasin';
                                  
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.blue[50],
                                      child: const Icon(Icons.person, color: Colors.blueAccent),
                                    ),
                                    title: Text(emp['full_name'] ?? 'Inconnu', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text('Magasin: $storeName\nAjouté le: ${emp['created_at'].toString().split('T')[0]}'),
                                    isThreeLine: true,
                                    trailing: _userRole == 'owner' ? IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      tooltip: 'Supprimer',
                                      onPressed: () => _deleteEmployee(emp['id']),
                                    ) : null,
                                  );
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
