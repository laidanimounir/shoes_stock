import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/app_strings.dart';
import '../../core/app_colors.dart';
import '../../core/app_session.dart';
import '../../services/report_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<dynamic> _stores = [];
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
    await _fetchStores();
    await _fetchAll();
  }

  Future<void> _fetchStores() async {
    try {
      final res = await Supabase.instance.client
          .from('stores')
          .select()
          .eq('is_active', true)
          .order('name');
      if (mounted) setState(() => _stores = res);
    } catch (e) {
      debugPrint('Error fetching stores: $e');
    }
  }

  Future<void> _fetchAll() async {
    setState(() {
      _isLoading = true;
      _loadingSeasonality = true;
    });
    _animController.reset();
    try {
      final supabase = Supabase.instance.client;

      final statsRes = await supabase.rpc('get_admin_dashboard_stats',
          params: {'p_store_id': _selectedStoreId});
      final chartRes = await supabase.rpc('get_revenue_chart_data', params: {
        'p_store_id': _selectedStoreId,
        'p_period': _chartPeriod,
      });
      final topRes = await supabase.rpc('get_top_products',
          params: {'p_store_id': _selectedStoreId});
      var activityQuery = supabase
          .from('activity_logs')
          .select('id, action_type, description, created_at, user_id');
      if (!AppSession.isOwner && AppSession.currentStoreId != null) {
        activityQuery = activityQuery.eq('store_id', AppSession.currentStoreId!);
      }
      final activityRes = await activityQuery
          .order('created_at', ascending: false)
          .limit(10);
      final debtRes = await supabase
          .from('customers')
          .select('id, full_name, phone, balance')
          .gt('balance', 0)
          .eq('is_active', true)
          .order('balance', ascending: false)
          .limit(5);
      final lowStockRes = await supabase.rpc('get_low_stock_items', params: {
        'p_store_id': _selectedStoreId,
        'p_threshold': 3,
      });
      final slowMovingRes = await supabase.rpc('get_slow_moving_products', params: {
        'p_store_id': _selectedStoreId,
        'p_days': _slowDays,
      });
      final sizeRes = await supabase.rpc('get_size_analytics', params: {
        'p_store_id': _selectedStoreId,
        'p_period': 'month',
      });
      final seasonRes = await supabase.rpc('get_seasonality_report', params: {
        'p_store_id': _selectedStoreId,
        'p_month': _seasonalityMonth,
      });

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
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? _buildShimmer()
                : FadeTransition(
                    opacity: _fadeAnim,
                    child: _buildBody(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    final daysKeys = ['day_sun', 'day_mon', 'day_tue', 'day_wed', 'day_thu', 'day_fri', 'day_sat'];
    final dayKey = daysKeys[now.weekday % 7];
    final monthKey = 'month_${now.month}';
    final dateStr = '${S.t(dayKey)} ${now.day} ${S.t(monthKey)} ${now.year}';

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 0.8),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.gold.withValues(alpha: 0.12),
              border: Border.all(color: AppColors.gold, width: 1.2),
            ),
            child: const Icon(Icons.dashboard_rounded, color: AppColors.gold, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(S.t('dash_title'),
                  style: GoogleFonts.playfairDisplay(
                      color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.bold)),
              Text(dateStr,
                  style: GoogleFonts.raleway(
                      color: AppColors.gold, fontSize: 11, letterSpacing: 0.8)),
            ],
          ),
          const Spacer(),
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border, width: 0.8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedStoreId,
                dropdownColor: AppColors.surface,
                icon: const Icon(Icons.store_outlined, color: AppColors.gold, size: 16),
                style: GoogleFonts.raleway(color: Colors.white, fontSize: 13,
                    fontWeight: FontWeight.w600),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(S.t('inv_all_stores'),
                        style: GoogleFonts.raleway(color: Colors.white70, fontSize: 13)),
                  ),
                  ..._stores.map((s) => DropdownMenuItem(
                        value: s['id'] as String?,
                        child: Text(s['name'],
                            style: GoogleFonts.raleway(color: Colors.white, fontSize: 13)),
                      )),
                ],
                onChanged: (val) {
                  setState(() => _selectedStoreId = val);
                  _fetchAll();
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.35), width: 0.8),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 18),
              onPressed: _fetchAll,
              tooltip: S.t('action_refresh'),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.35), width: 0.8),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.summarize_rounded, color: AppColors.success, size: 18),
              onPressed: () => ReportService.instance.showEndOfDayReportDialog(context, _selectedStoreId),
              tooltip: 'Rapport de Clôture',
            ),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            icon: const Icon(Icons.download_rounded, color: AppColors.gold, size: 18),
            tooltip: 'Exporter',
            onSelected: (v) async {
              if (v == 'sales') await ReportService.instance.generateDailySalesReport(DateTime.now(), _selectedStoreId);
              else if (v == 'inventory') await ReportService.instance.generateInventoryReport(_selectedStoreId);
              else if (v == 'debts') await ReportService.instance.generateDebtReport(_selectedStoreId);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'sales', child: ListTile(leading: Icon(Icons.receipt, size: 18), title: Text('Rapport ventes'))),
              const PopupMenuItem(value: 'inventory', child: ListTile(leading: Icon(Icons.inventory, size: 18), title: Text("Rapport inventaire"))),
              const PopupMenuItem(value: 'debts', child: ListTile(leading: Icon(Icons.money_off, size: 18), title: Text('Rapport dettes'))),
            ],
          ),
        ],
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
            color: AppColors.info,
          ),
          const SizedBox(width: 12),
          _kpiCard(
            title: S.t('dash_today_sales_count'),
            subtitle: S.t('dash_item_count'),
            value: '${(stats['today_sales_count'] as num?)?.toInt() ?? 0}',
            icon: Icons.receipt_long_rounded,
            color: AppColors.teal,
          ),
          const SizedBox(width: 12),
          _kpiCard(
            title: S.t('dash_today_expenses'),
            subtitle: S.t('dash_today'),
            value: '${(stats['today_expenses'] as num?)?.toInt() ?? 0} ${S.t('misc_currency')}',
            icon: Icons.money_off_rounded,
            color: AppColors.danger,
          ),
          const SizedBox(width: 12),
          _kpiCard(
            title: S.t('dash_month_revenue'),
            subtitle: S.t('dash_sales_count'),
            value: '${(stats['month_revenue'] as num?)?.toInt() ?? 0} ${S.t('misc_currency')}',
            icon: Icons.calendar_month_rounded,
            color: AppColors.success,
          ),
          const SizedBox(width: 12),
          _kpiCard(
            title: S.t('dash_month_sales'),
            subtitle: S.t('dash_item_count'),
            value: '${(stats['month_sales_count'] as num?)?.toInt() ?? 0}',
            icon: Icons.shopping_cart_rounded,
            color: AppColors.gold,
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
            color: AppColors.warning,
          ),
          const SizedBox(width: 10),
          _miniKpiCard(
            title: S.t('dash_supplier_debt'),
            value: '${(stats['supplier_debt_total'] as num?)?.toInt() ?? 0} ${S.t('misc_currency')}',
            color: AppColors.danger,
          ),
          const SizedBox(width: 10),
          _miniKpiCard(
            title: S.t('dash_stock_value'),
            value: '${(stats['stock_value'] as num?)?.toInt() ?? 0} ${S.t('misc_currency')}',
            color: AppColors.teal,
          ),
          const SizedBox(width: 10),
          _miniKpiCard(
            title: S.t('dash_total_profit'),
            value: '${(stats['total_profit'] as num?)?.toInt() ?? 0} ${S.t('misc_currency')}',
            color: AppColors.purple,
          ),
          const SizedBox(width: 10),
          _miniKpiCard(
            title: S.t('dash_avg_margin'),
            value: '${(stats['avg_margin'] as num?)?.toInt() ?? 0} ${S.t('misc_currency')}',
            color: AppColors.teal,
          ),
          const SizedBox(width: 10),
          _miniKpiCard(
            title: S.t('dash_low_stock'),
            value: '${(stats['low_stock_count'] as num?)?.toInt() ?? 0}',
            color: AppColors.danger,
          ),
          const SizedBox(width: 10),
          _miniKpiCard(
            title: S.t('dash_active_cust'),
            value: '${(stats['active_customers'] as num?)?.toInt() ?? 0}',
            color: AppColors.purple,
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
          color: AppColors.surface,
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
                      style: GoogleFonts.raleway(
                          color: AppColors.textSecondary, fontSize: 11,
                          fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            Text(value,
                style: GoogleFonts.raleway(
                    color: Colors.white, fontSize: 18,
                    fontWeight: FontWeight.bold),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(subtitle,
                style: GoogleFonts.raleway(
                    color: AppColors.textSecondary, fontSize: 10)),
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15), width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title,
                style: GoogleFonts.raleway(
                    color: AppColors.textSecondary, fontSize: 10,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(value,
                style: GoogleFonts.raleway(
                    color: Colors.white, fontSize: 15,
                    fontWeight: FontWeight.bold),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.8),
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
                        style: GoogleFonts.playfairDisplay(
                            color: Colors.white, fontSize: 14,
                            fontWeight: FontWeight.bold)),
                    Text(S.t('dash_${_chartPeriod}'),
                        style: GoogleFonts.raleway(
                            color: AppColors.textSecondary, fontSize: 11)),
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
                    style: GoogleFonts.raleway(color: AppColors.textSecondary)))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxRevenue > 0 ? (maxRevenue / 4).ceilToDouble() : 1,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: AppColors.border,
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
                                    style: GoogleFonts.raleway(
                                        color: AppColors.textSecondary, fontSize: 9));
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
                                    style: GoogleFonts.raleway(
                                        color: AppColors.textSecondary, fontSize: 9)),
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
                          color: AppColors.info,
                          barWidth: 2.5,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: data.length <= 31,
                            getDotPainter: (spot, percent, barData, index) {
                              if (index == data.length - 1) {
                                return FlDotCirclePainter(
                                  radius: 4,
                                  color: AppColors.info,
                                  strokeWidth: 2,
                                  strokeColor: Colors.white,
                                );
                              }
                              return FlDotCirclePainter(
                                radius: 2,
                                color: AppColors.info.withValues(alpha: 0.5),
                                strokeWidth: 0,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.info.withValues(alpha: 0.08),
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
                                color: AppColors.info,
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
              ? AppColors.info.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? AppColors.info.withValues(alpha: 0.4)
                : AppColors.border,
            width: 0.8,
          ),
        ),
        child: Text(label,
            style: GoogleFonts.raleway(
                color: isSelected ? AppColors.info : AppColors.textSecondary,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400)),
      ),
    );
  }

  Widget _buildTopProductsCard() {
    final products = _topProducts;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.t('dash_top_products_title'),
              style: GoogleFonts.playfairDisplay(
                  color: Colors.white, fontSize: 14,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(S.t('dash_month'),
              style: GoogleFonts.raleway(
                  color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 12),
          Expanded(
            child: products.isEmpty
                ? Center(child: Text(S.t('dash_no_products_sold'),
                    style: GoogleFonts.raleway(color: AppColors.textSecondary)))
                : ListView.separated(
                    itemCount: products.length,
                    separatorBuilder: (_, __) => Divider(
                        color: AppColors.border, height: 1, thickness: 0.5),
                    itemBuilder: (context, index) {
                      final p = products[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 24, height: 24,
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text('${index + 1}',
                                    style: GoogleFonts.raleway(
                                        color: AppColors.gold, fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p['product_name'] ?? '',
                                      style: GoogleFonts.raleway(
                                          color: Colors.white, fontSize: 12,
                                          fontWeight: FontWeight.w600),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text(p['variant_info'] ?? '',
                                      style: GoogleFonts.raleway(
                                          color: AppColors.textSecondary, fontSize: 10)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${p['total_sold'] ?? 0}',
                                    style: GoogleFonts.raleway(
                                        color: AppColors.info, fontSize: 13,
                                        fontWeight: FontWeight.bold)),
                                Text(S.t('dash_item_count'),
                                    style: GoogleFonts.raleway(
                                        color: AppColors.textSecondary, fontSize: 9)),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(S.t('dash_recent_activity'),
                  style: GoogleFonts.playfairDisplay(
                      color: Colors.white, fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: activity.isEmpty
                ? Center(child: Text(S.t('dash_no_activity'),
                    style: GoogleFonts.raleway(color: AppColors.textSecondary)))
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
                                color: AppColors.gold.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                (a['description']?.toString() ?? '').length > 50
                                    ? '${(a['description']?.toString() ?? '').substring(0, 47)}...'
                                    : (a['description']?.toString() ?? ''),
                                style: GoogleFonts.raleway(
                                    color: AppColors.textPrimary, fontSize: 10),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (timeAgo.isNotEmpty)
                              Text(timeAgo,
                                  style: GoogleFonts.raleway(
                                      color: AppColors.textSecondary, fontSize: 9)),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.t('dash_debt_clients'),
              style: GoogleFonts.playfairDisplay(
                  color: Colors.white, fontSize: 13,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(
            child: clients.isEmpty
                ? Center(child: Text(S.t('dash_no_debt_clients'),
                    style: GoogleFonts.raleway(color: AppColors.textSecondary)))
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
                                style: GoogleFonts.raleway(
                                    color: AppColors.textPrimary, fontSize: 11),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${((c['balance'] as num?)?.toInt() ?? 0)} ${S.t('misc_currency')}',
                              style: GoogleFonts.raleway(
                                  color: AppColors.warning, fontSize: 11,
                                  fontWeight: FontWeight.bold),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Stock Faible',
                  style: GoogleFonts.playfairDisplay(
                      color: Colors.white, fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: items.isEmpty
                ? Center(child: Text('Aucun stock faible',
                    style: GoogleFonts.raleway(color: AppColors.textSecondary)))
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
                                color: AppColors.danger.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${item['product_name'] ?? ''} (${item['size'] ?? ''})',
                                style: GoogleFonts.raleway(
                                    color: AppColors.textPrimary, fontSize: 10),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${item['quantity'] ?? 0}',
                              style: GoogleFonts.raleway(
                                  color: AppColors.danger, fontSize: 10,
                                  fontWeight: FontWeight.bold),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.slow_motion_video, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Text('Produits à rotation lente',
                      style: GoogleFonts.playfairDisplay(
                          color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _slowDays,
                    dropdownColor: AppColors.surface,
                    style: GoogleFonts.raleway(
                        fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
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
                  style: GoogleFonts.raleway(color: AppColors.textSecondary, fontSize: 12)),
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
                            color: days > 90 ? AppColors.danger.withValues(alpha: 0.5) : Colors.orange.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${item['product_name'] ?? ''} (${item['size'] ?? ''})',
                            style: GoogleFonts.raleway(color: AppColors.textPrimary, fontSize: 11),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '$days j',
                          style: GoogleFonts.raleway(
                              color: days > 90 ? AppColors.danger : Colors.orange,
                              fontSize: 10, fontWeight: FontWeight.bold),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.straighten, color: AppColors.teal, size: 18),
              const SizedBox(width: 8),
              Text(S.t('size_analytics_title'),
                  style: GoogleFonts.playfairDisplay(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          if (data.isEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(S.t('dash_no_data'),
                  style: GoogleFonts.raleway(color: AppColors.textSecondary, fontSize: 12)),
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
                          style: GoogleFonts.raleway(
                              color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: barWidth.clamp(0.0, 1.0),
                          backgroundColor: AppColors.teal.withValues(alpha: 0.15),
                          color: AppColors.teal,
                          minHeight: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 70,
                      child: Text('$sold ${S.t('dash_item_count')}',
                          style: GoogleFonts.raleway(
                              color: AppColors.textSecondary, fontSize: 11)),
                    ),
                    SizedBox(
                      width: 60,
                      child: Text('${revenue.toStringAsFixed(0)} ${S.t('misc_currency')}',
                          style: GoogleFonts.raleway(
                              color: AppColors.teal, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text('${pct.toStringAsFixed(1)}%',
                          style: GoogleFonts.raleway(
                              color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w600)),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month, color: AppColors.teal, size: 18),
              const SizedBox(width: 8),
              Text('Analyse Saisonnière',
                  style: GoogleFonts.playfairDisplay(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
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
                        style: GoogleFonts.raleway(
                            fontSize: 12,
                            color: selected ? Colors.white : AppColors.teal)),
                    selected: selected,
                    selectedColor: AppColors.teal,
                    backgroundColor: AppColors.teal.withValues(alpha: 0.15),
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
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.teal),
            ))
          else if (_seasonalityData.isEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(S.t('dash_no_data'),
                  style: GoogleFonts.raleway(color: AppColors.textSecondary, fontSize: 12)),
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
    final colors = [AppColors.teal, AppColors.gold, AppColors.purple];

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
                    child: Text('${years[idx]}',
                        style: GoogleFonts.raleway(
                            color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
                      style: GoogleFonts.raleway(fontSize: 9, color: AppColors.textSecondary));
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
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text('Année',
                  style: GoogleFonts.raleway(color: AppColors.teal, fontWeight: FontWeight.bold, fontSize: 11))),
              Expanded(child: Text('Revenu',
                  style: GoogleFonts.raleway(color: AppColors.teal, fontWeight: FontWeight.bold, fontSize: 11))),
              Expanded(child: Text('Unités',
                  style: GoogleFonts.raleway(color: AppColors.teal, fontWeight: FontWeight.bold, fontSize: 11))),
              Expanded(child: Text('Top Catégorie',
                  style: GoogleFonts.raleway(color: AppColors.teal, fontWeight: FontWeight.bold, fontSize: 11))),
            ],
          ),
          const Divider(color: AppColors.border),
          ...sorted.map((d) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(child: Text('${d['year']}',
                    style: GoogleFonts.raleway(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12))),
                Expanded(child: Text('${NumberFormat('#,##0', 'fr').format((d['total_revenue'] as num).toInt())} ${S.t('misc_currency')}',
                    style: GoogleFonts.raleway(color: AppColors.textSecondary, fontSize: 11))),
                Expanded(child: Text('${d['total_units']}',
                    style: GoogleFonts.raleway(color: AppColors.textSecondary, fontSize: 11))),
                Expanded(child: Text(d['top_category'] ?? '-',
                    style: GoogleFonts.raleway(color: AppColors.gold, fontSize: 11),
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
          color: Color.lerp(AppColors.surface, AppColors.surfaceLight, _anim.value),
          border: Border.all(
              color: AppColors.border, width: 0.8),
        ),
      ),
    );
  }
}
