import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_strings.dart';
import '../../theme/app_colors.dart';
import '../../core/app_session.dart';
import '../../theme/app_colors.dart';

class StoresScreen extends StatefulWidget {
  const StoresScreen({super.key});
  @override
  State<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends State<StoresScreen> {
  List<dynamic> _stores = [];
  List<dynamic> _filtered = [];
  bool _isLoading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _fetch(); }
  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client.from('stores').select().eq('is_active', true);
      if (mounted) setState(() { _stores = res; _applyFilter(); _isLoading = false; });
    } catch (_) { if (mounted) setState(() => _isLoading = false); }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.from(_stores)
          : _stores.where((s) =>
              (s['name'] ?? '').toString().toLowerCase().contains(q) ||
              (s['address'] ?? '').toString().toLowerCase().contains(q)).toList();
    });
  }

  void _add() {
    final nameCtrl = TextEditingController(); final addrCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(S.t('store_add')), content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom', border: OutlineInputBorder())),
        const SizedBox(height: 8), TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: 'Adresse', border: OutlineInputBorder())),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.t('action_cancel'))),
        ElevatedButton(onPressed: () async { if (nameCtrl.text.isEmpty) return; Navigator.pop(ctx); try { await Supabase.instance.client.from('stores').insert({'name': nameCtrl.text.trim(), 'address': addrCtrl.text.trim(), 'is_active': true}); _fetch(); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Color(0xFFF87171))); } }, child: Text(S.t('action_save'))),
      ],
    ));
  }

  void _edit(Map<String, dynamic> store) {
    final nameCtrl = TextEditingController(text: store['name']);
    final addrCtrl = TextEditingController(text: store['address']);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(S.t('store_edit')), content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom', border: OutlineInputBorder())),
        const SizedBox(height: 8), TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: 'Adresse', border: OutlineInputBorder())),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.t('action_cancel'))),
        ElevatedButton(onPressed: () async {
          if (nameCtrl.text.isEmpty) return;
          Navigator.pop(ctx);
          try {
            await Supabase.instance.client.from('stores').update({'name': nameCtrl.text.trim(), 'address': addrCtrl.text.trim()}).eq('id', store['id']);
            _fetch();
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.t('store_updated')), backgroundColor: Color(0xFF4ADE80)));
          } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Color(0xFFF87171))); }
        }, child: Text(S.t('action_save'))),
      ],
    ));
  }

  Future<void> _delete(Map<String, dynamic> store) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(S.t('action_confirm_delete')),
      content: Text(S.t('store_delete_msg').replaceAll('{name}', store['name'] ?? '')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.t('action_cancel'))),
        ElevatedButton(onPressed: () async {
          Navigator.pop(ctx, true);
        }, style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFF87171), foregroundColor: Colors.white), child: Text(S.t('action_delete'))),
      ],
    ));
    if (confirm != true) return;
    try {
      await Supabase.instance.client.from('stores').delete().eq('id', store['id']);
      _fetch();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.t('store_deleted')), backgroundColor: Color(0xFF4ADE80)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.t('store_delete_error')), backgroundColor: Color(0xFFF87171)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.t('nav_stores')), backgroundColor: Color(0xFF0A0A14), foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: _add)]),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: S.t('search_hint'),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    onChanged: (_) => _applyFilter(),
                  ),
                ),
                Expanded(
                  child: _filtered.isEmpty
                      ? Center(child: Text(S.t('label_no_data')))
                      : RefreshIndicator(onRefresh: _fetch, child: ListView.builder(padding: const EdgeInsets.all(12), itemCount: _filtered.length, itemBuilder: (_, i) {
                          final s = _filtered[i];
                          return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
                            leading: CircleAvatar(child: Text((s['name'] as String? ?? '?')[0].toUpperCase())),
                            title: Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(s['address'] ?? '', style: const TextStyle(fontSize: 12)),
                            trailing: AppSession.isOwner
                                ? PopupMenuButton<String>(
                                    onSelected: (v) {
                                      if (v == 'edit') _edit(s);
                                      else if (v == 'delete') _delete(s);
                                    },
                                    itemBuilder: (_) => [
                                      PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit, size: 18), title: Text(S.t('form_edit')))),
                                      PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, size: 18, color: Color(0xFFF87171)), title: Text(S.t('action_delete'), style: TextStyle(color: Color(0xFFF87171))))),
                                    ],
                                  )
                                : null,
                          ));
                        }),
                      ),
                ),
              ],
            ),
    );
  }
}
