import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GestionFournisseursScreen extends StatefulWidget {
  const GestionFournisseursScreen({super.key});

  @override
  State<GestionFournisseursScreen> createState() => _GestionFournisseursScreenState();
}

class _GestionFournisseursScreenState extends State<GestionFournisseursScreen> {
  List<dynamic> _suppliers = [];
  bool _isLoading = true;

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
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _suppliers = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Error: $e");
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
                final data = {
                  'company_name': nameCtrl.text.trim(),
                  'contact_name': contactCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                };
                if (isEdit) {
                  await Supabase.instance.client.from('suppliers').update(data).eq('id', supplier!['id']);
                } else {
                  await Supabase.instance.client.from('suppliers').insert(data);
                }
                _fetchSuppliers();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(isEdit ? 'Fournisseur modifié.' : 'Fournisseur ajouté.'),
                    backgroundColor: Colors.green,
                  ));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
                }
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
        title: const Text('Confirmer la suppression'),
        content: const Text('Voulez-vous vraiment supprimer ce fournisseur ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await Supabase.instance.client.from('suppliers').delete().eq('id', id);
      _fetchSuppliers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fournisseur supprimé.'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Gestion des Fournisseurs'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.add), tooltip: 'Ajouter un fournisseur', onPressed: () => _showAddEditDialog()),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _suppliers.isEmpty
              ? const Center(child: Text('Aucun fournisseur. Appuyez sur + pour en ajouter.', style: TextStyle(fontSize: 18, color: Colors.grey)))
              : ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: _suppliers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final s = _suppliers[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal[50],
                          child: const Icon(Icons.local_shipping, color: Colors.teal),
                        ),
                        title: Text(s['company_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        subtitle: Text('Contact: ${s['contact_name'] ?? 'N/A'} • Tél: ${s['phone'] ?? 'N/A'}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
