import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_strings.dart';
import '../../theme/app_colors.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});
  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> with SingleTickerProviderStateMixin {
  List<dynamic> _employees = [];
  List<dynamic> _filtered = [];
  bool _isLoading = true;
  late TabController _tabCtrl;
  String _statusFilter = 'active';
  final Set<String> _expandedIds = {};
  final Map<String, Map<String, dynamic>> _performances = {};
  final _searchCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _tabCtrl = TabController(length: 3, vsync: this); _tabCtrl.addListener(() { if (!_tabCtrl.indexIsChanging) { setState(() { _statusFilter = ['active', 'suspended', 'archived'][_tabCtrl.index]; _expandedIds.clear(); _performances.clear(); }); _fetch(); } }); _fetch(); }
  @override
  void dispose() { _tabCtrl.dispose(); _searchCtrl.dispose(); super.dispose(); }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      var qb = Supabase.instance.client.from('user_profiles').select('id, full_name, email, phone, is_active, role, store_id, stores(name)');
      if (_statusFilter == 'active') qb = qb.eq('is_active', true);
      else if (_statusFilter == 'suspended') qb = qb.eq('is_active', false);
      qb = qb.eq('role', 'employee');
      final res = await qb.order('full_name');
      if (mounted) setState(() { _employees = res; _applyFilter(); _isLoading = false; });
    } catch (_) { if (mounted) setState(() => _isLoading = false); }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.from(_employees)
          : _employees.where((e) =>
              (e['full_name'] ?? '').toString().toLowerCase().contains(q) ||
              (e['email'] ?? '').toString().toLowerCase().contains(q) ||
              (e['phone'] ?? '').toString().toLowerCase().contains(q)).toList();
    });
  }

  Future<void> _loadPerformance(String userId, String? storeId) async {
    if (_performances.containsKey(userId)) return;
    try {
      final res = await Supabase.instance.client.rpc('get_employee_performance', params: {
        'p_store_id': storeId,
        'p_period': 'month',
      });
      final list = List<Map<String, dynamic>>.from(res ?? []);
      final perf = list.cast<Map<String, dynamic>?>().firstWhere(
        (p) => p?['user_id'] == userId,
        orElse: () => null,
      );
      if (mounted) setState(() {
        if (perf != null) _performances[userId] = perf;
        else _performances[userId] = {};
      });
    } catch (e) {
      if (mounted) setState(() => _performances[userId] = {});
    }
  }

  Future<void> _toggleStatus(Map<String, dynamic> emp) async {
    final newStatus = !(emp['is_active'] ?? true);
    final label = newStatus ? 'activer' : 'suspendre';
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text('Confirmation'), content: Text('Voulez-vous $label ${emp['full_name']} ?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.t('action_cancel'))),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning, foregroundColor: Colors.white), child: Text(label)),
      ],
    ));
    if (confirm != true) return;
    try {
      await Supabase.instance.client.from('user_profiles').update({'is_active': newStatus}).eq('id', emp['id']);
      _fetch();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger)); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.t('nav_employees')), backgroundColor: AppColors.mobileBackground, foregroundColor: Colors.white, bottom: TabBar(
        controller: _tabCtrl, labelColor: Colors.white, unselectedLabelColor: AppColors.mobileTextSecondary,
        tabs: [Tab(text: S.t('filter_active')), Tab(text: S.t('filter_suspended')), Tab(text: S.t('filter_archived'))],
      )),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : Column(children: [
        if (_isLoading == false) Padding(
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
        Expanded(child: _filtered.isEmpty
          ? Center(child: Text(S.t('label_no_data')))
          : RefreshIndicator(onRefresh: _fetch, child: ListView.builder(padding: const EdgeInsets.all(12), itemCount: _filtered.length, itemBuilder: (_, i) {
              final e = _filtered[i];
              final empId = e['id'] as String;
              final isExpanded = _expandedIds.contains(empId);
              final perf = _performances[empId];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(child: Text(((e['full_name'] as String?)?[0] ?? '?').toUpperCase())),
                      title: Text(e['full_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${e['phone'] ?? ''} • ${e['stores']?['name'] ?? ''}', style: const TextStyle(fontSize: 12)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: AppColors.mobilePrimary),
                            onPressed: () {
                              setState(() {
                                if (isExpanded) { _expandedIds.remove(empId); }
                                else { _expandedIds.add(empId); _loadPerformance(empId, e['store_id'] as String?); }
                              });
                            },
                          ),
                          PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'toggle') _toggleStatus(e);
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(value: 'toggle', child: Text((e['is_active'] ?? true) ? 'Suspendre' : 'Activer')),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isExpanded)
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: perf == null
                            ? const SizedBox(height: 40, child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))))
                            : perf.isEmpty
                                ? const Text('Aucune performance', style: TextStyle(color: AppColors.mobileTextSecondary, fontSize: 12))
                                : Column(
                                    children: [
                                      const Divider(),
                                      _perfRow('Ventes', '${(perf['total_sales'] as num?)?.toDouble() ?? 0} ${S.t('misc_currency')}', AppColors.success),
                                      const SizedBox(height: 6),
                                      _perfRow('Transactions', '${(perf['transactions_count'] as num?)?.toInt() ?? 0}', AppColors.info),
                                      const SizedBox(height: 6),
                                      _perfRow('Remboursements', '${(perf['total_refunds'] as num?)?.toDouble() ?? 0} ${S.t('misc_currency')}', AppColors.danger),
                                      const SizedBox(height: 6),
                                      _perfRow('Remises', '${(perf['total_discount_given'] as num?)?.toDouble() ?? 0} ${S.t('misc_currency')}', AppColors.warning),
                                    ],
                                  ),
                      ),
                  ],
                ),
            );
          }),
          ),
        ),
      ],
    ),
    );
  }

  Widget _perfRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.mobileTextSecondary)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
