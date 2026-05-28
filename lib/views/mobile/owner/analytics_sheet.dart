import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/app_strings.dart';

class AnalyticsSheet extends StatefulWidget {
  const AnalyticsSheet({super.key});

  @override
  State<AnalyticsSheet> createState() => _AnalyticsSheetState();
}

class _AnalyticsSheetState extends State<AnalyticsSheet> {
  bool _isLoading = true;

  double _salesToday = 0;
  double _salesThisMonth = 0;
  double _salesLastMonth = 0;
  double _monthDiff = 0;
  bool _isUp = true;
  List<Map<String, dynamic>> _storeComparison = [];
  List<Map<String, dynamic>> _topProducts = [];

  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    try {
      final summary = await Supabase.instance.client.rpc('get_analytics_summary');
      _salesToday = (summary['today_sales'] as num?)?.toDouble() ?? 0;
      _salesThisMonth = (summary['this_month_sales'] as num?)?.toDouble() ?? 0;
      _salesLastMonth = (summary['last_month_sales'] as num?)?.toDouble() ?? 0;
      _monthDiff = (summary['monthDiff'] as num?)?.toDouble() ?? 0;
      _isUp = summary['isUp'] as bool? ?? true;
      _storeComparison = List<Map<String, dynamic>>.from(summary['store_comparison'] ?? []);

      final topRes = await Supabase.instance.client.rpc('get_top_products_this_month');
      _topProducts = List<Map<String, dynamic>>.from(topRes ?? []).map((e) => {
        'name': e['product_name'],
        'size': e['size'],
        'qty': e['total_sold'],
      }).toList();

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        width: 40, height: 4,
                        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.analytics, color: Colors.indigo[900], size: 22),
                        const SizedBox(width: 10),
                        Text(S.t('owner_analytics'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.indigo[900])),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _sectionTitle(S.t('owner_sales_section'), Icons.point_of_sale, Colors.blue),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _analyticsCard(S.t('dash_today'), "${_salesToday.toStringAsFixed(0)} ${S.t('misc_currency')}", Colors.blue)),
                        const SizedBox(width: 12),
                        Expanded(child: _analyticsCard(S.t('dash_this_month'), "${_salesThisMonth.toStringAsFixed(0)} ${S.t('misc_currency')}", Colors.indigo)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _isUp ? Colors.green[50] : Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${S.t('owner_vs_last_month')} (${_salesLastMonth.toStringAsFixed(0)} ${S.t('misc_currency')})',
                              style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                          Row(
                            children: [
                              Icon(_isUp ? Icons.trending_up : Icons.trending_down,
                                  color: _isUp ? Colors.green : Colors.red, size: 18),
                              Text('${_monthDiff.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    color: _isUp ? Colors.green[700] : Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  )),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle(S.t('owner_top_5_products'), Icons.star, Colors.orange),
                    const SizedBox(height: 12),
                    ..._topProducts.asMap().entries.map((entry) {
                      final i = entry.key;
                      final p = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.orange[100],
                              child: Text('${i + 1}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text('${p['name']}  ${S.t('pos_size')} ${p['size']}',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            ),
                            Text('${p['qty']} ${S.t('owner_qty_sold')}',
                                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                    _sectionTitle(S.t('owner_store_comp_today'), Icons.storefront, Colors.purple),
                    const SizedBox(height: 12),
                    ..._storeComparison.map((store) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(store['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('${(store['sales'] as double).toStringAsFixed(0)} ${S.t('misc_currency')}',
                                    style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                              value: (store['ratio'] as double).clamp(0.0, 1.0),
                              backgroundColor: Colors.grey[200],
                              color: Colors.purple,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 30),
                  ],
                ),
        );
      },
    );
  }

  Widget _sectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _analyticsCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }
}
