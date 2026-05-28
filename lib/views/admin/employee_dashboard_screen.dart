import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/app_strings.dart';
import '../../core/app_colors.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  State<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _mySales = [];

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
    _fetchData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _commissionSummary = {};

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    _animController.reset();
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final statsRes = await supabase.rpc('get_employee_dashboard_stats');
      final mySalesRes = await supabase
          .from('invoices')
          .select('id, total_amount, created_at, customer:customer_id(full_name)')
          .eq('user_id', user.id)
          .eq('type', 'out')
          .order('created_at', ascending: false)
          .limit(10);

      Map<String, dynamic> commission = {};
      try {
        commission = await supabase.rpc('get_employee_commission_summary', params: {
          'p_user_id': user.id,
          'p_period': 'month',
        }) as Map<String, dynamic>;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _stats = statsRes as Map<String, dynamic>;
          _mySales = (mySalesRes as List<dynamic>).cast<Map<String, dynamic>>();
          _commissionSummary = commission;
          _isLoading = false;
        });
        _animController.forward();
      }
    } catch (e) {
      debugPrint('Error fetching employee dashboard: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _animController.forward();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysKeys = ['day_sun', 'day_mon', 'day_tue', 'day_wed', 'day_thu', 'day_fri', 'day_sat'];
    final dayKey = daysKeys[now.weekday % 7];
    final monthKey = 'month_${now.month}';
    final dateStr = '${S.t(dayKey)} ${now.day} ${S.t(monthKey)} ${now.year}';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 20),
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
                    Text(S.t('dash_employee_dashboard'),
                        style: GoogleFonts.playfairDisplay(
                            color: Colors.white, fontSize: 15,
                            fontWeight: FontWeight.bold)),
                    Text(dateStr,
                        style: GoogleFonts.raleway(
                            color: AppColors.gold, fontSize: 11, letterSpacing: 0.8)),
                  ],
                ),
                const Spacer(),
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.35), width: 0.8),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 18),
                    onPressed: _fetchData,
                    tooltip: S.t('action_refresh'),
                  ),
                ),
              ],
            ),
          ),
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

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildKpiRow(),
          const SizedBox(height: 20),
          _buildCommissionCard(),
          const SizedBox(height: 20),
          _buildMySalesCard(),
          const SizedBox(height: 20),
          _buildLowStockCard(),
        ],
      ),
    );
  }

  Widget _buildKpiRow() {
    final stats = _stats;
    return SizedBox(
      height: 100,
      child: Row(
        children: [
          _miniCard(
            title: S.t('dash_my_sales_today'),
            value: '${(stats['my_sales_today'] as num?)?.toInt() ?? 0}',
            icon: Icons.person_rounded,
            color: AppColors.gold,
          ),
          const SizedBox(width: 12),
          _miniCard(
            title: S.t('dash_today_sales_count'),
            value: '${(stats['today_sales_count'] as num?)?.toInt() ?? 0}',
            icon: Icons.receipt_long_rounded,
            color: AppColors.teal,
          ),
          const SizedBox(width: 12),
          _miniCard(
            title: S.t('dash_today_revenue'),
            value: '${(stats['today_revenue'] as num?)?.toInt() ?? 0} ${S.t('misc_currency')}',
            icon: Icons.trending_up_rounded,
            color: AppColors.info,
          ),
          const SizedBox(width: 12),
          _miniCard(
            title: S.t('dash_low_stock'),
            value: '${(stats['low_stock_count'] as num?)?.toInt() ?? 0}',
            icon: Icons.warning_rounded,
            color: AppColors.danger,
          ),
        ],
      ),
    );
  }

  Widget _miniCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 0.8),
        ),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(value,
                      style: GoogleFonts.raleway(
                          color: Colors.white, fontSize: 17,
                          fontWeight: FontWeight.bold),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(title,
                      style: GoogleFonts.raleway(
                          color: AppColors.textSecondary, fontSize: 9,
                          fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommissionCard() {
    final totalComm = (_commissionSummary['total_commission'] as num?)?.toDouble() ?? 0;
    final rate = (_commissionSummary['avg_commission_rate'] as num?)?.toDouble() ?? 0;
    final salesCount = (_commissionSummary['sales_count'] as num?)?.toInt() ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.monetization_on_rounded, color: AppColors.gold, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('COMMISSION DU MOIS', style: GoogleFonts.raleway(color: AppColors.textSecondary, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
              const SizedBox(height: 4),
              Text('${totalComm.toStringAsFixed(0)} ${S.t('misc_currency')}',
                  style: GoogleFonts.raleway(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Text('Taux: $rate% | $salesCount vente(s)',
                  style: GoogleFonts.raleway(color: AppColors.textSecondary, fontSize: 10)),
            ],
          )),
        ],
      ),
    );
  }

  Widget _buildMySalesCard() {
    final sales = _mySales;
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(S.t('dash_my_sales'),
                  style: GoogleFonts.playfairDisplay(
                      color: Colors.white, fontSize: 14,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          sales.isEmpty
              ? SizedBox(
                  height: 80,
                  child: Center(child: Text(S.t('dash_no_sales'),
                      style: GoogleFonts.raleway(color: AppColors.textSecondary))))
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sales.length,
                  separatorBuilder: (_, __) => Divider(
                      color: AppColors.border, height: 1, thickness: 0.5),
                  itemBuilder: (context, index) {
                    final s = sales[index];
                    final createdAt = s['created_at'] as String?;
                    final timeAgo = createdAt != null
                        ? timeago.format(DateTime.parse(createdAt), locale: 'fr_short')
                        : '';
                    final customer = s['customer'];
                    final customerName = customer is Map
                        ? (customer['full_name'] ?? S.t('misc_walk_in'))
                        : S.t('misc_walk_in');
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.receipt_rounded,
                                color: AppColors.success, size: 16),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${((s['total_amount'] as num?)?.toInt() ?? 0)} ${S.t('misc_currency')}',
                                    style: GoogleFonts.raleway(
                                        color: Colors.white, fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                Text(customerName,
                                    style: GoogleFonts.raleway(
                                        color: AppColors.textSecondary, fontSize: 10)),
                              ],
                            ),
                          ),
                          if (timeAgo.isNotEmpty)
                            Text(timeAgo,
                                style: GoogleFonts.raleway(
                                    color: AppColors.textSecondary, fontSize: 10)),
                        ],
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildLowStockCard() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchLowStock(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
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
                  const Icon(Icons.warning_rounded, color: AppColors.danger, size: 16),
                  const SizedBox(width: 8),
                  Text(S.t('dash_low_stock'),
                      style: GoogleFonts.playfairDisplay(
                          color: Colors.white, fontSize: 14,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.waiting)
                const SizedBox(
                  height: 40,
                  child: Center(child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))),
                )
              else if (items.isEmpty)
                SizedBox(
                  height: 40,
                  child: Center(child: Text(S.t('dash_no_data'),
                      style: GoogleFonts.raleway(color: AppColors.textSecondary)))
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => Divider(
                      color: AppColors.border, height: 1, thickness: 0.5),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item['product_name'] ?? ''} (${item['size'] ?? ''} - ${item['color'] ?? ''})',
                              style: GoogleFonts.raleway(
                                  color: Colors.white, fontSize: 12),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('${item['quantity'] ?? 0}',
                                style: GoogleFonts.raleway(
                                    color: AppColors.danger, fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchLowStock() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return [];

      final profileRes = await Supabase.instance.client
          .from('user_profiles')
          .select('store_id')
          .eq('id', user.id)
          .single();
      final storeId = profileRes['store_id'] as String?;

      var query = Supabase.instance.client
          .from('inventory')
          .select('quantity, variant:variant_id(size, color, product:product_id(name))')
          .gt('quantity', 0)
          .lt('quantity', 5);
      if (storeId != null) {
        query = query.eq('store_id', storeId);
      }
      final res = await query;
      return res.map<Map<String, dynamic>>((r) {
        final variant = r['variant'] as Map? ?? {};
        final product = variant['product'] as Map? ?? {};
        return {
          'product_name': product['name'] ?? '',
          'size': variant['size'] ?? '',
          'color': variant['color'] ?? '',
          'quantity': r['quantity'] ?? 0,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching low stock: $e');
      return [];
    }
  }

  Widget _buildShimmer() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          SizedBox(
            height: 100,
            child: Row(
              children: List.generate(4, (i) => [
                Expanded(child: _EmpShimmerBox()),
                if (i < 3) const SizedBox(width: 12),
              ]).expand((e) => e).toList(),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(child: _EmpShimmerBox()),
        ],
      ),
    );
  }
}

class _EmpShimmerBox extends StatefulWidget {
  @override
  State<_EmpShimmerBox> createState() => _EmpShimmerBoxState();
}

class _EmpShimmerBoxState extends State<_EmpShimmerBox>
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
          border: Border.all(color: AppColors.border, width: 0.8),
        ),
      ),
    );
  }
}
