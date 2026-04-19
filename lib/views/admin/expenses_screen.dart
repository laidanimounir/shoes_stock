import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_session.dart';
import '../../services/expense_service.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;
  String? _filterCategoryId;

  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final storeId = AppSession.currentStoreId;
    if (storeId == null) return;

    final cats = await ExpenseService.instance.fetchCategories(storeId);
    final exps = await ExpenseService.instance.fetchExpenses(
      storeId,
      from: _dateFrom,
      to: _dateTo,
      categoryId: _filterCategoryId,
    );

    if (mounted) {
      setState(() {
        _categories = cats;
        _expenses = exps;
        _isLoading = false;
      });
    }
  }

  // ══════════════════════════════════════════
  // Stats
  // ══════════════════════════════════════════

  double get _totalMonth {
    final now = DateTime.now();
    return _expenses
        .where((e) {
          final d = DateTime.tryParse(e['expense_date'] ?? '');
          return d != null && d.month == now.month && d.year == now.year;
        })
        .fold(0.0, (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0));
  }

  int get _countMonth {
    final now = DateTime.now();
    return _expenses.where((e) {
      final d = DateTime.tryParse(e['expense_date'] ?? '');
      return d != null && d.month == now.month && d.year == now.year;
    }).length;
  }

  double get _maxExpense {
    if (_expenses.isEmpty) return 0;
    return _expenses
        .map((e) => (e['amount'] as num?)?.toDouble() ?? 0)
        .reduce((a, b) => a > b ? a : b);
  }

  // ══════════════════════════════════════════
  // Add Expense Dialog
  // ══════════════════════════════════════════

  void _showAddExpenseDialog() {
    final formKey = GlobalKey<FormState>();
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? selectedCatId = _categories.isNotEmpty ? _categories.first['id'] : null;
    String selectedMethod = 'cash';
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Nouvelle Dépense', style: GoogleFonts.raleway(fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedCatId,
                    decoration: const InputDecoration(
                      labelText: 'Catégorie',
                      prefixIcon: Icon(Icons.category),
                      border: OutlineInputBorder(),
                    ),
                    items: _categories
                        .map((c) => DropdownMenuItem(
                              value: c['id'] as String,
                              child: Text(c['name'] as String),
                            ))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedCatId = v),
                    validator: (v) => v == null ? 'Requis' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Montant (DA)',
                      prefixIcon: Icon(Icons.attach_money),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Requis';
                      if (double.tryParse(v) == null || double.parse(v) <= 0) return 'Montant invalide';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      prefixIcon: Icon(Icons.description),
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedMethod,
                    decoration: const InputDecoration(
                      labelText: 'Méthode de paiement',
                      prefixIcon: Icon(Icons.payment),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Espèces')),
                      DropdownMenuItem(value: 'bank', child: Text('Virement bancaire')),
                      DropdownMenuItem(value: 'mobile', child: Text('Mobile')),
                    ],
                    onChanged: (v) => setDialogState(() => selectedMethod = v ?? 'cash'),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today, color: Colors.indigo),
                    title: Text(
                      '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                      style: GoogleFonts.raleway(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text('Date de la dépense'),
                    trailing: TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                      child: const Text('Changer'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(ctx);

                try {
                  await ExpenseService.instance.addExpense(
                    storeId: AppSession.currentStoreId!,
                    categoryId: selectedCatId,
                    amount: double.parse(amountCtrl.text),
                    description: descCtrl.text.trim(),
                    paymentMethod: selectedMethod,
                    expenseDate: selectedDate,
                  );
                  _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Dépense enregistrée.'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  // Category Manager Dialog
  // ══════════════════════════════════════════

  void _showCategoryManagerDialog() {
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Catégories de Dépenses', style: GoogleFonts.raleway(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Nom de la catégorie',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty) return;
                        try {
                          await ExpenseService.instance.addCategory(
                            name: nameCtrl.text.trim(),
                            storeId: AppSession.currentStoreId!,
                          );
                          nameCtrl.clear();
                          final cats = await ExpenseService.instance.fetchCategories(AppSession.currentStoreId!);
                          setDialogState(() {});
                          setState(() => _categories = cats);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                      child: const Text('Ajouter'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                SizedBox(
                  height: 200,
                  child: _categories.isEmpty
                      ? const Center(child: Text('Aucune catégorie.', style: TextStyle(color: Colors.grey)))
                      : ListView.separated(
                          itemCount: _categories.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final cat = _categories[i];
                            return ListTile(
                              leading: const Icon(Icons.label, color: Colors.indigo),
                              title: Text(cat['name'] as String),
                              dense: true,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  // Date Range Picker
  // ══════════════════════════════════════════

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateFrom != null && _dateTo != null
          ? DateTimeRange(start: _dateFrom!, end: _dateTo!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _dateFrom = picked.start;
        _dateTo = picked.end;
      });
      _loadData();
    }
  }

  // ══════════════════════════════════════════
  // Helpers
  // ══════════════════════════════════════════

  IconData _methodIcon(String? method) {
    switch (method) {
      case 'bank':
        return Icons.account_balance;
      case 'mobile':
        return Icons.phone_android;
      default:
        return Icons.money;
    }
  }

  String _methodLabel(String? method) {
    switch (method) {
      case 'bank':
        return 'Virement';
      case 'mobile':
        return 'Mobile';
      default:
        return 'Espèces';
    }
  }

  // ══════════════════════════════════════════
  // Build
  // ══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Gestion des Dépenses', style: GoogleFonts.raleway(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.category),
            tooltip: 'Gérer les catégories',
            onPressed: _showCategoryManagerDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpenseDialog,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text('Dépense', style: GoogleFonts.raleway(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Summary Cards ──
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _buildStatCard('Total du mois', '${_totalMonth.toStringAsFixed(2)} DA',
                          Icons.trending_down, Colors.red),
                      const SizedBox(width: 12),
                      _buildStatCard('Nombre', '$_countMonth dépenses',
                          Icons.receipt_long, Colors.indigo),
                      const SizedBox(width: 12),
                      _buildStatCard('Plus grande', '${_maxExpense.toStringAsFixed(2)} DA',
                          Icons.arrow_upward, Colors.orange),
                    ],
                  ),
                ),

                // ── Filters ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickDateRange,
                        icon: const Icon(Icons.date_range, size: 18),
                        label: Text(
                          _dateFrom != null
                              ? '${_dateFrom!.day}/${_dateFrom!.month} → ${_dateTo!.day}/${_dateTo!.month}'
                              : 'Période',
                          style: GoogleFonts.raleway(fontSize: 13),
                        ),
                      ),
                      if (_dateFrom != null) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            setState(() { _dateFrom = null; _dateTo = null; });
                            _loadData();
                          },
                        ),
                      ],
                      const SizedBox(width: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Wrap(
                            spacing: 8,
                            children: [
                              FilterChip(
                                label: const Text('Toutes'),
                                selected: _filterCategoryId == null,
                                selectedColor: Colors.indigo[100],
                                onSelected: (_) {
                                  setState(() => _filterCategoryId = null);
                                  _loadData();
                                },
                              ),
                              ..._categories.map((c) => FilterChip(
                                    label: Text(c['name'] as String),
                                    selected: _filterCategoryId == c['id'],
                                    selectedColor: Colors.indigo[100],
                                    onSelected: (_) {
                                      setState(() => _filterCategoryId =
                                          _filterCategoryId == c['id'] ? null : c['id'] as String);
                                      _loadData();
                                    },
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ── Expense List ──
                Expanded(
                  child: _expenses.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text('Aucune dépense enregistrée.',
                                  style: GoogleFonts.raleway(color: Colors.grey, fontSize: 16)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _expenses.length,
                          itemBuilder: (context, index) {
                            final e = _expenses[index];
                            final amount = (e['amount'] as num?)?.toDouble() ?? 0;
                            final catName = e['expense_categories']?['name'] as String? ?? 'Sans catégorie';
                            final desc = e['description'] as String? ?? '';
                            final method = e['payment_method'] as String? ?? 'cash';
                            final dateStr = e['expense_date'] as String? ?? '';

                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.red[50],
                                  child: Icon(_methodIcon(method), color: Colors.red[700]),
                                ),
                                title: Text(
                                  desc.isNotEmpty ? desc : catName,
                                  style: GoogleFonts.raleway(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  '$catName · ${_methodLabel(method)}',
                                  style: GoogleFonts.raleway(color: Colors.grey[600], fontSize: 12),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${amount.toStringAsFixed(2)} DA',
                                      style: GoogleFonts.raleway(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red[700],
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(dateStr, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.raleway(color: Colors.grey[600], fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(value,
                      style: GoogleFonts.raleway(fontWeight: FontWeight.bold, fontSize: 16, color: color),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
