import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SlowMovingSection extends StatefulWidget {
  const SlowMovingSection({super.key});

  @override
  State<SlowMovingSection> createState() => _SlowMovingSectionState();
}

class _SlowMovingSectionState extends State<SlowMovingSection> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  int _days = 60;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .rpc('get_slow_moving_products', params: {'p_days': _days});
      if (mounted) setState(() {
        _items = List<Map<String, dynamic>>.from(res ?? []);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.slow_motion_video, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Produits à rotation lente',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _days,
                    style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
                    items: const [
                      DropdownMenuItem(value: 30, child: Text('30j')),
                      DropdownMenuItem(value: 60, child: Text('60j')),
                      DropdownMenuItem(value: 90, child: Text('90j')),
                    ],
                    onChanged: (v) {
                      if (v != null) { setState(() => _days = v); _fetch(); }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        _isLoading
            ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
            : _items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text('Aucun produit lent', style: TextStyle(color: Colors.grey[500], fontSize: 13)))
                : Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        final days = (item['days_since_last_sale'] as num?)?.toInt() ?? 0;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: days > 90 ? Colors.red[50] : Colors.orange[50],
                            child: Icon(Icons.inventory_2, color: days > 90 ? Colors.red : Colors.orange, size: 18),
                          ),
                          title: Text('${item['product_name'] ?? ''} (${item['size'] ?? ''})',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text('${item['store_name'] ?? ''} • ${item['quantity']} unités',
                              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: days > 90 ? Colors.red[50] : Colors.orange[50],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('$days jours',
                                style: TextStyle(
                                    color: days > 90 ? Colors.red : Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11)),
                          ),
                        );
                      },
                    ),
                  ),
      ],
    );
  }
}
