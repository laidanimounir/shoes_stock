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

  @override
  void initState() {
    super.initState();
    _fetchStores();
  }

  Future<void> _fetchStores() async {
    final response = await Supabase.instance.client.from('stores').select();
    setState(() {
      _stores = response;
      if (_stores.isNotEmpty) {
        _selectedStoreId = _stores.first['id'];
      }
    });
  }

  Future<void> _createEmployee() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStoreId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez sélectionner un magasin.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'create_employee',
        body: {
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'full_name': _nameController.text.trim(),
          'store_id': _selectedStoreId,
        },
      );

      if (response.status == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Employé créé avec succès !'), backgroundColor: Colors.green),
          );
          _formKey.currentState!.reset();
        }
      } else {
        throw Exception(response.data['error'] ?? 'Erreur inconnue');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la création : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      appBar: AppBar(
        title: const Text('Gestion des Employés'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, spreadRadius: 2),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Créer un nouvel employé",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Nom complet', border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Ce champ est requis' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v!.isEmpty || !v.contains('@') ? 'Email invalide' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Mot de passe temp.', border: OutlineInputBorder()),
                    obscureText: true,
                    validator: (v) => v!.length < 6 ? 'Minimum 6 caractères' : null,
                  ),
                  const SizedBox(height: 16),
                  if (_stores.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: _selectedStoreId,
                      decoration: const InputDecoration(labelText: 'Affecter au magasin', border: OutlineInputBorder()),
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
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Créer l\'employé', style: TextStyle(fontSize: 16)),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
