import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
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
  int _selectedMonth = DateTime.now().month;
  List<Map<String, dynamic>> _seasonalityData = [];
  bool _loadingSeasonality = false;

  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
    _fetchSeasonality();
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

  Future<void> _fetchSeasonality() async {
    if (!mounted) return;
    setState(() => _loadingSeasonality = true);
    try {
      final res = await Supabase.instance.client.rpc('get_seasonality_report', params: {
        'p_month': _selectedMonth,
      });
      if (mounted) {
        setState(() {
          _seasonalityData = List<Map<String, dynamic>>.from(res ?? []);
          _loadingSeasonality = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching seasonality: $e');
      if (mounted) setState(() => _loadingSeasonality = false);
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
                    const SizedBox(height: 24),
                    _buildSeasonalitySection(),
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

  Widget _buildSeasonalitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Analyse Saisonnière', Icons.calendar_month, Colors.teal),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: List.generate(12, (i) {
              final m = i + 1;
              final selected = _selectedMonth == m;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(DateFormat('MMM', 'fr').format(DateTime(2020, m)),
                      style: TextStyle(fontSize: 12, color: selected ? Colors.white : Colors.teal[700])),
                  selected: selected,
                  selectedColor: Colors.teal,
                  backgroundColor: Colors.teal[50],
                  onSelected: (_) {
                    setState(() => _selectedMonth = m);
                    _fetchSeasonality();
                  },
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 16),
        if (_loadingSeasonality)
          const Center(child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(strokeWidth: 2),
          ))
        else if (_seasonalityData.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Aucune donnée pour ce mois', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          ))
        else
          _buildSeasonalityChart(),
        const SizedBox(height: 12),
        if (_seasonalityData.isNotEmpty) _buildSeasonalityTable(),
      ],
    );
  }

  Widget _buildSeasonalityChart() {
    final sorted = List<Map<String, dynamic>>.from(_seasonalityData)
      ..sort((a, b) => (a['year'] as int).compareTo(b['year'] as int));
    final years = sorted.map((e) => e['year'] as int).toList();
    final maxRevenue = sorted.fold<double>(0, (p, v) => p > (v['total_revenue'] as num).toDouble() ? p : (v['total_revenue'] as num).toDouble());
    final colors = [Colors.teal[300]!, Colors.teal[600]!, Colors.teal[900]!];

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxRevenue * 1.2,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${years[groupIndex]}\n${NumberFormat('#,##0', 'fr').format(rod.toY.toInt())} ${S.t('misc_currency')}',
                  const TextStyle(color: Colors.white, fontSize: 11),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= years.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${years[idx]}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text('${value.toInt()}', style: const TextStyle(fontSize: 9, color: Colors.grey));
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxRevenue > 0 ? (maxRevenue / 4) : 1,
          ),
          borderData: FlBorderData(show: false),
          barGroups: sorted.asMap().entries.map((entry) {
            final i = entry.key;
            final d = entry.value;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: (d['total_revenue'] as num).toDouble(),
                  color: colors[i % colors.length],
                  width: 24,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSeasonalityTable() {
    final sorted = List<Map<String, dynamic>>.from(_seasonalityData)
      ..sort((a, b) => (b['year'] as int).compareTo(a['year'] as int));
    return Container(
      decoration: BoxDecoration(
        color: Colors.teal[50],
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text('Année', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal[800]))),
              Expanded(child: Text('Revenu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal[800]))),
              Expanded(child: Text('Unités', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal[800]))),
              Expanded(child: Text('Top Catégorie', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal[800]))),
            ],
          ),
          const Divider(color: Colors.teal),
          ...sorted.map((d) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(child: Text('${d['year']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                Expanded(child: Text('${NumberFormat('#,##0', 'fr').format((d['total_revenue'] as num).toInt())} ${S.t('misc_currency')}', style: const TextStyle(fontSize: 12))),
                Expanded(child: Text('${d['total_units']}', style: const TextStyle(fontSize: 12))),
                Expanded(child: Text(d['top_category'] ?? '-', style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
