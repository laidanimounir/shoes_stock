import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/app_strings.dart';
import '../../theme/app_text_styles.dart';
import '../../core/app_session.dart';

class _T {
  _T._();
  static const bgPage = Color(0xFF0A0A14);
  static const statusUnpaidBg = Color(0xFF2B0D0D);
  static const statusPaidText = Color(0xFF4ADE80);
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _selectedStoreId;

  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _chartData = [];
  String _chartPeriod = 'month';
  List<Map<String, dynamic>> _topProducts = [];
  List<Map<String, dynamic>> _recentActivity = [];
  List<Map<String, dynamic>> _debtClients = [];
  List<dynamic> _lowStockItems = [];
  List<Map<String, dynamic>> _slowMoving = [];
  int _slowDays = 60;
  List<Map<String, dynamic>> _sizeAnalytics = [];
  int _seasonalityMonth = DateTime.now().month;
  List<Map<String, dynamic>> _seasonalityData = [];
  bool _loadingSeasonality = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _init();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() {
      _isLoading = true;
      _loadingSeasonality = true;
    });
    _animController.reset();
    try {
      final supabase = Supabase.instance.client;

      final results = await Future.wait<dynamic>([
        supabase.rpc('get_admin_dashboard_stats',
            params: {'p_store_id': _selectedStoreId}),
        supabase.rpc('get_revenue_chart_data', params: {
          'p_store_id': _selectedStoreId,
          'p_period': _chartPeriod,
        }),
        supabase.rpc('get_top_products',
            params: {'p_store_id': _selectedStoreId}),
        _fetchActivityLogs(supabase),
        _fetchDebtCustomers(supabase),
        supabase.rpc('get_low_stock_items', params: {
          'p_store_id': _selectedStoreId,
          'p_threshold': 3,
        }),
        supabase.rpc('get_slow_moving_products', params: {
          'p_store_id': _selectedStoreId,
          'p_days': _slowDays,
        }),
        supabase.rpc('get_size_analytics', params: {
          'p_store_id': _selectedStoreId,
          'p_period': 'month',
        }),
        supabase.rpc('get_seasonality_report', params: {
          'p_store_id': _selectedStoreId,
          'p_month': _seasonalityMonth,
        }),
      ]);

      final statsRes = results[0];
      final chartRes = results[1];
      final topRes = results[2];
      final activityRes = results[3];
      final debtRes = results[4];
      final lowStockRes = results[5];
      final slowMovingRes = results[6];
      final sizeRes = results[7];
      final seasonRes = results[8];

      if (mounted) {
        setState(() {
          _stats = statsRes as Map<String, dynamic>;
          _chartData = (chartRes as List<dynamic>).cast<Map<String, dynamic>>();
          _topProducts = (topRes as List<dynamic>).cast<Map<String, dynamic>>();
          _recentActivity = (activityRes as List<dynamic>).cast<Map<String, dynamic>>();
          _debtClients = (debtRes as List<dynamic>).cast<Map<String, dynamic>>();
          _lowStockItems = List<Map<String, dynamic>>.from(lowStockRes ?? []);
          _slowMoving = (slowMovingRes as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
          _sizeAnalytics = List<Map<String, dynamic>>.from(sizeRes ?? []);
          _seasonalityData = List<Map<String, dynamic>>.from(seasonRes ?? []);
          _loadingSeasonality = false;
          _isLoading = false;
        });
        _animController.forward();
      }
    } catch (e) {
      debugPrint('Error fetching dashboard data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _animController.forward();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.t('error_loading_data'), style: TextStyle(color: _T.statusPaidText)),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: _T.statusUnpaidBg,
          ),
        );
      }
    }
  }

  Future<List<dynamic>> _fetchActivityLogs(SupabaseClient supabase) async {
    var query = supabase
        .from('activity_logs')
        .select('id, action_type, description, created_at, user_id');
    if (!AppSession.isOwner && AppSession.currentStoreId != null) {
      query = query.eq('store_id', AppSession.currentStoreId!);
    }
    return query.order('created_at', ascending: false).limit(10);
  }

  Future<List<dynamic>> _fetchDebtCustomers(SupabaseClient supabase) async {
    return supabase
        .from('customers')
        .select('id, full_name, phone, balance')
        .gt('balance', 0)
        .eq('is_active', true)
        .order('balance', ascending: false)
        .limit(5);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bgPage,
      body: _isLoading
          ? _buildShimmer()
          : FadeTransition(
              opacity: _fadeAnim,
              child: _buildBody(),
            ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildKpiRow(),
          const SizedBox(height: 16),
          _buildSecondaryKpiRow(),
          const SizedBox(height: 20),
          _buildBottomRow(),
          const SizedBox(height: 20),
          _buildSlowMovingSection(),
          const SizedBox(height: 20),
          _buildSizeAnalyticsSection(),
          const SizedBox(height: 20),
          _buildSeasonalitySection(),
        ],
      ),
    );
  }

  Widget _buildKpiRow() {
    final stats = _stats;
    return SizedBox(
      height: 120,
      child: Row(
        children: [
          _kpiCard(
            title: S.t('dash_revenue'),
            subtitle: S.t('dash_today'),
            value: '${(stats['today_revenue'] as num?)?.toInt() ?? 0} ${S.t('misc_currency')}',
            icon: Icons.trending_up_rounded,
            color: const Color(0xFF58A6FF),
          ),
          const SizedBox(width: 12),
          _kpiCard(
            title: S.t('dash_today_sales_count'),
            subtitle: S.t('dash_item_count'),
            value: '${(stats['today_sales_count'] as num?)?.toInt() ?? 0}',
            icon: Icons.receipt_long_rounded,
            color: const Color(0xFF58A6FF),
          ),
          const SizedBox(width: 12),
          _kpiCard(
            title: S.t('dash_today_expenses'),
            subtitle: S.t('dash_today'),
            value: '${(stats['today_expenses'] as num?)?.toInt() ?? 0} ${S.t('misc_currency')}',
            icon: Icons.money_off_rounded,
            color: const Color(0xFFF87171),
          ),
          const SizedBox(width: 12),
          _kpiCard(
            title: S.t('dash_month_revenue'),
            subtitle: S.t('dash_sales_count'),
            value: '${(stats['month_revenue'] as num?)?.toInt() ?? 0} ${S.t('misc_currency')}',
            icon: Icons.calendar_month_rounded,
            color: const Color(0xFF4ADE80),
          ),
          const SizedBox(width: 12),
          _kpiCard(
            title: S.t('dash_month_sales'),
            subtitle: S.t('dash_item_count'),
            value: '${(stats['month_sales_count'] as num?)?.toInt() ?? 0}',
            icon: Icons.shopping_cart_rounded,
            color: const Color(0xFFF0A500),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryKpiRow() {
    final stats = _stats;
    return SizedBox(
      height: 90,
      child: Row(
        children: [
          _miniKpiCard(
            title: S.t('dash_customer_debt'),
            value: '${(stats['customer_debt_total'] as num?)?.toInt() ?? 0} ${S.t('misc_currency')}',
            color: const Color(0xFFFBBF24),
          ),
          const SizedBox(width: 10),
          _miniKpiCard(
            title: S.t('dash_supplier_debt'),
            value: '${(stats['supplier_debt_total'] as num?)?.toInt() ?? 0} ${S.t('misc_currency')}',
            color: const Color(0xFFF87171),
          ),
          const SizedBox(width: 10),
          _miniKpiCard(
            title: S.t('dash_stock_value'),
            value: '${(stats['stock_value'] as num?)?.toInt() ?? 0} ${S.t('misc_currency')}',
            color: const Color(0xFF58A6FF),
          ),
          const SizedBox(width: 10),
          _miniKpiCard(
            title: S.t('dash_total_profit'),
            value: '${(stats['total_profit'] as num?)?.toInt() ?? 0} ${S.t('misc_currency')}',
            color: const Color(0xFF58A6FF),
          ),
          const SizedBox(width: 10),
          _miniKpiCard(
            title: S.t('dash_avg_margin'),
            value: '${(stats['avg_margin'] as num?)?.toInt() ?? 0} ${S.t('misc_currency')}',
            color: const Color(0xFF58A6FF),
          ),
          const SizedBox(width: 10),
          _miniKpiCard(
            title: S.t('dash_low_stock'),
            value: '${(stats['low_stock_count'] as num?)?.toInt() ?? 0}',
            color: const Color(0xFFF87171),
          ),
          const SizedBox(width: 10),
          _miniKpiCard(
            title: S.t('dash_active_cust'),
            value: '${(stats['active_customers'] as num?)?.toInt() ?? 0}',
            color: const Color(0xFF58A6FF),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomRow() {
    return SizedBox(
      height: 400,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: _buildChartCard(),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: _buildTopProductsCard(),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildRecentActivityCard(),
                ),
                const SizedBox(height: 12),
                Expanded(
                  flex: 2,
                  child: _buildLowStockCard(),
                ),
                const SizedBox(height: 12),
                Expanded(
                  flex: 2,
                  child: _buildDebtClientsCard(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiCard({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF13131F),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: AppTextStyles.bodyMedium(
                          color: const Color(0xFF9090A8)),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            Text(value,
                style: AppTextStyles.bodyMedium(
                    color: const Color(0xFFEEEEFF)),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(subtitle,
                style: AppTextStyles.bodyMedium(
                    color: const Color(0xFF9090A8))),
          ],
        ),
      ),
    );
  }

  Widget _miniKpiCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF13131F),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15), width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title,
                style: AppTextStyles.bodyMedium(
                    color: const Color(0xFF9090A8))),
            const SizedBox(height: 4),
            Text(value,
                style: AppTextStyles.bodyMedium(
                    color: const Color(0xFFEEEEFF)),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard() {
    final data = _chartData;
    final maxRevenue = data.fold<double>(0, (p, v) => p > ((v['revenue'] as num?)?.toDouble() ?? 0) ? p : ((v['revenue'] as num?)?.toDouble() ?? 0));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF13131F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E1E35), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(S.t('dash_revenue_chart'),
                        style: AppTextStyles.headingLarge(
                            color: const Color(0xFFEEEEFF))),
                    Text(S.t('dash_${_chartPeriod}'),
                        style: AppTextStyles.bodyMedium(
                            color: const Color(0xFF9090A8))),
                  ],
                ),
              ),
              Row(
                children: [
                  _periodChip('week', S.t('dash_week')),
                  const SizedBox(width: 4),
                  _periodChip('month', S.t('dash_month')),
                  const SizedBox(width: 4),
                  _periodChip('3months', S.t('dash_3months')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: data.isEmpty
                ? Center(child: Text(S.t('dash_no_data'),
                    style: AppTextStyles.bodyMedium(color: const Color(0xFF9090A8))))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxRevenue > 0 ? (maxRevenue / 4).ceilToDouble() : 1,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: const Color(0xFF1E1E35),
                          strokeWidth: 0.5,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 44,
                            getTitlesWidget: (value, meta) {
                              final v = value.toInt();
                              if (v % 2 == 0 || v == 0) {
                                return Text('$v',
                                    style: AppTextStyles.bodyMedium(
                                        color: const Color(0xFF9090A8)));
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: (data.length / 5).ceilToDouble().clamp(1, double.infinity),
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                              final day = data[idx]['day'] as String? ?? '';
                              final parts = day.split('-');
                              final label = parts.length >= 3 ? '${parts[2]}/${parts[1]}' : day;
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(label,
                                    style: AppTextStyles.bodyMedium(
                                        color: const Color(0xFF9090A8))),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(data.length, (i) {
                            final rev = (data[i]['revenue'] as num?)?.toDouble() ?? 0;
                            return FlSpot(i.toDouble(), rev);
                          }),
                          isCurved: true,
                          color: const Color(0xFF58A6FF),
                          barWidth: 2.5,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: data.length <= 31,
                            getDotPainter: (spot, percent, barData, index) {
                              if (index == data.length - 1) {
                                return FlDotCirclePainter(
                                  radius: 4,
                                  color: const Color(0xFF58A6FF),
                                  strokeWidth: 2,
                                  strokeColor: Colors.white,
                                );
                              }
                              return FlDotCirclePainter(
                                radius: 2,
                                color: const Color(0xFF58A6FF).withValues(alpha: 0.5),
                                strokeWidth: 0,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(0xFF58A6FF).withValues(alpha: 0.08),
                          ),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                            final rev = spot.y.toInt();
                            return LineTooltipItem(
                              '$rev ${S.t('misc_currency')}',
                              TextStyle(
                                color: const Color(0xFF58A6FF),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _periodChip(String period, String label) {
    final isSelected = _chartPeriod == period;
    return GestureDetector(
      onTap: () {
        setState(() => _chartPeriod = period);
        _fetchAll();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF58A6FF).withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF58A6FF).withValues(alpha: 0.4)
                : const Color(0xFF1E1E35),
            width: 0.8,
          ),
        ),
        child: Text(label,
            style: AppTextStyles.bodyMedium(
                color: isSelected ? const Color(0xFF58A6FF) : const Color(0xFF9090A8))),
      ),
    );
  }

  Widget _buildTopProductsCard() {
    final products = _topProducts;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF13131F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E1E35), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.t('dash_top_products_title'),
              style: AppTextStyles.headingLarge(
                  color: const Color(0xFFEEEEFF))),
          const SizedBox(height: 4),
          Text(S.t('dash_month'),
              style: AppTextStyles.bodyMedium(
                  color: const Color(0xFF9090A8))),
          const SizedBox(height: 12),
          Expanded(
            child: products.isEmpty
                ? Center(child: Text(S.t('dash_no_products_sold'),
                    style: AppTextStyles.bodyMedium(color: const Color(0xFF9090A8))))
                : ListView.separated(
                    itemCount: products.length,
                    separatorBuilder: (_, __) => Divider(
                        color: const Color(0xFF1E1E35), height: 1, thickness: 0.5),
                    itemBuilder: (context, index) {
                      final p = products[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 24, height: 24,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0A500).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text('${index + 1}',
                                    style: AppTextStyles.bodyMedium(
                                        color: const Color(0xFFF0A500))),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p['product_name'] ?? '',
                                      style: AppTextStyles.bodyMedium(
                                          color: const Color(0xFFEEEEFF)),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text(p['variant_info'] ?? '',
                                      style: AppTextStyles.bodyMedium(
                                          color: const Color(0xFF9090A8))),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${p['total_sold'] ?? 0}',
                                    style: AppTextStyles.bodyMedium(
                                        color: const Color(0xFF58A6FF))),
                                Text(S.t('dash_item_count'),
                                    style: AppTextStyles.bodyMedium(
                                        color: const Color(0xFF9090A8))),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityCard() {
    final activity = _recentActivity;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF13131F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E1E35), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(S.t('dash_recent_activity'),
                  style: AppTextStyles.headingLarge(
                      color: const Color(0xFFEEEEFF))),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: activity.isEmpty
                ? Center(child: Text(S.t('dash_no_activity'),
                    style: AppTextStyles.bodyMedium(color: const Color(0xFF9090A8))))
                : ListView.builder(
                    itemCount: activity.length,
                    itemBuilder: (context, index) {
                      final a = activity[index];
                      final createdAt = a['created_at'] as String?;
                      final timeAgo = createdAt != null
                          ? timeago.format(DateTime.parse(createdAt), locale: 'fr_short')
                          : '';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 6, height: 6,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0A500).withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                (a['description']?.toString() ?? '').length > 50
                                    ? '${(a['description']?.toString() ?? '').substring(0, 47)}...'
                                    : (a['description']?.toString() ?? ''),
                                style: AppTextStyles.bodyMedium(
                                    color: const Color(0xFFEEEEFF)),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (timeAgo.isNotEmpty)
                              Text(timeAgo,
                                  style: AppTextStyles.bodyMedium(
                                      color: const Color(0xFF9090A8))),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtClientsCard() {
    final clients = _debtClients;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF13131F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E1E35), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.t('dash_debt_clients'),
              style: AppTextStyles.headingLarge(
                  color: const Color(0xFFEEEEFF))),
          const SizedBox(height: 8),
          Expanded(
            child: clients.isEmpty
                ? Center(child: Text(S.t('dash_no_debt_clients'),
                    style: AppTextStyles.bodyMedium(color: const Color(0xFF9090A8))))
                : ListView.builder(
                    itemCount: clients.length,
                    itemBuilder: (context, index) {
                      final c = clients[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                (c['full_name']?.toString() ?? '').length > 20
                                    ? '${(c['full_name']?.toString() ?? '').substring(0, 18)}...'
                                    : (c['full_name'] ?? ''),
                                style: AppTextStyles.bodyMedium(
                                    color: const Color(0xFFEEEEFF)),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${((c['balance'] as num?)?.toInt() ?? 0)} ${S.t('misc_currency')}',
                              style: AppTextStyles.bodyMedium(
                                  color: const Color(0xFFFBBF24)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockCard() {
    final items = _lowStockItems;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF13131F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E1E35), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Stock Faible',
                  style: AppTextStyles.headingLarge(
                      color: const Color(0xFFEEEEFF))),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: items.isEmpty
                ? Center(child: Text('Aucun stock faible',
                    style: AppTextStyles.bodyMedium(color: const Color(0xFF9090A8))))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 6, height: 6,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF87171).withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${item['product_name'] ?? ''} (${item['size'] ?? ''})',
                                style: AppTextStyles.bodyMedium(
                                    color: const Color(0xFFEEEEFF)),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${item['quantity'] ?? 0}',
                              style: AppTextStyles.bodyMedium(
                                  color: const Color(0xFFF87171)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlowMovingSection() {
    final items = _slowMoving;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF13131F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E1E35), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.slow_motion_video, color: const Color(0xFFF0A500), size: 18),
                  const SizedBox(width: 8),
                  Text('Produits à rotation lente',
                      style: AppTextStyles.headingLarge(
                          color: const Color(0xFFEEEEFF))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0A500).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _slowDays,
                    dropdownColor: const Color(0xFF13131F),
                    style: AppTextStyles.bodyMedium(
                        color: const Color(0xFFF0A500)),
                    items: const [
                      DropdownMenuItem(value: 30, child: Text('30j')),
                      DropdownMenuItem(value: 60, child: Text('60j')),
                      DropdownMenuItem(value: 90, child: Text('90j')),
                    ],
                    onChanged: (v) {
                      if (v != null) { setState(() => _slowDays = v); _fetchAll(); }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Aucun produit lent',
                  style: AppTextStyles.bodyMedium(color: const Color(0xFF9090A8))),
            ))
          else
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final days = (item['days_since_last_sale'] as num?)?.toInt() ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                            color: days > 90 ? const Color(0xFFF87171).withValues(alpha: 0.5) : const Color(0xFFF0A500).withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${item['product_name'] ?? ''} (${item['size'] ?? ''})',
                            style: AppTextStyles.bodyMedium(color: const Color(0xFFEEEEFF)),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '$days j',
                          style: AppTextStyles.bodyMedium(
                              color: days > 90 ? const Color(0xFFF87171) : const Color(0xFFF0A500)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSizeAnalyticsSection() {
    final data = _sizeAnalytics;
    final maxSold = data.fold<int>(0, (p, v) => p > ((v['total_sold'] as num?)?.toInt() ?? 0) ? p : ((v['total_sold'] as num?)?.toInt() ?? 0));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF13131F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E1E35), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.straighten, color: const Color(0xFF58A6FF), size: 18),
              const SizedBox(width: 8),
              Text(S.t('size_analytics_title'),
                  style: AppTextStyles.headingLarge(
                      color: const Color(0xFFEEEEFF))),
            ],
          ),
          const SizedBox(height: 12),
          if (data.isEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(S.t('dash_no_data'),
                  style: AppTextStyles.bodyMedium(color: const Color(0xFF9090A8))),
            ))
          else
            ...data.map((item) {
              final size = item['size'] as String? ?? '-';
              final sold = (item['total_sold'] as num?)?.toInt() ?? 0;
              final revenue = (item['revenue'] as num?)?.toDouble() ?? 0;
              final pct = (item['pct_of_total'] as num?)?.toDouble() ?? 0;
              final barWidth = maxSold > 0 ? (sold / maxSold) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(size,
                          style: AppTextStyles.bodyMedium(
                              color: Colors.white,)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: barWidth.clamp(0.0, 1.0),
                          backgroundColor: const Color(0xFF58A6FF).withValues(alpha: 0.15),
                          color: const Color(0xFF58A6FF),
                          minHeight: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 70,
                      child: Text('$sold ${S.t('dash_item_count')}',
                          style: AppTextStyles.bodyMedium(
                              color: const Color(0xFF9090A8))),
                    ),
                    SizedBox(
                      width: 60,
                      child: Text('${revenue.toStringAsFixed(0)} ${S.t('misc_currency')}',
                          style: AppTextStyles.bodyMedium(
                              color: const Color(0xFF58A6FF))),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text('${pct.toStringAsFixed(1)}%',
                          style: AppTextStyles.bodyMedium(
                              color: const Color(0xFFF0A500))),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _fetchSeasonality() async {
    if (!mounted) return;
    setState(() => _loadingSeasonality = true);
    try {
      final res = await Supabase.instance.client.rpc('get_seasonality_report', params: {
        'p_store_id': _selectedStoreId,
        'p_month': _seasonalityMonth,
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

  Widget _buildSeasonalitySection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF13131F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E1E35), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month, color: const Color(0xFF58A6FF), size: 18),
              const SizedBox(width: 8),
              Text('Analyse Saisonnière',
                  style: AppTextStyles.headingLarge(
                      color: const Color(0xFFEEEEFF))),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: List.generate(12, (i) {
                final m = i + 1;
                final selected = _seasonalityMonth == m;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(DateFormat('MMM', 'fr').format(DateTime(2020, m)),
                        style: AppTextStyles.bodyMedium(
                            color: selected ? Colors.white : const Color(0xFF58A6FF))),
                    selected: selected,
                    selectedColor: const Color(0xFF58A6FF),
                    backgroundColor: const Color(0xFF58A6FF).withValues(alpha: 0.15),
                    onSelected: (_) {
                      setState(() => _seasonalityMonth = m);
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
              child: CircularProgressIndicator(strokeWidth: 2, color: const Color(0xFF58A6FF)),
            ))
          else if (_seasonalityData.isEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(S.t('dash_no_data'),
                  style: AppTextStyles.bodyMedium(color: const Color(0xFF9090A8))),
            ))
          else
            _buildSeasonalityChart(),
          const SizedBox(height: 12),
          if (_seasonalityData.isNotEmpty) _buildAdminSeasonalityTable(),
        ],
      ),
    );
  }

  Widget _buildSeasonalityChart() {
    final sorted = List<Map<String, dynamic>>.from(_seasonalityData)
      ..sort((a, b) => (a['year'] as int).compareTo(b['year'] as int));
    final years = sorted.map((e) => e['year'] as int).toList();
    final maxRevenue = sorted.fold<double>(0, (p, v) => p > (v['total_revenue'] as num).toDouble() ? p : (v['total_revenue'] as num).toDouble());
    final colors = [const Color(0xFF58A6FF), const Color(0xFFF0A500), const Color(0xFF58A6FF)];

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
                  const TextStyle(color: const Color(0xFFEEEEFF)),
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
                    child: Text('${years[idx]}',
                        style: AppTextStyles.bodyMedium(
                            color: const Color(0xFFEEEEFF))),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text('${value.toInt()}',
                      style: AppTextStyles.bodyMedium(color: const Color(0xFF9090A8)));
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

  Widget _buildAdminSeasonalityTable() {
    final sorted = List<Map<String, dynamic>>.from(_seasonalityData)
      ..sort((a, b) => (b['year'] as int).compareTo(a['year'] as int));
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _T.bgPage,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text('Année',
                  style: AppTextStyles.bodyMedium(color: const Color(0xFF58A6FF)))),
              Expanded(child: Text('Revenu',
                  style: AppTextStyles.bodyMedium(color: const Color(0xFF58A6FF)))),
              Expanded(child: Text('Unités',
                  style: AppTextStyles.bodyMedium(color: const Color(0xFF58A6FF)))),
              Expanded(child: Text('Top Catégorie',
                  style: AppTextStyles.bodyMedium(color: const Color(0xFF58A6FF)))),
            ],
          ),
          const Divider(color: const Color(0xFF1E1E35)),
          ...sorted.map((d) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(child: Text('${d['year']}',
                    style: const TextStyle(fontSize: 14, color: Color(0xFFEEEEFF)))),
                Expanded(child: Text('${NumberFormat('#,##0', 'fr').format((d['total_revenue'] as num).toInt())} ${S.t('misc_currency')}',
                    style: AppTextStyles.bodyMedium(color: const Color(0xFF9090A8)))),
                Expanded(child: Text('${d['total_units']}',
                    style: AppTextStyles.bodyMedium(color: const Color(0xFF9090A8)))),
                Expanded(child: Text(d['top_category'] ?? '-',
                    style: AppTextStyles.bodyMedium(color: const Color(0xFFF0A500)),
                    overflow: TextOverflow.ellipsis)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          SizedBox(
            height: 120,
            child: Row(
              children: List.generate(5, (i) => [
                Expanded(child: _ShimmerBox()),
                if (i < 4) const SizedBox(width: 12),
              ]).expand((e) => e).toList(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 90,
            child: Row(
              children: List.generate(5, (i) => [
                Expanded(child: _ShimmerBox()),
                if (i < 4) const SizedBox(width: 10),
              ]).expand((e) => e).toList(),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              children: [
                Expanded(flex: 3, child: _ShimmerBox()),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: _ShimmerBox()),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: _ShimmerBox()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Color.lerp(const Color(0xFF13131F), _T.bgPage, _anim.value),
          border: Border.all(
              color: const Color(0xFF1E1E35), width: 0.8),
        ),
      ),
    );
  }
}
