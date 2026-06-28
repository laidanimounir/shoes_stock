import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_session.dart';
import '../../theme/app_colors.dart';
import '../../core/app_strings.dart';
import '../../theme/app_colors.dart';
import '../admin/comparaison_fournisseur_sheet.dart';
import '../../local_db/isar_service.dart';
import '../../local_db/collections/supplier_local.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});
  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  List<dynamic> _suppliers = [];
  bool _isLoading = true, _debtFilter = false;
  final _searchCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _fetch(); }
  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _fetch([String q = '']) async {
    setState(() => _isLoading = true);
    if (AppSession.isOfflineMode) {
      try { final isar = await IsarService.getInstance(); final all = await isar.supplierLocals.where().findAll(); var mapped = all.map((s) => {'id': s.supabaseId, 'company_name': s.companyName, 'full_name': s.contactName, 'phone': s.phone, 'balance': s.balance, 'is_active': s.isActive}).toList(); if (q.isNotEmpty) mapped = mapped.where((s) => (s['company_name'] ?? '').toString().toLowerCase().contains(q.toLowerCase()) || (s['phone'] ?? '').toString().toLowerCase().contains(q.toLowerCase())).toList(); if (mounted) setState(() { _suppliers = _debtFilter ? mapped.where((s) => (s['balance'] as num? ?? 0) > 0).toList() : mapped; _isLoading = false; }); }
      catch (_) { if (mounted) setState(() => _isLoading = false); }
      return;
    }
    try {
      var qb = Supabase.instance.client.from('suppliers').select().eq('is_active', true);
      if (q.isNotEmpty) qb = qb.or('company_name.ilike.%$q%,phone.ilike.%$q%');
      final res = await qb.order('company_name');
      if (mounted) setState(() { _suppliers = _debtFilter ? (res as List).where((s) => (s['balance'] as num? ?? 0) > 0).toList() : res; _isLoading = false; });
    } catch (_) { if (mounted) setState(() => _isLoading = false); }
  }

  void _add() {
    final nameCtrl = TextEditingController(); final phoneCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(S.t('supplier_add')), content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom société', border: OutlineInputBorder())),
        const SizedBox(height: 8), TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Téléphone', border: OutlineInputBorder())),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.t('action_cancel'))),
        ElevatedButton(onPressed: () async { if (nameCtrl.text.isEmpty) return; Navigator.pop(ctx); try { await Supabase.instance.client.from('suppliers').insert({'company_name': nameCtrl.text.trim(), 'phone': phoneCtrl.text.trim(), 'balance': 0, 'is_active': true}); _fetch(); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Color(0xFFF87171))); } }, child: Text(S.t('action_save'))),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.t('nav_suppliers')), backgroundColor: Color(0xFF0A0A14), foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.compare_arrows), tooltip: S.t('supp_compare'), onPressed: () => SupplierComparisonSheet.show(context)),
          IconButton(icon: Icon(_debtFilter ? Icons.filter_list_off : Icons.filter_list), onPressed: () => setState(() { _debtFilter = !_debtFilter; _fetch(); })),
          if (AppSession.isOwner) IconButton(icon: const Icon(Icons.add), onPressed: _add),
        ],
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : Column(children: [
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
            onChanged: (v) => _fetch(v),
          ),
        ),
        Expanded(child: _suppliers.isEmpty
          ? Center(child: Text(S.t('supplier_no_results')))
          : RefreshIndicator(onRefresh: () => _fetch(_searchCtrl.text), child: ListView.builder(padding: const EdgeInsets.all(12), itemCount: _suppliers.length, itemBuilder: (_, i) {
              final s = _suppliers[i]; final bal = (s['balance'] as num?)?.toDouble() ?? 0;
              return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
                leading: CircleAvatar(child: Text((s['company_name'] as String? ?? '?')[0].toUpperCase())),
                title: Text(s['company_name'] ?? s['full_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(s['phone'] ?? '', style: const TextStyle(fontSize: 12)),
                trailing: bal > 0
                    ? Text('${bal.toStringAsFixed(0)} ${S.t('misc_currency')}', style: const TextStyle(color: Color(0xFFF87171), fontWeight: FontWeight.bold))
                    : const Icon(Icons.check_circle, color: Color(0xFF4ADE80), size: 20),
              ));
            }),
          ),
        ),
      ],
    ),
    );
  }
}
