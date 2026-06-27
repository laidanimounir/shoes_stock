import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_session.dart';
import '../../theme/app_colors.dart';
import '../../core/app_strings.dart';
import '../../theme/app_colors.dart';
import '../../local_db/isar_service.dart';
import '../../local_db/collections/expense_local.dart';
import '../../local_db/collections/expense_category_local.dart';
import '../../services/expense_service.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<dynamic> _expenses = [];
  List<dynamic> _categories = [];
  bool _isLoading = true;
  String? _catFilter;
  final _searchCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _fetch(); }
  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      final cats = await Supabase.instance.client.from('expense_categories').select().eq('is_active', true);
      final exps = await ExpenseService.instance.fetchExpenses(AppSession.currentStoreId!);
      if (mounted) setState(() { _categories = cats; _expenses = exps; _isLoading = false; });
    } catch (_) {
      // Offline
      try {
        final isar = await IsarService.getInstance();
        final cats = await isar.expenseCategoryLocals.where().findAll();
        final exps = await isar.expenseLocals.where().findAll();
        if (mounted) setState(() { _categories = cats.map((c) => {'id': c.supabaseId, 'name': c.name}).toList(); _expenses = exps.map((e) => {'id': e.supabaseId, 'amount': e.amount, 'description': e.description, 'created_at': e.createdAt?.toIso8601String(), 'category_id': e.categoryId}).toList(); _isLoading = false; });
      } catch (_) { if (mounted) setState(() => _isLoading = false); }
    }
  }

  void _add() {
    final descCtrl = TextEditingController(); final amountCtrl = TextEditingController(); String? catId;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
      title: Text(S.t('expense_add')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Montant', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(value: catId, decoration: const InputDecoration(labelText: 'Catégorie', border: OutlineInputBorder()),
          items: _categories.map<DropdownMenuItem<String>>((c) => DropdownMenuItem(value: c['id'] as String?, child: Text(c['name'] ?? ''))).toList(),
          onChanged: (v) => setD(() => catId = v)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.t('action_cancel'))),
        ElevatedButton(onPressed: () async {
          final amount = double.tryParse(amountCtrl.text);
          if (amount == null || amount <= 0) return;
          Navigator.pop(ctx);
          try {
            await ExpenseService.instance.addExpense(storeId: AppSession.currentStoreId!, categoryId: catId, amount: amount, description: descCtrl.text.trim(), paymentMethod: 'cash', expenseDate: DateTime.now());
            _fetch();
          } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger)); }
        }, child: Text(S.t('action_save'))),
      ],
    )));
  }

  void _toggleFilter(String catId) {
    setState(() {
      _catFilter = _catFilter == catId ? null : catId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchCtrl.text.toLowerCase();
    var filtered = _catFilter == null ? _expenses : _expenses.where((e) => e['category_id'] == _catFilter).toList();
    if (q.isNotEmpty) {
      filtered = filtered.where((e) =>
        (e['description'] ?? '').toString().toLowerCase().contains(q)
      ).toList();
    }
    final total = filtered.fold(0.0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0));
    return Scaffold(
      appBar: AppBar(title: Text(S.t('nav_expenses')), backgroundColor: AppColors.mobileBackground, foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: _add)]),
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
            onChanged: (_) => setState(() {}),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12), color: Colors.white,
          child: Column(children: [
            Row(children: [
              Text('${S.t('pos_total')}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('${total.toStringAsFixed(0)} ${S.t('misc_currency')}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.danger)),
            ]),
            const SizedBox(height: 8),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
              FilterChip(label: Text(S.t('filter_all')), selected: _catFilter == null, onSelected: (_) => setState(() => _catFilter = null)),
              const SizedBox(width: 4),
              ..._categories.map((c) => Padding(padding: const EdgeInsets.only(right: 4), child: FilterChip(
                label: Text(c['name'] ?? ''),
                selected: _catFilter == c['id'],
                onSelected: (_) => _toggleFilter(c['id'] as String),
              ))),
            ])),
          ]),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text(S.t('label_no_data')))
              : RefreshIndicator(
                  onRefresh: _fetch,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final e = filtered[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          title: Text(e['description'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text(e['created_at']?.toString().substring(0, 10) ?? '',
                              style: const TextStyle(fontSize: 11)),
                          trailing: Text(
                              '-${(e['amount'] as num?)?.toDouble() ?? 0} ${S.t('misc_currency')}',
                              style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ]),
    );
  }
}
