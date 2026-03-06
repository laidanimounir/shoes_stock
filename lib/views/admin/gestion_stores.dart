import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GestionStoresScreen extends StatefulWidget {
  const GestionStoresScreen({super.key});

  @override
  State<GestionStoresScreen> createState() => _GestionStoresScreenState();
}

class _GestionStoresScreenState extends State<GestionStoresScreen> {
  List<dynamic> _stores = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStores();
  }

  Future<void> _fetchStores() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('stores')
          .select()
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _stores = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Error fetching stores: $e");
    }
  }

  void _showAddEditDialog([Map<String, dynamic>? store]) {
    final isEdit = store != null;
    final nameCtrl = TextEditingController(text: store?['name'] ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(isEdit ? Icons.edit : Icons.add_business, color: Colors.indigo),
            const SizedBox(width: 12),
            Text(isEdit ? 'Modifier Magasin' : 'Nouveau Magasin'),
          ],
        ),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 400,
            child: TextFormField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nom du Magasin',
                prefixIcon: Icon(Icons.warehouse),
                border: OutlineInputBorder(),
              ),
              validator: (v) => v!.trim().isEmpty ? 'Ce champ est obligatoire' : null,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              try {
                final data = {'name': nameCtrl.text.trim()};
                if (isEdit) {
                  await Supabase.instance.client
                      .from('stores')
                      .update(data)
                      .eq('id', store['id']);
                } else {
                  await Supabase.instance.client
                      .from('stores')
                      .insert(data);
                }
                _fetchStores();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(isEdit ? 'Magasin modifié avec succès.' : 'Magasin ajouté avec succès.'),
                    backgroundColor: Colors.green,
                  ));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Erreur: $e'),
                    backgroundColor: Colors.red,
                  ));
                }
              }
            },
            icon: Icon(isEdit ? Icons.save : Icons.add),
            label: Text(isEdit ? 'Enregistrer' : 'Ajouter'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteStore(Map<String, dynamic> store) async {
    // Check if store has employees or inventory
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 12),
            Text('Confirmer la suppression'),
          ],
        ),
        content: Text("Voulez-vous supprimer le magasin '${store['name']}'?\\n\\nLe magasin ne sera supprimé que s'il n'est pas lié à des employés ou à du stock."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await Supabase.instance.client
          .from('stores')
          .delete()
          .eq('id', store['id']);
      _fetchStores();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Magasin supprimé avec succès.'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Erreur: Impossible de supprimer le magasin (il peut être lié à d'autres données). $e"),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<Map<String, int>> _getStoreStats(String storeId) async {
    try {
      final employeesRes = await Supabase.instance.client
          .from('user_profiles')
          .select('id')
          .eq('store_id', storeId)
          .eq('role', 'employee');

      final inventoryRes = await Supabase.instance.client
          .from('inventory')
          .select('quantity')
          .eq('store_id', storeId);

      int totalStock = 0;
      for (var inv in inventoryRes) {
        totalStock += (inv['quantity'] as int?) ?? 0;
      }

      return {
        'employees': employeesRes.length,
        'totalStock': totalStock,
      };
    } catch (e) {
      return {'employees': 0, 'totalStock': 0};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Gestion des Magasins'),
        backgroundColor: Colors.indigo[800],
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () => _showAddEditDialog(),
              icon: const Icon(Icons.add_business, size: 20),
              label: const Text('Nouveau Magasin', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.indigo[800],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stores.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warehouse_outlined, size: 100, color: Colors.grey[400]),
                      const SizedBox(height: 24),
                      const Text(
                        'Aucun magasin pour le moment',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ajoutez votre premier magasin pour commencer',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: () => _showAddEditDialog(),
                        icon: const Icon(Icons.add_business),
                        label: const Text('Ajouter un magasin', style: TextStyle(fontSize: 18)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 1.6,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                    ),
                    itemCount: _stores.length,
                    itemBuilder: (context, index) {
                      final store = _stores[index];
                      return FutureBuilder<Map<String, int>>(
                        future: _getStoreStats(store['id']),
                        builder: (context, snapshot) {
                          final stats = snapshot.data ?? {'employees': 0, 'totalStock': 0};
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border(
                                left: BorderSide(color: Colors.indigo[700]!, width: 5),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.warehouse, color: Colors.indigo[700], size: 32),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          store['name'],
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.indigo[900],
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert, color: Colors.grey),
                                        onSelected: (val) {
                                          if (val == 'edit') _showAddEditDialog(store);
                                          if (val == 'delete') _deleteStore(store);
                                        },
                                        itemBuilder: (ctx) => [
                                          const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Colors.orange, size: 20), SizedBox(width: 8), Text('Modifier')])),
                                          const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 20), SizedBox(width: 8), Text('Supprimer')])),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Row(
                                    children: [
                                      _buildStatBadge(
                                        Icons.people,
                                        '${stats['employees']} employés',
                                        Colors.blue,
                                      ),
                                      const SizedBox(width: 12),
                                      _buildStatBadge(
                                        Icons.inventory_2,
                                        '${stats['totalStock']} unités',
                                        Colors.green,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildStatBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
