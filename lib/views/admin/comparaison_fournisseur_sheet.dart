import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_session.dart';
import '../../core/app_strings.dart';

class SupplierComparisonSheet extends StatefulWidget {
  const SupplierComparisonSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const SupplierComparisonSheet(),
    );
  }

  @override
  State<SupplierComparisonSheet> createState() => _SupplierComparisonSheetState();
}

class _SupplierComparisonSheetState extends State<SupplierComparisonSheet> {
  List<dynamic> _variants = [];
  List<dynamic> _filteredVariants = [];
  final _searchCtrl = TextEditingController();
  bool _loadingVariants = true;
  bool _loadingComparison = false;
  String? _selectedVariantId;
  String? _selectedVariantLabel;
  List<dynamic> _comparisonData = [];

  @override
  void initState() {
    super.initState();
    _fetchVariants();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchVariants() async {
    setState(() => _loadingVariants = true);
    try {
      final res = await Supabase.instance.client
          .from('product_variants')
          .select('id, size, color, barcode, products(name)')
          .eq('is_active', true)
          .order('products(name)', ascending: true);
      if (mounted) {
        setState(() {
          _variants = res;
          _filteredVariants = res;
          _loadingVariants = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingVariants = false);
    }
  }

  void _onSearch(String q) {
    final query = q.toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredVariants = List.from(_variants);
      } else {
        _filteredVariants = _variants.where((v) {
          final name = (v['products']?['name'] ?? '').toString().toLowerCase();
          final barcode = (v['barcode'] ?? '').toString().toLowerCase();
          return name.contains(query) || barcode.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadComparison(String variantId, String label) async {
    setState(() {
      _selectedVariantId = variantId;
      _selectedVariantLabel = label;
      _loadingComparison = true;
    });
    try {
      final res = await Supabase.instance.client.rpc('get_supplier_comparison', params: {
        'p_variant_id': variantId,
        'p_store_id': AppSession.currentStoreId,
      });
      if (mounted) {
        setState(() {
          _comparisonData = (res as List?) ?? [];
          _loadingComparison = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingComparison = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.9,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: _selectedVariantId == null
            ? _buildVariantSelector()
            : _buildComparisonTable(),
      ),
    );
  }

  Widget _buildVariantSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(S.t('comparison_select_product'),
          style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: S.t('comparison_search_hint'),
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            isDense: true,
          ),
          onChanged: _onSearch,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loadingVariants
              ? const Center(child: CircularProgressIndicator())
              : _filteredVariants.isEmpty
                  ? Center(child: Text(S.t('comparison_no_variants')))
                  : ListView.separated(
                      itemCount: _filteredVariants.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final v = _filteredVariants[i];
                        final name = v['products']?['name'] ?? '?';
                        final size = v['size'] ?? '';
                        final color = v['color'] ?? '';
                        final barcode = v['barcode'] ?? '';
                        return ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.shopping_bag)),
                          title: Text('$name', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('$size • $color${barcode.isNotEmpty ? ' • $barcode' : ''}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _loadComparison(
                            v['id'],
                            '$name ($size, $color)',
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildComparisonTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() {
                _selectedVariantId = null;
                _comparisonData = [];
              }),
            ),
            Expanded(
              child: Text(
                '${S.t('comparison_title')}: $_selectedVariantLabel',
                style: Theme.of(context).textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const Divider(),
        if (_loadingComparison)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_comparisonData.isEmpty)
          Expanded(child: Center(child: Text(S.t('comparison_no_data'))))
        else
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 20,
                  columns: [
                    DataColumn(label: Text(S.t('comparison_supplier'),
                      style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text(S.t('comparison_last_price'),
                      style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                    DataColumn(label: Text(S.t('comparison_avg_price'),
                      style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                    DataColumn(label: Text(S.t('comparison_min_price'),
                      style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                    DataColumn(label: Text(S.t('comparison_max_price'),
                      style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                    DataColumn(label: Text(S.t('comparison_purchases'),
                      style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                  ],
                  rows: _buildRows(),
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<DataRow> _buildRows() {
    if (_comparisonData.isEmpty) return [];

    final prices = _comparisonData
        .map((r) => (r['last_price'] as num?)?.toDouble() ?? 0)
        .toList();
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final hasMultiple = _comparisonData.length > 1;

    return _comparisonData.map<DataRow>((r) {
      final lastPrice = (r['last_price'] as num?)?.toDouble() ?? 0;
      final isCheapest = hasMultiple && lastPrice == minPrice;
      final isMostExp = hasMultiple && lastPrice == maxPrice;

      Color? rowColor;
      if (isCheapest) rowColor = Colors.green.withOpacity(0.08);
      if (isMostExp) rowColor = Colors.red.withOpacity(0.08);

      final style = TextStyle(
        color: isCheapest ? Colors.green : (isMostExp ? Colors.red : null),
        fontWeight: isCheapest || isMostExp ? FontWeight.bold : null,
      );

      return DataRow(
        color: rowColor != null ? MaterialStateProperty.all(rowColor) : null,
        cells: [
          DataCell(Text(r['supplier_name'] ?? '', style: style)),
          DataCell(Text(lastPrice.toStringAsFixed(2), style: style)),
          DataCell(Text(((r['avg_price'] as num?)?.toDouble() ?? 0).toStringAsFixed(2))),
          DataCell(Text(((r['min_price'] as num?)?.toDouble() ?? 0).toStringAsFixed(2))),
          DataCell(Text(((r['max_price'] as num?)?.toDouble() ?? 0).toStringAsFixed(2))),
          DataCell(Text('${(r['total_purchases'] as num?)?.toInt() ?? 0}')),
        ],
      );
    }).toList();
  }
}
