import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../desktop/refund_modal.dart';
import '../../core/app_strings.dart';
import '../../core/app_session.dart';

class _T {
  _T._();
  static const bgPage = Color(0xFF0A0A14);
  static const bgAppBar = Color(0xFF0F0F1C);
  static const bgCard = Color(0xFF13131F);
  static const bgTable = Color(0xFF0D0D1A);
  static const bgTableHeader = Color(0xFF1A1400);
  static const bgTableRowAlt = Color(0xFF111120);
  static const bgTableHover = Color(0xFF1E1E35);
  static const accentGold = Color(0xFFFFC107);
  static const accentBlue = Color(0xFF58A6FF);
  static const textPrimary = Color(0xFFEEEEFF);
  static const textSecondary = Color(0xFF8888AA);
  static const textMuted = Color(0xFF555570);
  static const borderColor = Color(0xFF1E1E35);
  static const statusPaidBg = Color(0xFF0D2B1A);
  static const statusPaidText = Color(0xFF4ADE80);
  static const statusRefundedBg = Color(0xFF2B1A0D);
  static const statusRefundedText = Color(0xFFFBBF24);
  static const statusUnpaidBg = Color(0xFF2B0D0D);
  static const statusUnpaidText = Color(0xFFF87171);
  static const statusPartialBg = Color(0xFF1A1A0D);
  static const statusPartialText = Color(0xFFFDE68A);
  static const shimmerColor = Color(0xFF252538);
}

