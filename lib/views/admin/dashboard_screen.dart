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
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
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
        profit += (totalPrice - (buyPrice * qty));
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
  static const _darkBg   = Color(0xFF0F0F1A);
  static const _cardBg   = Color(0xFF1A1A2E);
  static const _gold     = Color(0xFFD4A843);
  static const _goldLight= Color(0xFFF0C96B);

  // ══════════════════════════════════════════
  // build
  // ══════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
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

  // ══════════════════════════════════════════
  // HEADER
  // ══════════════════════════════════════════
  Widget _buildHeader() {
    final now = DateTime.now();
    final days   = ['Dim','Lun','Mar','Mer','Jeu','Ven','Sam'];
    final months = ['Jan','Fév','Mar','Avr','Mai','Jun',
                    'Jul','Aoû','Sep','Oct','Nov','Déc'];
    final dateStr =
        '${days[now.weekday % 7]} ${now.day} ${months[now.month - 1]} ${now.year}';

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border(
          bottom: BorderSide(color: _gold.withValues(alpha: 0.25), width: 0.8),
        ),
      ),
      child: Row(
        children: [
          // أيقونة
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _gold.withValues(alpha: 0.12),
              border: Border.all(color: _gold, width: 1.2),
            ),
            child: const Icon(Icons.storefront_rounded, color: _gold, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tableau de Bord',
                  style: GoogleFonts.playfairDisplay(
                      color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.bold)),
              Text(dateStr,
                  style: GoogleFonts.raleway(
                      color: _gold, fontSize: 11, letterSpacing: 0.8)),
            ],
          ),
          const Spacer(),

          // ── فلتر المتاجر (لم يتغير) ──
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _gold.withValues(alpha: 0.25), width: 0.8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedStoreId,
                dropdownColor: _cardBg,
                icon: const Icon(Icons.store_outlined, color: _gold, size: 16),
                style: GoogleFonts.raleway(color: Colors.white, fontSize: 13,
                    fontWeight: FontWeight.w600),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text('Tous les magasins',
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
                  _fetchDashboardStats();
                },
              ),
            ),
          ),
          const SizedBox(width: 8),

          // زر تحديث
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _gold.withValues(alpha: 0.35), width: 0.8),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.refresh_rounded, color: _gold, size: 18),
              onPressed: _fetchDashboardStats,
              tooltip: 'Actualiser',
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  // BODY — بدون scroll، يملأ الشاشة
  // ══════════════════════════════════════════
  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // ── صف 1: 4 بطاقات مالية ──────────
          Expanded(
            flex: 2,
            child: Row(
              children: [
                _buildKpiCard(
                  title: "Chiffre d'affaires",
                  subtitle: "Aujourd'hui",
                  value: '${_todaySales.toStringAsFixed(0)} DA',
                  icon: Icons.point_of_sale_rounded,
                  accentColor: const Color(0xFF1E88E5),
                  topColor: const Color(0xFF1565C0),
                ),
                const SizedBox(width: 14),
                _buildKpiCard(
                  title: 'Bénéfice Net',
                  subtitle: "Aujourd'hui",
                  value: '+${_todayProfit.toStringAsFixed(0)} DA',
                  icon: Icons.trending_up_rounded,
                  accentColor: const Color(0xFF43A047),
                  topColor: const Color(0xFF1B5E20),
                ),
                const SizedBox(width: 14),
                _buildKpiCard(
                  title: 'Créances Clients',
                  subtitle: 'Crédits en cours',
                  value: '${_customerDebt.toStringAsFixed(0)} DA',
                  icon: Icons.account_balance_wallet_rounded,
                  accentColor: const Color(0xFFFB8C00),
                  topColor: const Color(0xFFE65100),
                ),
                const SizedBox(width: 14),
                _buildKpiCard(
                  title: 'Dettes Fournisseurs',
                  subtitle: 'À régler',
                  value: '${_supplierDebt.toStringAsFixed(0)} DA',
                  icon: Icons.money_off_rounded,
                  accentColor: const Color(0xFFE53935),
                  topColor: const Color(0xFFB71C1C),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── فاصل ذهبي ─────────────────────
          Row(
            children: [
              Expanded(child: Container(height: 0.5,
                  color: _gold.withValues(alpha: 0.2))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.auto_awesome,
                    color: _gold.withValues(alpha: 0.5), size: 13),
              ),
              Expanded(child: Container(height: 0.5,
                  color: _gold.withValues(alpha: 0.2))),
            ],
          ),
          const SizedBox(height: 14),

          // ── صف 2: 3 بطاقات + منحنى ────────
          Expanded(
            flex: 3,
            child: Row(
              children: [
                // بطاقة المخزون
                Expanded(
                  flex: 2,
                  child: _buildStatBigCard(
                    title: 'Valeur du Stock',
                    value: '${_stockValue.toStringAsFixed(0)} DA',
                    icon: Icons.inventory_rounded,
                    accentColor: const Color(0xFF00897B),
                    topColor: const Color(0xFF00695C),
                  ),
                ),
                const SizedBox(width: 14),

                // بطاقة العملاء
                Expanded(
                  flex: 2,
                  child: _buildStatBigCard(
                    title: 'Clients Actifs',
                    value: '$_activeCustomers',
                    icon: Icons.people_rounded,
                    accentColor: const Color(0xFF7B1FA2),
                    topColor: const Color(0xFF4A148C),
                    isCount: true,
                  ),
                ),
                const SizedBox(width: 14),

                // بطاقة الموردين
                Expanded(
                  flex: 2,
                  child: _buildStatBigCard(
                    title: 'Fournisseurs Actifs',
                    value: '$_activeSuppliers',
                    icon: Icons.local_shipping_rounded,
                    accentColor: const Color(0xFF6D4C41),
                    topColor: const Color(0xFF3E2723),
                    isCount: true,
                  ),
                ),
                const SizedBox(width: 14),

                // منحنى بياني placeholder
                Expanded(
                  flex: 4,
                  child: _buildChartPlaceholder(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  // بطاقة KPI صغيرة — الصف الأول
  // ══════════════════════════════════════════
  Widget _buildKpiCard({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    required Color accentColor,
    required Color topColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accentColor.withValues(alpha: 0.2), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: topColor.withValues(alpha: 0.15),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: GoogleFonts.raleway(
                              color: Colors.white70, fontSize: 12,
                              fontWeight: FontWeight.w600),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(subtitle,
                          style: GoogleFonts.raleway(
                              color: Colors.white30, fontSize: 10)),
                    ],
                  ),
                ),
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [topColor, accentColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: GoogleFonts.raleway(
                        color: Colors.white, fontSize: 20,
                        fontWeight: FontWeight.bold),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentColor, accentColor.withValues(alpha: 0.1)],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  // بطاقة كبيرة — الصف الثاني
  // ══════════════════════════════════════════
  Widget _buildStatBigCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
    required Color topColor,
    bool isCount = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.2), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: topColor.withValues(alpha: 0.15),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // أيقونة كبيرة
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [topColor, accentColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.raleway(
                      color: Colors.white54, fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(value,
                  style: GoogleFonts.raleway(
                      color: Colors.white,
                      fontSize: isCount ? 40 : 22,
                      fontWeight: FontWeight.bold),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 10),
              Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentColor, accentColor.withValues(alpha: 0.1)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  // منحنى بياني — placeholder جاهز للربط
  // ══════════════════════════════════════════
  Widget _buildChartPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _gold.withValues(alpha: 0.15), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
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
                  Text('Évolution des Ventes',
                      style: GoogleFonts.playfairDisplay(
                          color: Colors.white, fontSize: 14,
                          fontWeight: FontWeight.bold)),
                  Text('7 derniers jours',
                      style: GoogleFonts.raleway(
                          color: Colors.white38, fontSize: 11)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _gold.withValues(alpha: 0.3), width: 0.8),
                ),
                child: Text('7J',
                    style: GoogleFonts.raleway(
                        color: _gold, fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // منحنى مرسوم يدوياً بـ CustomPaint
          Expanded(
            child: _MiniLineChart(
              goldColor: _gold,
              accentColor: const Color(0xFF1E88E5),
            ),
          ),

          const SizedBox(height: 12),
          // محاور X — أيام الأسبوع
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Auj']
                .map((d) => Text(d,
                    style: GoogleFonts.raleway(
                        color: Colors.white30, fontSize: 10)))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  // Shimmer
  // ══════════════════════════════════════════
  Widget _buildShimmer() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: List.generate(4, (i) => [
                Expanded(child: _ShimmerBox()),
                if (i < 3) const SizedBox(width: 14),
              ]).expand((e) => e).toList(),
            ),
          ),
          const SizedBox(height: 14),
          const SizedBox(height: 1),
          const SizedBox(height: 14),
          Expanded(
            flex: 3,
            child: Row(
              children: List.generate(4, (i) => [
                Expanded(flex: i == 3 ? 4 : 2, child: _ShimmerBox()),
                if (i < 3) const SizedBox(width: 14),
              ]).expand((e) => e).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════
// منحنى بياني بـ CustomPaint
// ══════════════════════════════════════════
class _MiniLineChart extends StatelessWidget {
  final Color goldColor;
  final Color accentColor;

  const _MiniLineChart({
    required this.goldColor,
    required this.accentColor,
  });

  // بيانات placeholder — استبدلها ببيانات Supabase لاحقاً
  static const _points = [0.3, 0.5, 0.4, 0.7, 0.6, 0.85, 1.0];

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LinePainter(
        points: _points,
        lineColor: accentColor,
        fillColor: accentColor.withValues(alpha: 0.12),
        dotColor: goldColor,
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double> points;
  final Color lineColor;
  final Color fillColor;
  final Color dotColor;

  _LinePainter({
    required this.points,
    required this.lineColor,
    required this.fillColor,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    final w = size.width;
    final h = size.height;
    final step = w / (points.length - 1);

    // نقاط المنحنى
    final coords = <Offset>[];
    for (int i = 0; i < points.length; i++) {
      coords.add(Offset(i * step, h - (points[i] * h)));
    }

    // رسم المنحنى الناعم
    path.moveTo(coords[0].dx, coords[0].dy);
    fillPath.moveTo(coords[0].dx, h);
    fillPath.lineTo(coords[0].dx, coords[0].dy);

    for (int i = 0; i < coords.length - 1; i++) {
      final cp1 = Offset((coords[i].dx + coords[i + 1].dx) / 2, coords[i].dy);
      final cp2 = Offset((coords[i].dx + coords[i + 1].dx) / 2, coords[i + 1].dy);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy,
          coords[i + 1].dx, coords[i + 1].dy);
      fillPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy,
          coords[i + 1].dx, coords[i + 1].dy);
    }

    fillPath.lineTo(coords.last.dx, h);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    // نقطة آخر قيمة (اليوم) مع دائرة ذهبية
    final last = coords.last;
    canvas.drawCircle(last, 5, dotPaint);
    canvas.drawCircle(last, 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_LinePainter old) => false;
}

// ══════════════════════════════════════════
// Shimmer Box
// ══════════════════════════════════════════
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
          color: Color.lerp(
              const Color(0xFF1A1A2E), const Color(0xFF252545), _anim.value),
          border: Border.all(
              color: const Color(0xFFD4A843).withValues(alpha: 0.08),
              width: 0.8),
        ),
      ),
    );
  }
}