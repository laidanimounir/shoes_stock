import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_session.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../theme/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/app_strings.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../theme/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../local_db/isar_service.dart';
import '../../local_db/collections/customer_local.dart';
import '../../local_db/collections/invoice_local.dart';
import '../../local_db/collections/payment_local.dart';
import '../../services/debt_recovery_service.dart';
import '../../shared/utils/contact_utils.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});
  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  List<dynamic> _customers = [];
  bool _isLoading = true;
  bool _debtFilter = false;
  Map<String, dynamic>? _selected;
  late TabController _tabCtrl;
  List<dynamic> _invoices = [], _payments = [];
  bool _loadingHistory = false;
  double _balance = 0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _fetch();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch([String q = '']) async {
    setState(() => _isLoading = true);
    if (AppSession.isOfflineMode) {
      try {
        final isar = await IsarService.getInstance();
        var customers = await isar.customerLocals.where().findAll();
        if (q.isNotEmpty) customers = customers.where((c) => c.fullName.toLowerCase().contains(q.toLowerCase()) || (c.phone?.toLowerCase().contains(q.toLowerCase()) ?? false)).toList();
        final mapped = customers.where((c) => c.isActive).map((c) => {'id': c.supabaseId, 'full_name': c.fullName, 'phone': c.phone, 'email': c.email, 'address': c.address, 'balance': c.balance, 'is_active': c.isActive}).toList();
        if (mounted) setState(() { _customers = _debtFilter ? mapped.where((c) => (c['balance'] as num? ?? 0) > 0).toList() : mapped; _isLoading = false; });
      } catch (_) { if (mounted) setState(() => _isLoading = false); }
      return;
    }
    try {
      var qb = Supabase.instance.client.from('customers').select().eq('is_active', true);
      if (q.isNotEmpty) qb = qb.or('full_name.ilike.%$q%,phone.ilike.%$q%');
      final res = await qb.order('full_name');
      if (mounted) setState(() { _customers = _debtFilter ? (res as List).where((c) => (c['balance'] as num? ?? 0) > 0).toList() : res; _isLoading = false; });
    } catch (_) { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _fetchHistory(String id) async {
    setState(() => _loadingHistory = true);
    if (AppSession.isOfflineMode) {
      try {
        final isar = await IsarService.getInstance();
        final invs = await isar.invoiceLocals.where().findAll();
        final invsFiltered = invs.where((i) => i.customerId == id && i.type == 'out').toList();
        final pays = await isar.paymentLocals.where().findAll();
        final paysFiltered = pays.where((p) => p.customerId == id).toList();
        if (mounted) setState(() {
          _invoices = invsFiltered.map((i) => {'id': i.supabaseId, 'invoice_number': i.invoiceNumber, 'total_amount': i.totalAmount, 'paid_amount': i.paidAmount, 'status': i.status, 'created_at': i.createdAt?.toIso8601String()}).toList();
          _payments = paysFiltered.map((p) => {'id': p.supabaseId, 'amount': p.amount, 'payment_method': p.paymentMethod, 'created_at': p.createdAt?.toIso8601String()}).toList();
          _balance = _invoices.fold(0.0, (s, i) => s + ((i['total_amount'] as num?)?.toDouble() ?? 0)) - _payments.fold(0.0, (s, p) => s + ((p['amount'] as num?)?.toDouble() ?? 0));
          _loadingHistory = false;
        });
      } catch (_) { if (mounted) setState(() => _loadingHistory = false); }
      return;
    }
    try {
      var iq = Supabase.instance.client.from('invoices').select().eq('customer_id', id).eq('type', 'out');
      var pq = Supabase.instance.client.from('payments').select().eq('customer_id', id);
      if (AppSession.isEmployee && AppSession.currentStoreId != null) {
        iq = iq.eq('store_id', AppSession.currentStoreId!);
        pq = pq.eq('store_id', AppSession.currentStoreId!);
      }
      final invs = await iq.order('created_at', ascending: false);
      final pays = await pq.order('payment_date', ascending: false);
      if (mounted) setState(() { _invoices = invs; _payments = pays; _loadingHistory = false; });
      final balRes = await Supabase.instance.client.rpc('get_customer_balance', params: {'p_customer_id': id});
      if (mounted) setState(() { _balance = (balRes as num?)?.toDouble() ?? 0; });
    } catch (_) { if (mounted) setState(() => _loadingHistory = false); }
  }

  void _addCustomer() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(S.t('cust_add')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Téléphone', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.t('action_cancel'))),
        ElevatedButton(onPressed: () async {
          if (nameCtrl.text.isEmpty) return;
          Navigator.pop(ctx);
          try {
            await Supabase.instance.client.from('customers').insert({'full_name': nameCtrl.text.trim(), 'phone': phoneCtrl.text.trim(), 'email': emailCtrl.text.trim(), 'balance': 0, 'is_active': true});
            _fetch(_searchCtrl.text);
          } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger)); }
        }, child: Text(S.t('action_save'))),
      ],
    ));
  }

  void _editCustomer() {
    if (!AppSession.isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.t('msg_access_denied')), backgroundColor: AppColors.danger));
      return;
    }
    final c = _selected!;
    final nameCtrl = TextEditingController(text: c['full_name']);
    final phoneCtrl = TextEditingController(text: c['phone']);
    final emailCtrl = TextEditingController(text: c['email']);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(S.t('cust_edit')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Téléphone', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.t('action_cancel'))),
        ElevatedButton(onPressed: () async {
          Navigator.pop(ctx);
          try {
            await Supabase.instance.client.from('customers').update({'full_name': nameCtrl.text.trim(), 'phone': phoneCtrl.text.trim(), 'email': emailCtrl.text.trim()}).eq('id', c['id']);
            if (_selected?['id'] == c['id']) setState(() { _selected!['full_name'] = nameCtrl.text; _selected!['phone'] = phoneCtrl.text; _selected!['email'] = emailCtrl.text; });
            _fetch(_searchCtrl.text);
          } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger)); }
        }, child: Text(S.t('action_save'))),
      ],
    ));
  }

  void _deleteCustomer() async {
    if (!AppSession.isOwner) return;
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(S.t('cust_archive_title')), content: Text(S.t('cust_archive_msg')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.t('action_cancel'))),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning, foregroundColor: Colors.white), child: Text(S.t('action_archive'))),
      ],
    ));
    if (confirm != true) return;
    try {
      await Supabase.instance.client.from('customers').update({'is_active': false}).eq('id', _selected!['id']);
      setState(() => _selected = null);
      _fetch(_searchCtrl.text);
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger)); }
  }

  void _recordPayment() async {
    final amountCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(S.t('cust_receive_payment')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${S.t('pos_credit')}: ${_balance.toStringAsFixed(0)} ${S.t('misc_currency')}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger)),
        const SizedBox(height: 12),
        TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Montant', border: OutlineInputBorder())),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.t('action_cancel'))),
        ElevatedButton(onPressed: () async {
          final amount = double.tryParse(amountCtrl.text);
          if (amount == null || amount <= 0) return;
          Navigator.pop(ctx);
          try {
            await DebtRecoveryService.instance.recordDebtPayment(customerId: _selected!['id'], amount: amount, paymentMethod: 'cash', storeId: AppSession.currentStoreId ?? '');
            _fetchHistory(_selected!['id']);
          } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger)); }
        }, child: Text(S.t('action_confirm'))),
      ],
    ));
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Map<String, dynamic> _getTierInfo(int points) {
    if (points >= 2000) {
      return {'name': 'Gold', 'color': Colors.amber, 'progress': 1.0};
    } else if (points >= 500) {
      return {'name': 'Silver', 'color': AppColors.mobileTextSecondary, 'progress': (points - 500) / 1500.0};
    } else {
      return {'name': 'Bronze', 'color': const Color(0xFF8B4513), 'progress': points > 0 ? points / 500.0 : 0.0};
    }
  }

  Future<void> _showCustomerProfile(Map<String, dynamic> customer) async {
    Map<String, dynamic> profile;

    if (AppSession.isOfflineMode) {
      final isar = await IsarService.getInstance();
      final localInvoices = await isar.invoiceLocals
          .filter()
          .customerIdEqualTo(customer['id'])
          .typeEqualTo('out')
          .findAll();

      final totalSpent = localInvoices.fold<double>(0.0, (s, i) => s + i.totalAmount);
      profile = {
        'id': customer['id'],
        'full_name': customer['full_name'],
        'phone': customer['phone'],
        'customer_type': customer['customer_type'] ?? 'retail',
        'loyalty_points': 0,
        'credit_limit': customer['credit_limit'] ?? 0,
        'balance': (customer['balance'] as num?)?.toDouble() ?? 0.0,
        'total_purchases': localInvoices.length,
        'total_spent': totalSpent,
        'avg_order_value': localInvoices.isEmpty ? 0.0 : totalSpent / localInvoices.length,
        'last_purchase_date': localInvoices.isNotEmpty ? localInvoices.first.createdAt?.toIso8601String() : null,
        'created_at': customer['created_at'],
        'overdue_amount': 0,
        'top_category': null,
      };
    } else {
      try {
        final res = await Supabase.instance.client.rpc('get_customer_profile', params: {'p_customer_id': customer['id']});
        profile = Map<String, dynamic>.from(res);
      } catch (e) {
        debugPrint("Error fetching customer profile: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur chargement profil: $e'), backgroundColor: AppColors.danger),
          );
        }
        return;
      }
    }

    if (!mounted) return;

    final initials = _getInitials(profile['full_name'] ?? '');
    final memberSince = profile['created_at'] != null
        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(profile['created_at']))
        : 'N/A';
    final totalPurchases = (profile['total_purchases'] as num?)?.toInt() ?? 0;
    final totalSpent = (profile['total_spent'] as num?)?.toDouble() ?? 0.0;
    final avgOrderValue = (profile['avg_order_value'] as num?)?.toDouble() ?? 0.0;
    final loyaltyPoints = (profile['loyalty_points'] as num?)?.toInt() ?? 0;
    final creditLimit = (profile['credit_limit'] as num?)?.toDouble() ?? 0.0;
    final balance = (profile['balance'] as num?)?.toDouble() ?? 0.0;
    final overdueAmount = (profile['overdue_amount'] as num?)?.toDouble() ?? 0.0;
    final lastPurchaseDate = profile['last_purchase_date'] != null
        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(profile['last_purchase_date']))
        : 'Aucun';
    final topCategory = profile['top_category'] as String? ?? 'N/A';
    final customerType = profile['customer_type'] as String? ?? 'retail';
    final phone = profile['phone'] as String? ?? '';
    final fullName = profile['full_name'] as String? ?? '';

    final currencyFormat = NumberFormat('#,##0.00', 'fr');
    final noDecFormat = NumberFormat('#,##0', 'fr');
    final tierInfo = _getTierInfo(loyaltyPoints);
    final creditProgress = creditLimit > 0 ? (balance / creditLimit).clamp(0.0, 1.0) : 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: AppColors.mobileBorderStrong, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                _buildProfileHeader(initials, fullName, customerType, memberSince),
                const SizedBox(height: 24),
                _buildStatsRow(totalPurchases, totalSpent, avgOrderValue, currencyFormat, noDecFormat),
                const SizedBox(height: 24),
                _buildLoyaltyCard(loyaltyPoints, tierInfo, noDecFormat),
                const SizedBox(height: 24),
                _buildFinancialSection(creditLimit, balance, overdueAmount, creditProgress, currencyFormat),
                const SizedBox(height: 24),
                _buildLastPurchaseInfo(lastPurchaseDate, topCategory),
                const SizedBox(height: 24),
                _buildActionButtons(sheetContext, customer, phone, balance, overdueAmount),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(String initials, String name, String customerType, String memberSince) {
    final isWholesale = customerType == 'wholesale';
    final badgeColor = isWholesale ? AppColors.mobilePrimary : AppColors.success;
    final badgeText = isWholesale ? 'GROS' : 'DÉTAIL';

    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: AppColors.mobilePrimary,
          child: Text(initials, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        const SizedBox(height: 12),
        Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: badgeColor),
          ),
          child: Text(badgeText, style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
        const SizedBox(height: 8),
        Text('Membre depuis $memberSince', style: TextStyle(color: AppColors.mobileTextSecondary, fontSize: 13)),
      ],
    );
  }

  Widget _buildStatsRow(int totalPurchases, double totalSpent, double avgOrderValue, NumberFormat currencyFormat, NumberFormat noDecFormat) {
    return Row(
      children: [
        _buildStatCard('Achats', noDecFormat.format(totalPurchases), Icons.shopping_bag, AppColors.mobilePrimary),
        const SizedBox(width: 12),
        _buildStatCard('Total', '${currencyFormat.format(totalSpent)} DA', Icons.attach_money, AppColors.success),
        const SizedBox(width: 12),
        _buildStatCard('Moyen', '${currencyFormat.format(avgOrderValue)} DA', Icons.trending_up, AppColors.warning),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: AppColors.mobileTextSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildLoyaltyCard(int points, Map<String, dynamic> tierInfo, NumberFormat format) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber[50]!, AppColors.warningLight!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star, color: AppColors.warning, size: 28),
              const SizedBox(width: 8),
              Text('Fidélité', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber[900])),
              const Spacer(),
              Text('${format.format(points)} pts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.amber[900])),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (tierInfo['progress'] as double).clamp(0.0, 1.0),
              backgroundColor: AppColors.mobileBorder,
              valueColor: AlwaysStoppedAnimation<Color>(tierInfo['color'] as Color),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTierBadge('Bronze', points < 500, const Color(0xFF8B4513)),
              _buildTierBadge('Silver', points < 500 || points >= 2000, AppColors.mobileTextSecondary),
              _buildTierBadge('Gold', points < 2000, Colors.amber),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: (tierInfo['color'] as Color).withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Niveau ${tierInfo['name']}',
                style: TextStyle(fontWeight: FontWeight.bold, color: tierInfo['color'] as Color, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierBadge(String name, bool inactive, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: inactive ? AppColors.mobileBorder : color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: inactive ? AppColors.mobileBorderStrong! : color),
      ),
      child: Text(
        name,
        style: TextStyle(
          color: inactive ? AppColors.mobileTextSecondary : color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildFinancialSection(double creditLimit, double balance, double overdueAmount, double creditProgress, NumberFormat format) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dangerLight?.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.credit_card, color: AppColors.danger, size: 24),
              const SizedBox(width: 8),
              Text('Crédit & Solde', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red[900])),
            ],
          ),
          const SizedBox(height: 12),
          if (creditLimit > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Limite: ${format.format(creditLimit)} DA', style: const TextStyle(fontSize: 13)),
                Text('${(creditProgress * 100).toStringAsFixed(0)}% utilisé', style: const TextStyle(fontSize: 12, color: AppColors.mobileTextSecondary)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: creditProgress,
                backgroundColor: AppColors.mobileBorder,
                valueColor: AlwaysStoppedAnimation<Color>(creditProgress > 0.8 ? AppColors.danger : AppColors.warning),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Text('Solde actuel: ', style: TextStyle(color: Colors.grey[700])),
              Text(
                '${format.format(balance)} DA',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: balance > 0 ? AppColors.danger : AppColors.success),
              ),
            ],
          ),
          if (overdueAmount > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 20),
                  const SizedBox(width: 8),
                  Text('Impayé: ${format.format(overdueAmount)} DA', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLastPurchaseInfo(String lastPurchaseDate, String topCategory) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50]?.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dernier achat', style: TextStyle(color: AppColors.mobileTextSecondary, fontSize: 12)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 6),
                    Text(lastPurchaseDate, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Catégorie favorite', style: TextStyle(color: AppColors.mobileTextSecondary, fontSize: 12)),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.category, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 6),
                    Text(topCategory, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext sheetContext, Map<String, dynamic> customer, String phone, double balance, double overdueAmount) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            icon: Icons.chat,
            label: 'WhatsApp',
            color: AppColors.success,
            onPressed: phone.isNotEmpty
                ? () => ContactUtils.sendWhatsApp(context, phone, customer['full_name'] ?? '', balance)
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionButton(
            icon: Icons.phone,
            label: 'Appeler',
            color: AppColors.info,
            onPressed: phone.isNotEmpty
                ? () async {
                    final url = Uri.parse('tel:${ContactUtils.cleanPhone(phone)}');
                    if (await canLaunchUrl(url)) await launchUrl(url);
                  }
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionButton(
            icon: Icons.receipt_long,
            label: 'Factures',
            color: AppColors.mobilePrimary,
            onPressed: () => Navigator.pop(sheetContext),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionButton(
            icon: Icons.payments,
            label: 'Paiement',
            color: AppColors.warning,
            onPressed: () {
              Navigator.pop(sheetContext);
              _recordPayment();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(icon, color: onPressed != null ? color : AppColors.mobileTextSecondary, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(color: onPressed != null ? color : AppColors.mobileTextSecondary, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.t('nav_clients')),
        backgroundColor: AppColors.mobileBackground,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_debtFilter ? Icons.filter_list_off : Icons.filter_list),
            tooltip: S.t('cust_filter_debt'),
            onPressed: () => setState(() { _debtFilter = !_debtFilter; _fetch(_searchCtrl.text); }),
          ),
          IconButton(icon: const Icon(Icons.person_add), onPressed: _addCustomer),
        ],
      ),
      body: _isLoading
          ? const Padding(padding: EdgeInsets.all(16), child: AppShimmerListTile())
          : Row(
              children: [
                // Customer list
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.4,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: S.t('cust_search_hint'), prefixIcon: const Icon(Icons.search, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onChanged: (v) => _fetch(v),
                        ),
                      ),
                      Expanded(
                        child: _customers.isEmpty
                            ? Center(child: Text(S.t('cust_no_results')))
                            : RefreshIndicator(
                                onRefresh: () => _fetch(_searchCtrl.text),
                                child: ListView.builder(
                                itemCount: _customers.length,
                                itemBuilder: (_, i) {
                                  final c = _customers[i];
                                  final sel = _selected?['id'] == c['id'];
                                  final bal = (c['balance'] as num?)?.toDouble() ?? 0;
                                  return ListTile(
                                    dense: true,
                                    selected: sel,
                                    selectedTileColor: AppColors.mobilePrimary.withOpacity(0.1),
                                    leading: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: sel ? AppColors.mobilePrimary : AppColors.mobileBorder,
                                      child: Icon(Icons.person, size: 16, color: sel ? Colors.white : Colors.grey[700]),
                                    ),
                                    title: Text(c['full_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    subtitle: Text(c['phone'] ?? '', style: const TextStyle(fontSize: 10)),
                                    trailing: bal > 0
                                        ? Text('${bal.toStringAsFixed(0)} ${S.t('misc_currency')}', style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 10))
                                        : const Icon(Icons.check_circle, color: AppColors.success, size: 14),
                                    onTap: () { setState(() => _selected = c); _fetchHistory(c['id']); _showCustomerProfile(c); },
                                  );
                                  },
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, color: AppColors.mobileBorderStrong),
                // Detail panel
                Expanded(
                  child: _selected == null
                      ? Center(child: Text(S.t('cust_no_client_selected'), style: const TextStyle(color: AppColors.mobileTextSecondary)))
                      : _loadingHistory
                          ? const Padding(padding: EdgeInsets.all(16), child: AppShimmerListTile())
                          : Column(
                              children: [
                                // Header
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  color: AppColors.mobilePrimary.withOpacity(0.05),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(_selected!['full_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.mobilePrimary)),
                                            const SizedBox(height: 4),
                                            Text(_selected!['phone'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.mobileTextSecondary)),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(S.t('pos_credit'), style: const TextStyle(fontSize: 11, color: AppColors.mobileTextSecondary)),
                                          Text('${_balance.toStringAsFixed(0)} ${S.t('misc_currency')}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _balance > 0 ? AppColors.danger : AppColors.success)),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (AppSession.isOwner) ...[
                                                IconButton(icon: const Icon(Icons.edit, size: 16, color: AppColors.warning), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: _editCustomer),
                                                const SizedBox(width: 8),
                                                IconButton(icon: const Icon(Icons.archive, size: 16, color: AppColors.danger), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: _deleteCustomer),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Tabs
                                TabBar(
                                  controller: _tabCtrl,
                                  labelColor: AppColors.mobileBackground,
                                  unselectedLabelColor: AppColors.mobileTextSecondary,
                                  tabs: [
                                    Tab(text: '${S.t('nav_invoices')} (${_invoices.length})'),
                                    Tab(text: '${S.t('nav_payments')} (${_payments.length})'),
                                  ],
                                ),
                                Expanded(
                                  child: TabBarView(
                                    controller: _tabCtrl,
                                    children: [
                                      _buildInvoiceList(),
                                      _buildPaymentList(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                ),
              ],
            ),
      floatingActionButton: _selected != null
          ? FloatingActionButton(
              mini: true,
              onPressed: _recordPayment,
              backgroundColor: AppColors.success,
              child: const Icon(Icons.payments, color: Colors.white, size: 20),
            )
          : null,
    );
  }

  Widget _buildInvoiceList() {
    if (_invoices.isEmpty) return Center(child: Text(S.t('label_no_data')));
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _invoices.length,
      itemBuilder: (_, i) {
        final inv = _invoices[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 4),
          child: ListTile(
            dense: true,
            title: Text('${S.t('nav_invoices')} ${inv['invoice_number'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            subtitle: Text('${inv['created_at']?.toString().substring(0, 10) ?? ''} • ${inv['status'] ?? ''}', style: const TextStyle(fontSize: 10)),
            trailing: Text('${(inv['total_amount'] as num?)?.toDouble() ?? 0} ${S.t('misc_currency')}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        );
      },
    );
  }

  Widget _buildPaymentList() {
    if (_payments.isEmpty) return Center(child: Text(S.t('label_no_data')));
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _payments.length,
      itemBuilder: (_, i) {
        final p = _payments[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 4),
          child: ListTile(
            dense: true,
            title: Text('${p['created_at']?.toString().substring(0, 10) ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            subtitle: Text('${p['payment_method'] ?? ''}', style: const TextStyle(fontSize: 10)),
            trailing: Text('+${(p['amount'] as num?)?.toDouble() ?? 0} ${S.t('misc_currency')}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success, fontSize: 12)),
          ),
        );
      },
    );
  }
}
