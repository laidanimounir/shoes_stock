import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_session.dart';
import '../../core/app_strings.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});
  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> with SingleTickerProviderStateMixin {
  List<dynamic> _employees = [];
  bool _isLoading = true;
  late TabController _tabCtrl;
  String _statusFilter = 'active';

  @override
  void initState() { super.initState(); _tabCtrl = TabController(length: 3, vsync: this); _tabCtrl.addListener(() { if (!_tabCtrl.indexIsChanging) { setState(() { _statusFilter = ['active', 'suspended', 'archived'][_tabCtrl.index]; }); _fetch(); } }); _fetch(); }
  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      final isActive = _statusFilter == 'active' ? true : (_statusFilter == 'suspended' ? false : null);
      var qb = Supabase.instance.client.from('user_profiles').select('id, full_name, email, phone, is_active, role, stores(name)');
      if (_statusFilter == 'active') qb = qb.eq('is_active', true);
      else if (_statusFilter == 'suspended') qb = qb.eq('is_active', false);
      qb = qb.eq('role', 'employee');
      final res = await qb.order('full_name');
      if (mounted) setState(() { _employees = res; _isLoading = false; });
    } catch (_) { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _toggleStatus(Map<String, dynamic> emp) async {
    final newStatus = !(emp['is_active'] ?? true);
    final label = newStatus ? 'activer' : 'suspendre';
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text('Confirmation'), content: Text('Voulez-vous $label ${emp['full_name']} ?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.t('action_cancel'))),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white), child: Text(label)),
      ],
    ));
    if (confirm != true) return;
    try {
      await Supabase.instance.client.from('user_profiles').update({'is_active': newStatus}).eq('id', emp['id']);
      _fetch();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red)); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.t('nav_employees')), backgroundColor: Colors.indigo[900], foregroundColor: Colors.white, bottom: TabBar(
        controller: _tabCtrl, labelColor: Colors.white, unselectedLabelColor: Colors.white60,
        tabs: const [Tab(text: 'Actifs'), Tab(text: 'Suspendus'), Tab(text: 'Archivés')],
      )),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : _employees.isEmpty
          ? Center(child: Text(S.t('label_no_data')))
          : ListView.builder(padding: const EdgeInsets.all(12), itemCount: _employees.length, itemBuilder: (_, i) {
              final e = _employees[i];
              return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
                leading: CircleAvatar(child: Text(((e['full_name'] as String?)?[0] ?? '?').toUpperCase())),
                title: Text(e['full_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${e['phone'] ?? ''} • ${e['stores']?['name'] ?? ''}', style: const TextStyle(fontSize: 12)),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'toggle') _toggleStatus(e);
                    else if (v == 'archive') _toggleStatus(e);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'toggle', child: Text((e['is_active'] ?? true) ? 'Suspendre' : 'Activer')),
                  ],
                ),
              ));
            }),
    );
  }
}