// ═══════════════════════════════════════════════════════════
class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _sales = [];
  List<dynamic> _stores = [];
  bool _isLoading = true;

  String? _userStoreId;
  String? _filterStoreId;
  String _searchQuery = '';
  Timer? _debounce;

  static const _pageSize = 10;
  int _currentPage = 1;
  int _totalCount = 0;

  double _pageRevenue = 0;
  int _pageSales = 0;
  int _pageRefunded = 0;

  final _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initAndFetch();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchFocusNode.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Init ──────────────────────────────────────────────────
  Future<void> _initAndFetch() async {
    _userStoreId = AppSession.currentStoreId;
    if (AppSession.isOwner) {
      _stores = await _supabase.from('stores').select('id, name').order('name');
    } else {
      _filterStoreId = _userStoreId;
    }
    await _fetchSales();
  }

  // ── Fetch ─────────────────────────────────────────────────
  Future<void> _fetchSales() async {
    setState(() => _isLoading = true);
    try {
      final offset = (_currentPage - 1) * _pageSize;

      var countQ = _supabase
          .from('transactions')
          .count(CountOption.exact)
          .eq('type', 'out');
      if (_filterStoreId != null) countQ = countQ.eq('store_id', _filterStoreId!);
      if (_searchQuery.isNotEmpty) {
        countQ = countQ.ilike('invoice_number', '%$_searchQuery%');
      }
      _totalCount = await countQ;
      debugPrint('TOTAL COUNT: $_totalCount, TOTAL PAGES: $_totalPages');

      var dataQ = _supabase.from('transactions').select('''
        id, invoice_number, invoice_id, quantity, total_price, created_at, type,
        product_variants(id, products(name), size, color),
        customers(full_name),
        stores(name),
        invoices(status)
      ''').eq('type', 'out');

      if (_filterStoreId != null) dataQ = dataQ.eq('store_id', _filterStoreId!);
      if (_searchQuery.isNotEmpty) {
        dataQ = dataQ.ilike('invoice_number', '%$_searchQuery%');
      }

      final res = await dataQ
          .order('created_at', ascending: false)
          .range(offset, offset + _pageSize - 1);

      final items = res as List<dynamic>;

      double rev = 0;
      int refCount = 0;
      for (final item in items) {
        final st = item['invoices']?['status'] as String?;
        final pr = (item['total_price'] as num?)?.toDouble() ?? 0;
        if (st != 'refunded') rev += pr;
        if (st == 'refunded') refCount++;
      }

      setState(() {
        _sales = items;
        _pageRevenue = rev;
        _pageSales = items.length;
        _pageRefunded = refCount;
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_searchFocusNode.canRequestFocus) {
          _searchFocusNode.requestFocus();
        }
      });
    } catch (e) {
      debugPrint('Fetch error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _totalPages => (_totalCount / _pageSize).ceil().clamp(1, 99999);

  void _goToPage(int p) {
    if (p < 1 || p > _totalPages) return;
    setState(() => _currentPage = p);
    _fetchSales();
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() {
        _searchQuery = q.trim();
        _currentPage = 1;
      });
      _fetchSales();
    });
  }

  // ═════════════════════════════════════════════════════════
  //  BUILD
  // ═════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bgPage,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (!_isLoading && _sales.isNotEmpty) _buildKpiBar(),
          _buildSearchBar(),
          const SizedBox(height: 12),
          Expanded(child: _buildBody()),
          if (!_isLoading && _totalCount > 0) _buildPaginationBar(),
        ],
      ),
    );
  }

  // ── AppBar ───────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _T.bgAppBar,
      elevation: 0,
      titleSpacing: 20,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Historique Ventes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _T.textPrimary,
            ),
          ),
          Text(
            '$_totalCount ventes au total',
            style: const TextStyle(fontSize: 11, color: _T.textSecondary),
          ),
        ],
      ),
      actions: [
        if (AppSession.isOwner) _storeDropdown(),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _storeDropdown() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _T.bgTableHeader,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _T.borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          dropdownColor: _T.bgTableHeader,
          style: const TextStyle(color: _T.textPrimary, fontSize: 13),
          value: _filterStoreId,
          icon: const Icon(Icons.unfold_more_rounded,
              color: _T.textMuted, size: 16),
          hint: const Text(
            'Tous les magasins',
            style: TextStyle(color: _T.textMuted, fontSize: 13),
          ),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('Tous les magasins'),
            ),
            ..._stores.map((s) => DropdownMenuItem(
                  value: s['id'] as String,
                  child: Text(s['name'] as String),
                )),
          ],
          onChanged: (val) {
            setState(() {
              _filterStoreId = val;
              _currentPage = 1;
            });
            _fetchSales();
          },
        ),
      ),
    );
  }

  // ── KPI Bar ──────────────────────────────────────────────
  Widget _buildKpiBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: _T.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border(bottom: BorderSide(color: _T.borderColor)),
      ),
      child: Row(
        children: [
          _kpiItem('Total ventes', '$_totalCount', Icons.receipt_long_outlined,
              _T.accentGold),
          _kpiDivider(),
          _kpiItem('CA Total',
              '${_pageRevenue.toStringAsFixed(0)} ${S.t('misc_currency')}',
              Icons.trending_up_rounded, _T.accentBlue),
          _kpiDivider(),
          _kpiItem('Remboursés', '$_pageRefunded',
              Icons.assignment_return_rounded, _T.statusRefundedText),
          _kpiDivider(),
          _kpiItem('Page actuelle', '$_pageSales / $_pageSize',
              Icons.layers_rounded, _T.textPrimary),
        ],
      ),
    );
  }

  Widget _kpiItem(
      String label, String value, IconData icon, Color accentColor) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.only(left: 10),
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: Color(0xFFFFC107), width: 3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: accentColor.withValues(alpha: 0.6)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 10, color: _T.textMuted),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(value,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                          letterSpacing: -0.3),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiDivider() {
    return Container(
      width: 1,
      height: 36,
      color: _T.borderColor,
    );
  }

  // ── Search Bar ───────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: _T.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _T.borderColor),
        ),
        child: TextField(
          focusNode: _searchFocusNode,
          controller: _searchCtrl,
          onChanged: (v) => _onSearch(v),
          style: const TextStyle(
            color: Color(0xFFE8E8F0),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          cursorColor: const Color(0xFFF0A500),
          decoration: InputDecoration(
            border: InputBorder.none,
            filled: true,
            fillColor: const Color(0xFF1E1E2E),
            hintText: 'Rechercher par N° facture, client ou produit...',
            hintStyle: const TextStyle(
              color: Color(0xFF606078),
              fontSize: 13,
            ),
            prefixIcon:
                const Icon(Icons.search_rounded, color: _T.textMuted, size: 18),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: _T.textMuted, size: 16),
                    onPressed: () {
                      _searchCtrl.clear();
                      _onSearch('');
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  // ── Body ─────────────────────────────────────────────────
  Widget _buildBody() {
    if (_isLoading) return _buildSkeletonTable();
    if (_sales.isEmpty) return _buildEmptyState();

    final offset = (_currentPage - 1) * _pageSize;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 900,
        child: Column(
          children: [
            _buildTableHeader(),
            Expanded(
              child: ListView.builder(
                itemCount: _sales.length,
                itemBuilder: (_, i) =>
                    _buildTableRow(_sales[i] as Map<String, dynamic>,
                        offset + i + 1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Table Header ─────────────────────────────────────────
  Widget _buildTableHeader() {
    const hdr = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: Color(0xFFFFC107),
      letterSpacing: 1.2,
    );

    return Container(
      height: 40,
      decoration: const BoxDecoration(
        color: _T.bgTableHeader,
        border: Border(bottom: BorderSide(color: _T.borderColor)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          SizedBox(width: 36, child: Text('#', style: hdr)),
          SizedBox(width: 120, child: Text('N° FACTURE', style: hdr)),
          SizedBox(width: 130, child: Text('DATE', style: hdr)),
          Expanded(child: Text('PRODUIT', style: hdr)),
          SizedBox(width: 110, child: Text('CLIENT', style: hdr)),
          SizedBox(width: 110, child: Text('MAGASIN', style: hdr)),
          SizedBox(
              width: 44,
              child: Center(child: Text('QTÉ', style: hdr))),
          SizedBox(
              width: 100,
              child: Text('MONTANT', style: hdr, textAlign: TextAlign.right)),
          SizedBox(
              width: 90,
              child: Center(child: Text('STATUT', style: hdr))),
          const SizedBox(width: 50),
        ],
      ),
    );
  }

  // ── Table Row ────────────────────────────────────────────
  Widget _buildTableRow(Map<String, dynamic> s, int displayIndex) {
    final status = s['invoices']?['status'] as String?;
    final price = (s['total_price'] as num?)?.toDouble() ?? 0;
    final invoiceNum = (s['invoice_number'] as String?)?.isNotEmpty == true
        ? s['invoice_number'] as String
        : null;
    final client =
        s['customers']?['full_name'] as String? ?? S.t('label_guest');
    final store = s['stores']?['name'] as String? ?? '—';
    final product =
        s['product_variants']?['products']?['name'] as String? ?? '—';
    final size = s['product_variants']?['size'] as String? ?? '';
    final color = s['product_variants']?['color'] as String?;
    final qty = (s['quantity'] as num?)?.toInt() ?? 1;

    DateTime? dt;
    if (s['created_at'] != null) {
      dt = DateTime.tryParse(s['created_at'] as String)?.toLocal();
    }
    final dateStr = dt != null
        ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  '
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
        : '—';

    final productDesc = StringBuffer(product);
    if (size.isNotEmpty) productDesc.write('  ($size)');
    if (color != null) productDesc.write(' · $color');

    final canRefund =
        status == 'paid' || status == 'partial' || status == 'unpaid';
    final isEven = displayIndex % 2 == 0;

    return GestureDetector(
      onTap: () => _showDetailDialog(s),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: isEven ? _T.bgTable : _T.bgTableRowAlt,
          border: const Border(bottom: BorderSide(color: _T.borderColor)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            SizedBox(
                width: 36,
                child: Text('$displayIndex',
                    style: const TextStyle(
                        fontSize: 12, color: _T.textMuted))),
            SizedBox(
                width: 120,
                child: Text(invoiceNum ?? '—',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: invoiceNum != null
                            ? _T.accentBlue
                            : _T.textMuted),
                    overflow: TextOverflow.ellipsis)),
            SizedBox(
                width: 130,
                child: Text(dateStr,
                    style: const TextStyle(
                        fontSize: 12, color: _T.textSecondary),
                    overflow: TextOverflow.ellipsis)),
            Expanded(
                child: Text(productDesc.toString(),
                    style: const TextStyle(
                        fontSize: 13,
                        color: _T.textPrimary,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis)),
            SizedBox(
                width: 110,
                child: Text(client,
                    style: const TextStyle(
                        fontSize: 12, color: _T.textSecondary),
                    overflow: TextOverflow.ellipsis)),
            SizedBox(
                width: 110,
                child: Text(store,
                    style: const TextStyle(
                        fontSize: 12, color: _T.textSecondary),
                    overflow: TextOverflow.ellipsis)),
            SizedBox(
                width: 44,
                child: Center(
                    child: Text('$qty',
                        style: const TextStyle(
                            fontSize: 13, color: _T.textPrimary)))),
            SizedBox(
                width: 100,
                child: Text(
                  '${price.toStringAsFixed(2)} ${S.t('misc_currency')}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _T.accentGold),
                  overflow: TextOverflow.ellipsis,
                )),
            SizedBox(width: 90, child: Center(child: _buildStatusBadge(status))),
            SizedBox(
                width: 50,
                child: Center(
                  child: canRefund
                      ? GestureDetector(
                          onTap: () => _handleRefund(s),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE53935),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.assignment_return_rounded,
                              size: 17,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                )),
          ],
        ),
      ),
    );
  }

  // ── Status Badge ─────────────────────────────────────────
  Widget _buildStatusBadge(String? status) {
    Color bg, fg;
    String label;

    switch (status) {
      case 'paid':
        bg = _T.statusPaidBg;
        fg = _T.statusPaidText;
        label = 'Payé';
        break;
      case 'refunded':
        bg = _T.statusRefundedBg;
        fg = _T.statusRefundedText;
        label = 'Remboursé';
        break;
      case 'partial':
        bg = _T.statusPartialBg;
        fg = _T.statusPartialText;
        label = 'Partiel';
        break;
      case 'unpaid':
        bg = _T.statusUnpaidBg;
        fg = _T.statusUnpaidText;
        label = 'Impayé';
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: fg),
          ),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: fg)),
        ],
      ),
    );
  }

  // ── Pagination Bar ───────────────────────────────────────
  Widget _buildPaginationBar() {
    final total = _totalPages;
    final current = _currentPage;

    final Set<int> show = {1, total, current};
    if (current > 1) show.add(current - 1);
    if (current < total) show.add(current + 1);
    final sorted = show.toList()..sort();

    List<Widget> buttons = [];
    int? prev;
    for (final p in sorted) {
      if (prev != null && p - prev > 1) {
        buttons.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('…',
              style: TextStyle(
                  color: _T.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ));
      }
      buttons.add(_pageBtn(p, p == current));
      prev = p;
    }

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: _T.bgCard,
        border: Border(top: BorderSide(color: _T.borderColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: _T.textSecondary),
              children: [
                const TextSpan(text: 'Page '),
                TextSpan(
                  text: '$current',
                  style: const TextStyle(
                      color: _T.textPrimary, fontWeight: FontWeight.w700),
                ),
                TextSpan(text: ' sur $total  ·  $_totalCount résultats'),
              ],
            ),
          ),
          Row(
            children: [
              _navBtn(Icons.chevron_left_rounded,
                  current > 1 ? () => _goToPage(current - 1) : null),
              const SizedBox(width: 4),
              ...buttons,
              const SizedBox(width: 4),
              _navBtn(Icons.chevron_right_rounded,
                  current < total ? () => _goToPage(current + 1) : null),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pageBtn(int p, bool active) {
    return GestureDetector(
      onTap: () => _goToPage(p),
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: active ? _T.accentGold : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: active ? _T.accentGold : _T.borderColor, width: 1),
        ),
        child: Center(
          child: Text(
            '$p',
            style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? _T.bgPage : _T.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _T.borderColor),
        ),
        child: Opacity(
          opacity: enabled ? 1.0 : 0.3,
          child: Icon(icon, size: 18, color: _T.textPrimary),
        ),
      ),
    );
  }

  // ── Detail Dialog ────────────────────────────────────────
  void _showDetailDialog(Map<String, dynamic> s) {
    final status = s['invoices']?['status'] as String?;
    final price = (s['total_price'] as num?)?.toDouble() ?? 0;
    final invoiceNum = (s['invoice_number'] as String?)?.isNotEmpty == true
        ? s['invoice_number'] as String
        : null;
    final client =
        s['customers']?['full_name'] as String? ?? S.t('label_guest');
    final store = s['stores']?['name'] as String? ?? '—';
    final product =
        s['product_variants']?['products']?['name'] as String? ?? '—';
    final size = s['product_variants']?['size'] as String? ?? '';
    final color = s['product_variants']?['color'] as String?;
    final qty = (s['quantity'] as num?)?.toInt() ?? 1;

    DateTime? dt;
    if (s['created_at'] != null) {
      dt = DateTime.tryParse(s['created_at'] as String)?.toLocal();
    }
    final dateStr = dt != null
        ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  '
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
        : '—';

    final canRefund =
        status == 'paid' || status == 'partial' || status == 'unpaid';

    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth - 32 > 600 ? 600.0 : screenWidth - 32;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _T.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: dialogWidth, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        invoiceNum ?? 'Sans facture',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _T.accentBlue,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    _buildStatusBadge(status),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: _T.textMuted, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Text(
                  '$dateStr  ·  $store',
                  style: const TextStyle(fontSize: 12, color: _T.textSecondary),
                ),
              ),

              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section Produit
                      _dialogSectionLabel('PRODUIT'),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _T.bgTable,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _T.borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(product,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: _T.textPrimary)),
                            if (size.isNotEmpty || color != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                [if (size.isNotEmpty) 'Taille $size',
                                 if (color != null) 'Couleur $color']
                                    .join(' · '),
                                style: const TextStyle(
                                    fontSize: 13, color: _T.textSecondary),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _dialogInfoChip(
                                    'Qté', qty.toString()),
                                const SizedBox(width: 16),
                                _dialogInfoChip(
                                    'Prix unit.',
                                    '${price.toStringAsFixed(2)} ${S.t('misc_currency')}'),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Section Client
                      _dialogSectionLabel('CLIENT'),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _T.bgTable,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _T.borderColor),
                        ),
                        child: Text(
                          client,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _T.textPrimary),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Financial Summary
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _T.bgTableHeader,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Montant total',
                                style: TextStyle(
                                    fontSize: 13, color: _T.textSecondary)),
                            Text(
                              '${price.toStringAsFixed(2)} ${S.t('misc_currency')}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: _T.accentGold,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (canRefund)
                            Container(
                              margin: const EdgeInsets.only(right: 10),
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _handleRefund(s);
                                },
                                icon: const Icon(
                                    Icons.assignment_return_rounded,
                                    size: 16),
                                label: Text(S.t('label_return')),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _T.statusUnpaidBg,
                                  foregroundColor: _T.statusUnpaidText,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: const BorderSide(
                                        color: _T.borderColor),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 11),
                                ),
                              ),
                            ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(S.t('action_close'),
                                style: const TextStyle(
                                    color: _T.textSecondary)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogSectionLabel(String text) {
    return Text(text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _T.textMuted,
          letterSpacing: 1.2,
        ));
  }

  Widget _dialogInfoChip(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ',
            style: const TextStyle(fontSize: 12, color: _T.textMuted)),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _T.textPrimary)),
      ],
    );
  }

  // ── Skeleton Table ───────────────────────────────────────
  Widget _buildSkeletonTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 900,
        child: Column(
          children: [
            _buildTableHeader(),
            Expanded(
              child: ListView.builder(
                itemCount: 8,
                itemBuilder: (_, i) => Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: i.isEven ? _T.bgTable : _T.bgTableRowAlt,
                    border:
                        const Border(bottom: BorderSide(color: _T.borderColor)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      _skBox(24, 12),
                      const SizedBox(width: 52),
                      _skBox(70, 12),
                      const SizedBox(width: 70),
                      _skBox(100, 12),
                      Expanded(child: _skBox(double.infinity, 12)),
                      const SizedBox(width: 16),
                      _skBox(70, 12),
                      const SizedBox(width: 50),
                      _skBox(70, 12),
                      const SizedBox(width: 50),
                      _skBox(24, 12),
                      const SizedBox(width: 30),
                      _skBox(60, 12),
                      const SizedBox(width: 30),
                      _skBox(60, 12),
                      const SizedBox(width: 60),
                      _skBox(30, 12),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _skBox(double w, double h) {
    return Container(
      width: w == double.infinity ? null : w,
      height: h,
      decoration: BoxDecoration(
        color: _T.shimmerColor,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  // ── Empty State ──────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.receipt_long_outlined,
              size: 48, color: _T.textMuted),
          const SizedBox(height: 14),
          const Text('Aucune vente trouvée',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _T.textSecondary)),
          const SizedBox(height: 6),
          const Text(
            'Modifiez vos filtres ou votre recherche',
            style: TextStyle(fontSize: 13, color: _T.textMuted),
          ),
        ],
      ),
    );
  }

  // ── Refund Handler ───────────────────────────────────────
  Future<void> _handleRefund(Map<String, dynamic> s) async {
    final createdAtStr = s['created_at'] as String?;
    if (createdAtStr == null) return;
    final createdAt = DateTime.parse(createdAtStr);
    final hoursSince = DateTime.now().difference(createdAt).inHours;

    if (hoursSince > 48) {
      if (AppSession.isOwner) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: _T.bgCard,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: Text(S.t('refund_48h_warning_title'),
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: _T.textPrimary)),
            content: Text(S.t('refund_48h_warning_body'),
                style: const TextStyle(
                    color: _T.textSecondary, fontSize: 14)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(S.t('action_cancel'),
                    style: const TextStyle(color: _T.textSecondary)),
              ),
              Container(
                margin: const EdgeInsets.only(right: 8, bottom: 4),
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _T.accentGold,
                    foregroundColor: _T.bgPage,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: Text(S.t('refund_48h_continue')),
                ),
              ),
            ],
          ),
        );
        if (ok != true) return;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(S.t('refund_48h_blocked')),
              backgroundColor: _T.statusUnpaidText,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(12),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        return;
      }
    }

    final result = await showDialog(
      context: context,
      builder: (_) => RefundModal(invoice: s, isOwner: AppSession.isOwner),
    );
    if (result == true) _fetchSales();
  }
}
