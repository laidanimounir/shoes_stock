import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_strings.dart';

class StockCountScreen extends StatefulWidget {
  const StockCountScreen({super.key});

  @override
  State<StockCountScreen> createState() => _StockCountScreenState();
}

class _StockCountScreenState extends State<StockCountScreen> {
  List<dynamic> _stores = [];
  String? _selectedStoreId;
  List<dynamic> _inventoryItems = [];
  bool _isLoading = true;

  String? _activeCountId;
  bool _isCounting = false;

  @override
  void initState() {
    super.initState();
    _fetchStores();
  }

  Future<void> _fetchStores() async {
    try {
      final res = await Supabase.instance.client
          .from('stores')
          .select()
          .eq('is_active', true)
          .order('name');
      if (mounted) setState(() { _stores = res; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _initiateCount() async {
    if (_selectedStoreId == null) return;
    try {
      final res = await Supabase.instance.client
          .from('stock_counts')
          .insert({
            'store_id': _selectedStoreId,
            'created_by': Supabase.instance.client.auth.currentUser!.id,
          })
          .select()
          .single();
      _activeCountId = res['id'];
      await _loadInventoryForCount();
      if (mounted) setState(() => _isCounting = true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Color(0xFFF87171)));
    }
  }

  Future<void> _loadInventoryForCount() async {
    if (_selectedStoreId == null) return;
    try {
      final res = await Supabase.instance.client
          .from('inventory')
          .select('variant_id, quantity, product_variants(id, size, color, products(name))')
          .eq('store_id', _selectedStoreId!);
      setState(() => _inventoryItems = res);
    } catch (e) {
      debugPrint('Error loading inventory for count: $e');
    }
  }

  Future<void> _submitCountItem(String variantId, int expected, int actual) async {
    if (_activeCountId == null) return;
    final delta = actual - expected;
    try {
      await Supabase.instance.client.from('stock_count_items').upsert({
        'count_id': _activeCountId,
        'variant_id': variantId,
        'expected_qty': expected,
        'actual_qty': actual,
        'delta': delta,
      });
    } catch (e) {
      debugPrint('Error submitting count item: $e');
    }
  }

  Future<void> _closeCount() async {
    if (_activeCountId == null) return;
    try {
      await Supabase.instance.client.rpc('close_stock_count', params: {
        'p_count_id': _activeCountId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(S.t('action_save')),
          backgroundColor: Color(0xFF4ADE80),
        ));
        setState(() { _activeCountId = null; _isCounting = false; _inventoryItems = []; });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Color(0xFFF87171)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0A14),
      appBar: AppBar(
        title: Text('Comptage de Stock'),
        backgroundColor: Color(0xFF0F0F1C),
        foregroundColor: Color(0xFFEEEEFF),
        actions: [
          if (_isCounting)
            TextButton.icon(
              onPressed: _closeCount,
              icon: const Icon(Icons.check, color: Color(0xFFEEEEFF)),
              label: const Text('Fermer', style: TextStyle(color: Color(0xFFEEEEFF))),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isCounting
              ? _buildCountingView()
              : _buildInitView(),
    );
  }

  Widget _buildInitView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.inventory_2, size: 80, color: Color(0xFF58A6FF)),
          const SizedBox(height: 16),
          Text('Comptage de Stock', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F0F1C))),
          const SizedBox(height: 8),
          Text('Initier un comptage pour vérifier les quantités en magasin', style: TextStyle(color: Color(0xFF9090A8))),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            initialValue: _selectedStoreId,
            decoration: InputDecoration(
              labelText: S.t('label_store'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: _stores.map<DropdownMenuItem<String>>((s) =>
              DropdownMenuItem(value: s['id'] as String?, child: Text(s['name'] as String? ?? ''))
            ).toList(),
            onChanged: (v) => setState(() => _selectedStoreId = v),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectedStoreId == null ? null : _initiateCount,
              icon: const Icon(Icons.play_arrow),
              label: Text('Démarrer le Comptage', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF0F0F1C),
                foregroundColor: Color(0xFFEEEEFF),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountingView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Color(0xFF0D1F3A),
          child: Row(
            children: [
              const Icon(Icons.inventory, color: Color(0xFF58A6FF)),
              const SizedBox(width: 8),
              Text('Comptage en cours', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F0F1C))),
              const Spacer(),
              Text('${_inventoryItems.length} articles'),
            ],
          ),
        ),
        Expanded(
          child: _inventoryItems.isEmpty
              ? const Center(child: Text('Aucun article'))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _inventoryItems.length,
                  itemBuilder: (context, index) {
                    final item = _inventoryItems[index];
                    final variant = item['product_variants'] ?? {};
                    final product = variant['products'] ?? {};
                    final expected = (item['quantity'] as int?) ?? 0;
                    final variantId = item['variant_id'];
                    TextEditingController qtyCtrl = TextEditingController(text: '$expected');

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(product['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${S.t('pos_size')}: ${variant['size'] ?? '-'} | ${S.t('pos_color')}: ${variant['color'] ?? '-'}'),
                        trailing: SizedBox(
                          width: 120,
                          child: Row(
                            children: [
                              Text('$expected → ', style: TextStyle(color: Color(0xFF9090A8), fontSize: 12)),
                              SizedBox(
                                width: 50,
                                child: TextField(
                                  controller: qtyCtrl,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  onChanged: (val) {
                                    final actual = int.tryParse(val) ?? 0;
                                    _submitCountItem(variantId, expected, actual);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
