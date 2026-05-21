import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_session.dart';
import '../../core/app_strings.dart';

class StoresScreen extends StatefulWidget {
  const StoresScreen({super.key});
  @override
  State<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends State<StoresScreen> {
  List<dynamic> _stores = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client.from('stores').select().eq('is_active', true);
      if (mounted) setState(() { _stores = res; _isLoading = false; });
    } catch (_) { if (mounted) setState(() => _isLoading = false); }
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
        ElevatedButton(onPressed: () async { if (nameCtrl.text.isEmpty) return; Navigator.pop(ctx); try { await Supabase.instance.client.from('stores').insert({'name': nameCtrl.text.trim(), 'address': addrCtrl.text.trim(), 'is_active': true}); _fetch(); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red)); } }, child: Text(S.t('action_save'))),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.t('nav_stores')), backgroundColor: Colors.indigo[900], foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: _add)]),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : _stores.isEmpty
          ? Center(child: Text(S.t('label_no_data')))
          : ListView.builder(padding: const EdgeInsets.all(12), itemCount: _stores.length, itemBuilder: (_, i) {
              final s = _stores[i];
              return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
                leading: CircleAvatar(child: Text((s['name'] as String? ?? '?')[0].toUpperCase())),
                title: Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(s['address'] ?? '', style: const TextStyle(fontSize: 12)),
              ));
            }),
    );
  }
}
