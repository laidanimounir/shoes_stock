import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/app_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../core/app_session.dart';
import '../../services/report_service.dart';

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
  List<Map<String, dynamic>> _employees = [];

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
      } catch (e, s) { debugPrint('[EmployeeDashboard] commission error: $e\n$s'); }

      List<Map<String, dynamic>> employees = [];
      try {
        final empRes = await supabase
            .from('user_profiles')
            .select('id, full_name, first_name, last_name')
            .eq('role', 'employee')
            .eq('is_active', true)
            .eq('is_permanently_deleted', false)
            ;
        employees = List<Map<String, dynamic>>.from(empRes);
      } catch (e, s) { debugPrint('[EmployeeDashboard] employees fetch error: $e\n$s'); }

      if (mounted) {
        setState(() {
          _stats = statsRes as Map<String, dynamic>;
          _mySales = (mySalesRes as List<dynamic>).cast<Map<String, dynamic>>();
          _commissionSummary = commission;
          _employees = employees;
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

  Future<void> _showCashierReportDialog(String userId, String userName) async {
    final supabase = Supabase.instance.client;
    Map<String, dynamic>? report;
    try {
      report = await supabase.rpc('get_cashier_session_report', params: {
        'p_user_id': userId,
        'p_store_id': AppSession.currentStoreId,
        'p_date': DateTime.now().toIso8601String().split('T')[0],
      }) as Map<String, dynamic>;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur chargement rapport: $e'),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }

    if (!mounted) return;

    final totalSales = (report['total_sales'] as num?)?.toInt() ?? 0;
    final totalRevenue = (report['total_revenue'] as num?)?.toDouble() ?? 0;
    final avgDiscount = (report['avg_discount'] as num?)?.toDouble() ?? 0;
    final totalRefunds = (report['total_refunds'] as num?)?.toInt() ?? 0;
    final refundAmount = (report['refund_amount'] as num?)?.toDouble() ?? 0;
    final totalInvoices = (report['total_invoices'] as num?)?.toInt() ?? 0;
    final cashCollected = (report['cash_collected'] as num?)?.toDouble() ?? 0;
    final creditGiven = (report['credit_given'] as num?)?.toDouble() ?? 0;
    final topProduct = report['top_product_name'] as String? ?? '';
    final topProductQty = (report['top_product_qty'] as num?)?.toInt() ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_long_rounded, color: AppColors.desktopPrimary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Rapport du Jour — $userName',
                  style: AppTextStyles.headingLarge(
                      color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: AppColors.desktopSurface,
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _reportRow('Ventes', '$totalSales'),
                _reportRow('Revenu total', '${totalRevenue.toStringAsFixed(0)} ${S.t('misc_currency')}'),
                _reportRow('Remise moyenne', '${avgDiscount.toStringAsFixed(1)}%'),
                const Divider(color: AppColors.desktopBorder, height: 16),
                _reportRow('Factures', '$totalInvoices'),
                _reportRow('Remboursements', '$totalRefunds (${refundAmount.toStringAsFixed(0)} ${S.t('misc_currency')})'),
                const Divider(color: AppColors.desktopBorder, height: 16),
                _reportRow('Espèces encaissées', '${cashCollected.toStringAsFixed(0)} ${S.t('misc_currency')}'),
                _reportRow('Crédit accordé', '${creditGiven.toStringAsFixed(0)} ${S.t('misc_currency')}'),
                if (topProduct.isNotEmpty) ...[
                  const Divider(color: AppColors.desktopBorder, height: 16),
                  _reportRow('Top produit', '$topProduct ($topProductQty)'),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ReportService.instance.generateCashierSessionPdf(report!, userName: userName);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.print_rounded, size: 16, color: AppColors.desktopPrimary),
                const SizedBox(width: 4),
                Text('Imprimer', style: AppTextStyles.bodyMedium(color: AppColors.desktopPrimary)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.t('action_close'), style: AppTextStyles.bodyMedium(color: AppColors.desktopTextSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _reportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTextStyles.bodyMedium(
                  color: AppColors.desktopTextSecondary)),
          Text(value,
              style: AppTextStyles.bodyMedium(
                  color: Colors.white)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysKeys = ['day_sun', 'day_mon', 'day_tue', 'day_wed', 'day_thu', 'day_fri', 'day_sat'];
    final dayKey = daysKeys[now.weekday % 7];
    final monthKey = 'month_${now.month}';
    final dateStr = '${S.t(dayKey)} ${now.day} ${S.t(monthKey)} ${now.year}';

    return Scaffold(
      backgroundColor: AppColors.desktopBackground,
      body: Column(
        children: [
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.desktopSurface,
              border: Border(
                bottom: BorderSide(color: AppColors.desktopBorder, width: 0.8),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.desktopPrimary.withValues(alpha: 0.12),
                    border: Border.all(color: AppColors.desktopPrimary, width: 1.2),
                  ),
                  child: const Icon(Icons.dashboard_rounded, color: AppColors.desktopPrimary, size: 18),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(S.t('dash_employee_dashboard'),
                        style: AppTextStyles.headingLarge(
                            color: Colors.white)),
                    Text(dateStr,
                        style: AppTextStyles.bodyMedium(
                            color: AppColors.desktopPrimary)),
                  ],
                ),
                const Spacer(),
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.desktopPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.desktopPrimary.withValues(alpha: 0.35), width: 0.8),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.refresh_rounded, color: AppColors.desktopPrimary, size: 18),
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
          const SizedBox(height: 20),
          _buildEmployeesSection(),
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
            color: AppColors.desktopPrimary,
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
          color: AppColors.desktopSurface,
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
                      style: AppTextStyles.bodyMedium(
                          color: Colors.white),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(title,
                      style: AppTextStyles.bodyMedium(
                          color: AppColors.desktopTextSecondary),
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
        color: AppColors.desktopSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.desktopPrimary.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: AppColors.desktopPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.monetization_on_rounded, color: AppColors.desktopPrimary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('COMMISSION DU MOIS', style: AppTextStyles.bodyMedium(color: AppColors.desktopTextSecondary)),
              const SizedBox(height: 4),
              Text('${totalComm.toStringAsFixed(0)} ${S.t('misc_currency')}',
                  style: AppTextStyles.bodyMedium(color: Colors.white)),
              Text('Taux: $rate% | $salesCount vente(s)',
                  style: AppTextStyles.bodyMedium(color: AppColors.desktopTextSecondary)),
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
        color: AppColors.desktopSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.desktopBorder, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(S.t('dash_my_sales'),
                  style: AppTextStyles.headingLarge(
                      color: Colors.white)),
            ],
          ),
          const SizedBox(height: 12),
          sales.isEmpty
              ? SizedBox(
                  height: 80,
                  child: Center(child: Text(S.t('dash_no_sales'),
                      style: AppTextStyles.bodyMedium(color: AppColors.desktopTextSecondary))))
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sales.length,
                  separatorBuilder: (_, __) => Divider(
                      color: AppColors.desktopBorder, height: 1, thickness: 0.5),
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
                                    style: AppTextStyles.bodyMedium(
                                        color: Colors.white)),
                                Text(customerName,
                                    style: AppTextStyles.bodyMedium(
                                        color: AppColors.desktopTextSecondary)),
                              ],
                            ),
                          ),
                          if (timeAgo.isNotEmpty)
                            Text(timeAgo,
                                style: AppTextStyles.bodyMedium(
                                    color: AppColors.desktopTextSecondary)),
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
            color: AppColors.desktopSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.desktopBorder, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_rounded, color: AppColors.danger, size: 16),
                  const SizedBox(width: 8),
                  Text(S.t('dash_low_stock'),
                      style: AppTextStyles.headingLarge(
                          color: Colors.white)),
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
                      style: AppTextStyles.bodyMedium(color: AppColors.desktopTextSecondary)))
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => Divider(
                      color: AppColors.desktopBorder, height: 1, thickness: 0.5),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item['product_name'] ?? ''} (${item['size'] ?? ''} - ${item['color'] ?? ''})',
                              style: AppTextStyles.bodyMedium(
                                  color: Colors.white),
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
                                style: AppTextStyles.bodyMedium(
                                    color: AppColors.danger)),
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

  Widget _buildEmployeesSection() {
    final employees = _employees;
    if (employees.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.desktopSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.desktopBorder, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_rounded, color: AppColors.desktopPrimary, size: 18),
              const SizedBox(width: 8),
              Text('Employés',
                  style: AppTextStyles.headingLarge(
                      color: Colors.white)),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: employees.length,
            separatorBuilder: (_, __) => Divider(
                color: AppColors.desktopBorder, height: 1, thickness: 0.5),
            itemBuilder: (context, index) {
              final e = employees[index];
              final name = e['full_name'] as String? ?? '${e['first_name'] ?? ''} ${e['last_name'] ?? ''}'.trim();
              final userId = e['id'] as String;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.desktopPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: AppTextStyles.bodyMedium(
                              color: AppColors.desktopPrimary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(name,
                          style: AppTextStyles.bodyMedium(
                              color: Colors.white),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Container(
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.desktopPrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.desktopPrimary.withValues(alpha: 0.35), width: 0.8),
                      ),
                      child: TextButton(
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10)),
                        onPressed: () => _showCashierReportDialog(userId, name),
                        child: Text('Rapport du Jour',
                            style: AppTextStyles.bodyMedium(
                                color: AppColors.desktopPrimary)),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
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
          color: Color.lerp(AppColors.desktopSurface, AppColors.desktopBackground, _anim.value),
          border: Border.all(color: AppColors.desktopBorder, width: 0.8),
        ),
      ),
    );
  }
}
