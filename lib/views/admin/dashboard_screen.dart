import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  // ══════════════════════════════════════════
  // المنطق — لم يتغير أي شيء
  // ══════════════════════════════════════════
  bool _isLoading = true;
  List<dynamic> _stores = [];
  String? _selectedStoreId;
  double _todaySales = 0.0;
  double _todayProfit = 0.0;
  double _customerDebt = 0.0;
  double _supplierDebt = 0.0;
  double _stockValue = 0.0;
  int _activeCustomers = 0;
  int _activeSuppliers = 0;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _initDashboard();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _initDashboard() async {
    await _fetchStores();
    await _fetchDashboardStats();
  }

  Future<void> _fetchStores() async {
    try {
      final res = await Supabase.instance.client
          .from('stores')
          .select()
          .eq('is_active', true)
          .order('name');
      if (mounted) {
        setState(() {
          _stores = res;
          _selectedStoreId = null;
        });
      }
    } catch (e) {
      debugPrint('Error fetching stores: $e');
    }
  }

  Future<void> _fetchDashboardStats() async {
    setState(() => _isLoading = true);
    _animController.reset();

    try {
      final today = DateTime.now();
      final startOfDay =
          DateTime(today.year, today.month, today.day).toIso8601String();

      var transQuery = Supabase.instance.client
          .from('transactions')
          .select('quantity, total_price, product_variants(buy_price)')
          .eq('type', 'out')
          .gte('created_at', startOfDay);

      if (_selectedStoreId != null) {
        transQuery = transQuery.eq('store_id', _selectedStoreId!);
      }

      final transRes = await transQuery;

      double sales = 0;
      double profit = 0;

      for (var t in transRes) {
        double totalPrice = (t['total_price'] as num?)?.toDouble() ?? 0.0;
        int qty = (t['quantity'] as num?)?.toInt() ?? 0;
        double buyPrice =
            (t['product_variants']?['buy_price'] as num?)?.toDouble() ?? 0.0;
        sales += totalPrice;
        double cost = buyPrice * qty;
        profit += (totalPrice - cost);
      }

      final custRes = await Supabase.instance.client
          .from('customers')
          .select('balance')
          .eq('is_active', true);
      double cDebt = custRes.fold(
          0.0, (sum, c) => sum + ((c['balance'] as num?)?.toDouble() ?? 0.0));

      final suppRes = await Supabase.instance.client
          .from('suppliers')
          .select('balance')
          .eq('is_active', true);
      double sDebt = suppRes.fold(
          0.0, (sum, s) => sum + ((s['balance'] as num?)?.toDouble() ?? 0.0));

      var invQuery = Supabase.instance.client
          .from('inventory')
          .select('quantity, product_variants(buy_price)')
          .gt('quantity', 0);

      if (_selectedStoreId != null) {
        invQuery = invQuery.eq('store_id', _selectedStoreId!);
      }

      final invRes = await invQuery;
      double stockVal = 0;
      for (var i in invRes) {
        int qty = (i['quantity'] as num?)?.toInt() ?? 0;
        double buyPrice =
            (i['product_variants']?['buy_price'] as num?)?.toDouble() ?? 0.0;
        stockVal += (qty * buyPrice);
      }

      if (mounted) {
        setState(() {
          _todaySales = sales;
          _todayProfit = profit;
          _customerDebt = cDebt;
          _supplierDebt = sDebt;
          _stockValue = stockVal;
          _activeCustomers = custRes.length;
          _activeSuppliers = suppRes.length;
          _isLoading = false;
        });
        _animController.forward();
      }
    } catch (e) {
      debugPrint('Error fetching dashboard stats: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ══════════════════════════════════════════
  // ألوان الثيم
  // ══════════════════════════════════════════
  static const _darkBg = Color(0xFF0F0F1A);
  static const _cardBg = Color(0xFF1A1A2E);
  static const _gold = Color(0xFFD4A843);
  static const _goldLight = Color(0xFFF0C96B);

  // ══════════════════════════════════════════
  // البناء الرئيسي
  // ══════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading ? _buildShimmer() : _buildBody(),
          ),
        ],
      ),
    );
  }

  // ── رأس الصفحة ────────────────────────────
  Widget _buildHeader() {
    final now = DateTime.now();
    final days = ['Dim', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];
    final months = [
      'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun',
      'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'
    ];
    final dateStr =
        '${days[now.weekday % 7]} ${now.day} ${months[now.month - 1]} ${now.year}';

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 20, 20, 20),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border(
          bottom: BorderSide(color: _gold.withValues(alpha: 0.3), width: 1),
        ),
      ),
      child: Row(
        children: [
          // شعار + عنوان
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _gold.withValues(alpha: 0.15),
              border: Border.all(color: _gold, width: 1.5),
            ),
            child: const Icon(Icons.storefront_rounded,
                color: _gold, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tableau de Bord',
                style: GoogleFonts.playfairDisplay(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                dateStr,
                style: GoogleFonts.raleway(
                  color: _gold,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const Spacer(),
          // فلتر المتاجر — لم يتغير
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: _gold.withValues(alpha: 0.3), width: 0.8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedStoreId,
                dropdownColor: _cardBg,
                icon: const Icon(Icons.store_outlined, color: _gold, size: 18),
                style: GoogleFonts.raleway(
                    color: Colors.white, fontWeight: FontWeight.w600),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text('Tous les magasins',
                        style: GoogleFonts.raleway(color: Colors.white70)),
                  ),
                  ..._stores.map((s) => DropdownMenuItem(
                        value: s['id'] as String?,
                        child: Text(s['name'],
                            style:
                                GoogleFonts.raleway(color: Colors.white)),
                      )),
                ],
                onChanged: (val) {
                  setState(() => _selectedStoreId = val);
                  _fetchDashboardStats();
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
          // زر تحديث
          Container(
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: _gold.withValues(alpha: 0.4), width: 0.8),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, color: _gold, size: 20),
              onPressed: _fetchDashboardStats,
              tooltip: 'Actualiser',
            ),
          ),
        ],
      ),
    );
  }

  // ── المحتوى الرئيسي ──────────────────────
  Widget _buildBody() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Indicateurs Financiers', Icons.bar_chart_rounded),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildKpiCard(
                  title: "Chiffre d'affaires",
                  subtitle: "Aujourd'hui",
                  value: _todaySales,
                  icon: Icons.point_of_sale_rounded,
                  gradientColors: [const Color(0xFF1565C0), const Color(0xFF1E88E5)],
                ),
                _buildKpiCard(
                  title: 'Bénéfice Net',
                  subtitle: "Aujourd'hui",
                  value: _todayProfit,
                  icon: Icons.trending_up_rounded,
                  gradientColors: [const Color(0xFF1B5E20), const Color(0xFF43A047)],
                  isProfit: true,
                ),
                _buildKpiCard(
                  title: 'Créances Clients',
                  subtitle: 'Crédits en cours',
                  value: _customerDebt,
                  icon: Icons.account_balance_wallet_rounded,
                  gradientColors: [const Color(0xFFE65100), const Color(0xFFFB8C00)],
                ),
                _buildKpiCard(
                  title: 'Dettes Fournisseurs',
                  subtitle: 'À régler',
                  value: _supplierDebt,
                  icon: Icons.money_off_rounded,
                  gradientColors: [const Color(0xFFB71C1C), const Color(0xFFE53935)],
                ),
              ],
            ),
            const SizedBox(height: 36),
            // فاصل ذهبي
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 0.5,
                    color: _gold.withValues(alpha: 0.3),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.auto_awesome,
                      color: _gold.withValues(alpha: 0.6), size: 16),
                ),
                Expanded(
                  child: Container(
                    height: 0.5,
                    color: _gold.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 36),
            _buildSectionTitle('Statistiques du Magasin', Icons.storefront_rounded),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildKpiCard(
                  title: 'Valeur du Stock',
                  subtitle: 'Global',
                  value: _stockValue,
                  icon: Icons.inventory_rounded,
                  gradientColors: [const Color(0xFF00695C), const Color(0xFF00897B)],
                ),
                _buildStatCard(
                  title: 'Clients Actifs',
                  value: '$_activeCustomers',
                  icon: Icons.people_rounded,
                  gradientColors: [const Color(0xFF4A148C), const Color(0xFF7B1FA2)],
                ),
                _buildStatCard(
                  title: 'Fournisseurs Actifs',
                  value: '$_activeSuppliers',
                  icon: Icons.local_shipping_rounded,
                  gradientColors: [const Color(0xFF3E2723), const Color(0xFF6D4C41)],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── عنوان القسم ──────────────────────────
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _gold, size: 20),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // ── بطاقة KPI مالية ──────────────────────
  Widget _buildKpiCard({
    required String title,
    required String subtitle,
    required double value,
    required IconData icon,
    required List<Color> gradientColors,
    bool isProfit = false,
  }) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: gradientColors[1].withValues(alpha: 0.25), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.raleway(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.raleway(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isProfit ? '+${value.toStringAsFixed(0)}' : value.toStringAsFixed(0),
                style: GoogleFonts.raleway(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  'DA',
                  style: GoogleFonts.raleway(
                    fontSize: 13,
                    color: _goldLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  gradientColors[1].withValues(alpha: 0.8),
                  gradientColors[1].withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  // ── بطاقة إحصاء (بدون DA) ────────────────
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required List<Color> gradientColors,
  }) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: gradientColors[1].withValues(alpha: 0.25), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.raleway(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            value,
            style: GoogleFonts.raleway(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  gradientColors[1].withValues(alpha: 0.8),
                  gradientColors[1].withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shimmer أثناء التحميل ─────────────────
  Widget _buildShimmer() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: List.generate(
          7,
          (_) => _ShimmerCard(),
        ),
      ),
    );
  }
}

// ── بطاقة shimmer منفصلة ─────────────────────
class _ShimmerCard extends StatefulWidget {
  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
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
        width: 260,
        height: 130,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Color.lerp(
            const Color(0xFF1A1A2E),
            const Color(0xFF252540),
            _anim.value,
          ),
          border: Border.all(
              color: const Color(0xFFD4A843).withValues(alpha: 0.1), width: 0.8),
        ),
      ),
    );
  }
}