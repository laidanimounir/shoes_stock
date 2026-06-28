import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_strings.dart';

class GestionStoresScreen extends StatefulWidget {
  const GestionStoresScreen({super.key});

  @override
  State<GestionStoresScreen> createState() => _GestionStoresScreenState();
}

class _GestionStoresScreenState extends State<GestionStoresScreen> {
  List<dynamic> _stores = [];
  bool _isLoading = true;

  String? _userRole;

  @override
  void initState() {
    super.initState();
    _initRoleAndFetch();
  }

  Future<void> _initRoleAndFetch() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final profile = await Supabase.instance.client
            .from('user_profiles')
            .select('role')
            .eq('id', user.id)
            .single();
        _userRole = profile['role'];
      }
    } catch (e, s) { debugPrint('[GestionStores] initRole error: $e\n$s'); }
    if (mounted) setState(() {});
    await _fetchStores();
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
    final maxDiscCtrl = TextEditingController(
        text: store?['max_discount_percent']?.toString() ?? '30');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(isEdit ? Icons.edit : Icons.add_business, color: Colors.indigo),
            const SizedBox(width: 12),
            Text(isEdit ? S.t('store_edit') : S.t('store_add')),
          ],
        ),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: S.t('store_name'),
                    prefixIcon: const Icon(Icons.warehouse),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => v!.trim().isEmpty ? S.t('msg_required') : null,
                ),
                if (isEdit) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: maxDiscCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: S.t('store_max_discount'),
                      prefixIcon: const Icon(Icons.percent),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.t('action_cancel')),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              try {
                final data = <String, dynamic>{'name': nameCtrl.text.trim()};
                if (isEdit) {
                  final maxDisc = double.tryParse(maxDiscCtrl.text);
                  if (maxDisc != null) {
                    data['max_discount_percent'] = maxDisc;
                  }
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
                    content: Text(isEdit ? S.t('store_updated') : S.t('store_created')),
                    backgroundColor: Colors.green,
                  ));
                }
              } on PostgrestException catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(e.code == '42501' ? S.t('msg_access_denied') : '${S.t('msg_error')}: ${e.message}'),
                    backgroundColor: Colors.red,
                  ));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('${S.t('msg_error')}: $e'),
                    backgroundColor: Colors.red,
                  ));
                }
              }
            },
            icon: Icon(isEdit ? Icons.save : Icons.add),
            label: Text(isEdit ? S.t('action_save') : S.t('action_add')),
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
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 12),
            Text(S.t('action_confirm_delete')),
          ],
        ),
        content: Text(S.t('store_delete_msg').replaceAll('{name}', store['name'])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.t('action_cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(S.t('action_delete')),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(S.t('store_deleted')),
          backgroundColor: Colors.green,
        ));
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.code == '42501' ? S.t('msg_access_denied') : '${S.t('msg_error')}: ${e.message}'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("${S.t('store_delete_error')} $e"),
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
      backgroundColor: Color(0xFF0A0A14),
      appBar: AppBar(
        title: Text(S.t('store_title')),
        backgroundColor: Color(0xFF0F0F1C),
        foregroundColor: Colors.white,
        actions: [
          if (_userRole == 'owner')
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 16),
              child: ElevatedButton.icon(
                onPressed: () => _showAddEditDialog(),
                icon: const Icon(Icons.add_business, size: 20),
                label: Text(S.t('store_add'), style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Color(0xFF0F0F1C),
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
                      Text(
                        S.t('store_no_results_yet'),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        S.t('store_add_first'),
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 32),
                      if (_userRole == 'owner')
                        ElevatedButton.icon(
                          onPressed: () => _showAddEditDialog(),
                          icon: const Icon(Icons.add_business),
                          label: Text(S.t('store_add_btn'), style: const TextStyle(fontSize: 18)),
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
                              border: BorderDirectional(
                                start: BorderSide(color: Color(0xFF0F0F1C)!, width: 5),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.warehouse, color: Color(0xFF0F0F1C), size: 32),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          store['name'],
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0F0F1C),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (_userRole == 'owner')
                                        PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert, color: Colors.grey),
                                          onSelected: (val) {
                                            if (val == 'edit') _showAddEditDialog(store);
                                            if (val == 'delete') _deleteStore(store);
                                          },
                                          itemBuilder: (ctx) => [
                                            PopupMenuItem(value: 'edit', child: Row(children: [const Icon(Icons.edit, color: Colors.orange, size: 20), const SizedBox(width: 8), Text(S.t('action_edit'))])),
                                            PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.delete, color: Colors.red, size: 20), const SizedBox(width: 8), Text(S.t('action_delete'))])),
                                          ],
                                        ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Row(
                                    children: [
                                      _buildStatBadge(
                                        Icons.people,
                                        '${stats['employees']} ${S.t('store_employees')}',
                                        Colors.blue,
                                      ),
                                      const SizedBox(width: 12),
                                      _buildStatBadge(
                                        Icons.inventory_2,
                                        '${stats['totalStock']} ${S.t('store_units')}',
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
