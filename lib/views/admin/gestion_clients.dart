import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_session.dart';
import '../../local_db/isar_service.dart';
import '../../local_db/collections/customer_local.dart';
import '../../local_db/collections/invoice_local.dart';
import '../../local_db/collections/payment_local.dart';
import '../../local_db/collections/user_profile_local.dart';
import '../../core/app_strings.dart';
import '../../shared/utils/contact_utils.dart';

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

class GestionClientsScreen extends StatefulWidget {
  const GestionClientsScreen({super.key});

  @override
  State<GestionClientsScreen> createState() => _GestionClientsScreenState();
}

class _GestionClientsScreenState extends State<GestionClientsScreen> with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();

  List<dynamic> _customers = [];
  bool _isLoading = true;
  bool _showOnlyWithDebt = false;

  Map<String, dynamic>? _selectedCustomer;
  late TabController _tabController;

  List<dynamic> _invoices = [];
  List<dynamic> _payments = [];
  bool _isLoadingHistory = false;
  double _currentBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchCustomers();
  }

  Future<void> _fetchCustomers([String query = '']) async {
    setState(() => _isLoading = true);

    if (AppSession.isOfflineMode) {
      final isar = await IsarService.getInstance();
      var localQuery = isar.customerLocals.filter().isActiveEqualTo(true);

      if (query.isNotEmpty) {
        final q = query.toLowerCase();
        localQuery = localQuery.group((qFilter) =>
          qFilter.fullNameContains(q, caseSensitive: false)
                 .or()
                 .phoneContains(q, caseSensitive: false)
        );
      }

      final response = await localQuery.findAll();
      final mapped = response.map((c) => {
        'id': c.supabaseId,
        'full_name': c.fullName,
        'phone': c.phone,
        'address': c.address,
        'email': c.email,
        'balance': c.balance,
        'is_active': c.isActive,
      }).toList();

      if (mounted) {
        setState(() {
          if (_showOnlyWithDebt) {
            _customers = mapped.where((c) => (c['balance'] as num? ?? 0) > 0).toList();
          } else {
            _customers = mapped;
          }
          _isLoading = false;
        });
      }
      return;
    }

    try {
      var queryBuilder = Supabase.instance.client
          .from('customers')
          .select()
          .eq('is_active', true);

      if (query.isNotEmpty) {
        queryBuilder = queryBuilder.or('full_name.ilike.%$query%,phone.ilike.%$query%');
      }

      final response = await queryBuilder.order('full_name', ascending: true);

      if (mounted) {
        setState(() {
          if (_showOnlyWithDebt) {
            _customers = (response as List).where((c) => (c['balance'] as num? ?? 0) > 0).toList();
          } else {
            _customers = response;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Error fetching customers: $e");
    }
  }

  Future<void> _fetchCustomerHistory(String customerId) async {
    setState(() => _isLoadingHistory = true);

    if (AppSession.isOfflineMode) {
      final isar = await IsarService.getInstance();

      final localInvoices = await isar.invoiceLocals
          .filter()
          .customerIdEqualTo(customerId)
          .typeEqualTo('out')
          .findAll();

      final localPayments = await isar.paymentLocals
          .filter()
          .customerIdEqualTo(customerId)
          .findAll();

      final profiles = await isar.userProfileLocals.where().findAll();
      final profileMap = {for (var p in profiles) p.supabaseId: p};

      final mappedInvoices = localInvoices.map((inv) {
        final profile = profileMap[inv.userId];
        return {
          'id': inv.supabaseId,
          'invoice_number': inv.invoiceNumber,
          'total_amount': inv.totalAmount,
          'paid_amount': inv.paidAmount,
          'status': inv.status,
          'type': inv.type,
          'created_at': inv.createdAt?.toIso8601String(),
          'user_profiles': profile != null ? {'full_name': profile.fullName} : null,
        };
      }).toList();

      final mappedPayments = localPayments.map((p) {
        final profile = profileMap[p.userId];
        return {
          'id': p.supabaseId,
          'amount': p.amount,
          'payment_method': p.paymentMethod,
          'created_at': p.createdAt?.toIso8601String(),
          'user_profiles': profile != null ? {'full_name': profile.fullName} : null,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _invoices = mappedInvoices;
          _payments = mappedPayments;

          double totalInvoiced = mappedInvoices.fold(0, (sum, inv) => sum + (inv['total_amount'] as num).toDouble());
          double totalPaid = mappedPayments.fold(0, (sum, p) => sum + (p['amount'] as num).toDouble());
          _currentBalance = totalInvoiced - totalPaid;

          if (_selectedCustomer != null) {
            _selectedCustomer!['balance'] = _currentBalance;
          }
          _isLoadingHistory = false;
        });
      }
      return;
    }

    try {
      var invoicesQuery = Supabase.instance.client
          .from('invoices')
          .select('*, user_profiles(full_name)')
          .eq('customer_id', customerId)
          .eq('type', 'out');

      var paymentsQuery = Supabase.instance.client
          .from('payments')
          .select('*, user_profiles(full_name)')
          .eq('customer_id', customerId);

      if (AppSession.isEmployee && AppSession.currentStoreId != null) {
        invoicesQuery = invoicesQuery.eq('store_id', AppSession.currentStoreId!);
        paymentsQuery = paymentsQuery.eq('store_id', AppSession.currentStoreId!);
      }

      final invoicesRes = await invoicesQuery.order('created_at', ascending: false);
      final paymentsRes = await paymentsQuery.order('payment_date', ascending: false);

      if (mounted) {
        setState(() {
          _invoices = invoicesRes;
          _payments = paymentsRes;
          _isLoadingHistory = false;
        });
      }
      final balRes = await Supabase.instance.client.rpc('get_customer_balance', params: {'p_customer_id': customerId});
      if (mounted) {
        setState(() {
          _currentBalance = (balRes as num?)?.toDouble() ?? 0.0;
          if (_selectedCustomer != null) {
            _selectedCustomer!['balance'] = _currentBalance;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingHistory = false);
      debugPrint("Error fetching history: $e");
    }
  }

  void _showAddEditCustomerDialog([Map<String, dynamic>? customer]) {
    final isEdit = customer != null;
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: customer?['full_name'] ?? '');
    final phoneCtrl = TextEditingController(text: customer?['phone'] ?? '');
    final emailCtrl = TextEditingController(text: customer?['email'] ?? '');

    InputDecoration _fieldDeco(String label, IconData icon) {
      return InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _T.textSecondary, fontSize: 13),
        prefixIcon: Icon(icon, color: _T.textMuted, size: 18),
        filled: true,
        fillColor: _T.bgTable,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _T.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _T.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _T.accentBlue),
        ),
      );
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _T.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isEdit ? S.t('cust_edit') : S.t('cust_add'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _T.textPrimary)),
                const SizedBox(height: 18),
                TextFormField(
                  controller: nameCtrl,
                  style: const TextStyle(color: _T.textPrimary, fontSize: 14),
                  decoration: _fieldDeco(S.t('cust_full_name'), Icons.person_outline_rounded),
                  validator: (v) => v!.isEmpty ? S.t('msg_required') : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: phoneCtrl,
                  style: const TextStyle(color: _T.textPrimary, fontSize: 14),
                  decoration: _fieldDeco(S.t('cust_phone'), Icons.phone_outlined),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: emailCtrl,
                  style: const TextStyle(color: _T.textPrimary, fontSize: 14),
                  decoration: _fieldDeco(S.t('cust_email'), Icons.email_outlined),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(S.t('action_cancel'), style: const TextStyle(color: _T.textSecondary)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        Navigator.pop(context);

                        try {
                          final Map<String, dynamic> data = {
                            'full_name': nameCtrl.text.trim(),
                            'phone': phoneCtrl.text.trim(),
                            'email': emailCtrl.text.trim(),
                          };

                          if (isEdit) {
                            if (!AppSession.isOwner) {
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.t('msg_access_denied')), backgroundColor: _T.statusUnpaidText));
                              return;
                            }
                            await Supabase.instance.client.from('customers').update(data).eq('id', customer['id']);
                            if (_selectedCustomer?['id'] == customer['id']) {
                              setState(() {
                                 _selectedCustomer!['full_name'] = data['full_name'];
                                 _selectedCustomer!['phone'] = data['phone'];
                                 _selectedCustomer!['email'] = data['email'];
                              });
                            }
                          } else {
                            data['balance'] = 0;
                            data['is_active'] = true;
                            await Supabase.instance.client.from('customers').insert(data);

                            try {
                              await Supabase.instance.client.from('activity_logs').insert({
                                'user_id': AppSession.currentUserId,
                                'action_type': 'add_customer',
                                'description': 'Nouveau client ajouté: ${data['full_name']}',
                                'store_id': AppSession.currentStoreId,
                              });
                            } catch (e, s) { debugPrint('[GestionClients] activityLog error: $e\n$s'); }
                          }

                          _fetchCustomers(_searchController.text);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(isEdit ? 'Client modifié.' : 'Client ajouté.'),
                              backgroundColor: _T.statusPaidText,
                            ));
                          }
                        } on PostgrestException catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.code == '42501' ? 'Accès refusé : Autorisations insuffisantes' : 'Erreur: ${e.message}'), backgroundColor: _T.statusUnpaidText));
                        } catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: _T.statusUnpaidText));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _T.accentGold,
                        foregroundColor: _T.bgPage,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                      child: Text(isEdit ? 'Modifier' : 'Enregistrer', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteCustomer(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _T.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(S.t('cust_archive_title'), style: const TextStyle(color: _T.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text(S.t('cust_archive_msg'), style: const TextStyle(color: _T.textSecondary, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.t('action_cancel'), style: const TextStyle(color: _T.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _T.accentGold, foregroundColor: _T.bgPage, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text(S.t('action_archive')),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await Supabase.instance.client.from('customers').update({'is_active': false}).eq('id', id);
      if (_selectedCustomer?['id'] == id) setState(() => _selectedCustomer = null);
      _fetchCustomers(_searchController.text);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.t('cust_archived')), backgroundColor: _T.accentGold));
    } on PostgrestException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.code == '42501' ? S.t('msg_access_denied') : '${S.t('msg_error')}: ${e.message}'), backgroundColor: _T.statusUnpaidText));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${S.t('msg_error')}: $e'), backgroundColor: _T.statusUnpaidText));
    }
  }

  void _selectCustomer(Map<String, dynamic> customer) {
    setState(() {
      _selectedCustomer = customer;
    });
    _fetchCustomerHistory(customer['id']);
    _showCustomerProfile(customer);
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
      return {'name': 'Gold', 'color': _T.statusRefundedText, 'progress': 1.0};
    } else if (points >= 500) {
      return {'name': 'Silver', 'color': _T.textSecondary, 'progress': (points - 500) / 1500.0};
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
            SnackBar(content: Text('Erreur chargement profil: $e'), backgroundColor: _T.statusUnpaidText),
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
              color: _T.bgCard,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: _T.borderColor, borderRadius: BorderRadius.circular(2)),
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
    final badgeColor = _T.accentBlue;
    final badgeText = isWholesale ? 'GROS' : 'DÉTAIL';

    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: _T.accentBlue,
          child: Text(initials, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _T.textPrimary)),
        ),
        const SizedBox(height: 12),
        Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _T.textPrimary)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: badgeColor),
          ),
          child: Text(badgeText, style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
        const SizedBox(height: 8),
        Text('Membre depuis $memberSince', style: const TextStyle(color: _T.textSecondary, fontSize: 13)),
      ],
    );
  }

  Widget _buildStatsRow(int totalPurchases, double totalSpent, double avgOrderValue, NumberFormat currencyFormat, NumberFormat noDecFormat) {
    return Row(
      children: [
        _buildStatCard('Achats', noDecFormat.format(totalPurchases), Icons.shopping_bag, _T.accentBlue),
        const SizedBox(width: 12),
        _buildStatCard('Total', '${currencyFormat.format(totalSpent)} DA', Icons.attach_money, _T.statusPaidText),
        const SizedBox(width: 12),
        _buildStatCard('Moyen', '${currencyFormat.format(avgOrderValue)} DA', Icons.trending_up, _T.accentGold),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: _T.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildLoyaltyCard(int points, Map<String, dynamic> tierInfo, NumberFormat format) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_T.statusRefundedBg, _T.bgTableHeader],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _T.statusRefundedText),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star, color: _T.statusRefundedText, size: 28),
              const SizedBox(width: 8),
              const Text('Fidélité', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _T.statusRefundedText)),
              const Spacer(),
              Text('${format.format(points)} pts', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _T.statusRefundedText)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (tierInfo['progress'] as double).clamp(0.0, 1.0),
              backgroundColor: _T.borderColor,
              valueColor: AlwaysStoppedAnimation<Color>(tierInfo['color'] as Color),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTierBadge('Bronze', points < 500, const Color(0xFF8B4513)),
              _buildTierBadge('Silver', points < 500 || points >= 2000, _T.textSecondary),
              _buildTierBadge('Gold', points < 2000, _T.statusRefundedText),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: (tierInfo['color'] as Color).withValues(alpha: 0.2),
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
        color: inactive ? _T.borderColor : color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: inactive ? _T.borderColor : color),
      ),
      child: Text(
        name,
        style: TextStyle(
          color: inactive ? _T.textSecondary : color,
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
        color: _T.statusUnpaidBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _T.statusUnpaidBg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.credit_card, color: _T.statusUnpaidText, size: 24),
              SizedBox(width: 8),
              Text('Crédit & Solde', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _T.statusUnpaidText)),
            ],
          ),
          const SizedBox(height: 12),
          if (creditLimit > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Limite: ${format.format(creditLimit)} DA', style: const TextStyle(fontSize: 13, color: _T.textPrimary)),
                Text('${(creditProgress * 100).toStringAsFixed(0)}% utilisé', style: const TextStyle(fontSize: 12, color: _T.textSecondary)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: creditProgress,
                backgroundColor: _T.borderColor,
                valueColor: AlwaysStoppedAnimation<Color>(creditProgress > 0.8 ? _T.statusUnpaidText : _T.accentGold),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              const Text('Solde actuel: ', style: TextStyle(color: _T.textSecondary)),
              Text(
                '${format.format(balance)} DA',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: balance > 0 ? _T.statusUnpaidText : _T.statusPaidText),
              ),
            ],
          ),
          if (overdueAmount > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _T.statusUnpaidBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _T.statusUnpaidText),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: _T.statusUnpaidText, size: 20),
                  const SizedBox(width: 8),
                  Text('Impayé: ${format.format(overdueAmount)} DA', style: const TextStyle(fontWeight: FontWeight.bold, color: _T.statusUnpaidText)),
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
        color: _T.accentBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _T.accentBlue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dernier achat', style: TextStyle(color: _T.textSecondary, fontSize: 12)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: _T.accentBlue),
                    const SizedBox(width: 6),
                    Text(lastPurchaseDate, style: const TextStyle(fontWeight: FontWeight.bold, color: _T.textPrimary)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Catégorie favorite', style: TextStyle(color: _T.textSecondary, fontSize: 12)),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Icon(Icons.category, size: 16, color: _T.accentBlue),
                    const SizedBox(width: 6),
                    Text(topCategory, style: const TextStyle(fontWeight: FontWeight.bold, color: _T.textPrimary)),
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
            color: _T.statusPaidText,
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
            color: _T.accentBlue,
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
            color: _T.accentBlue,
            onPressed: () => Navigator.pop(sheetContext),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionButton(
            icon: Icons.payments,
            label: 'Paiement',
            color: _T.accentGold,
            onPressed: () {
              Navigator.pop(sheetContext);
              _showAddPaymentDialog();
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
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(icon, color: onPressed != null ? color : _T.textMuted, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(color: onPressed != null ? color : _T.textMuted, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddPaymentDialog() {
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _T.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(S.t('cust_receive_payment'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _T.textPrimary)),
              const SizedBox(height: 16),
              Text("${S.t('pos_credit')}: ${_currentBalance.toStringAsFixed(2)} ${S.t('misc_currency')}",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: _T.statusUnpaidText)),
              const SizedBox(height: 16),
              TextFormField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: _T.textPrimary),
                decoration: InputDecoration(
                  labelText: S.t('cust_payment_amount'),
                  labelStyle: const TextStyle(color: _T.textSecondary, fontSize: 13),
                  prefixIcon: const Icon(Icons.attach_money, color: _T.textMuted, size: 18),
                  filled: true,
                  fillColor: _T.bgTable,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _T.borderColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _T.borderColor)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _T.accentBlue)),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: notesCtrl,
                style: const TextStyle(color: _T.textPrimary),
                decoration: InputDecoration(
                  labelText: S.t('cust_payment_notes'),
                  labelStyle: const TextStyle(color: _T.textSecondary, fontSize: 13),
                  filled: true,
                  fillColor: _T.bgTable,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _T.borderColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _T.borderColor)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _T.accentBlue)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.t('action_cancel'), style: const TextStyle(color: _T.textSecondary))),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final amount = double.tryParse(amountCtrl.text);
                      if (amount == null || amount <= 0) return;
                      Navigator.pop(ctx);

                      try {
                        final user = Supabase.instance.client.auth.currentUser;
                        await Supabase.instance.client.from('payments').insert({
                          'customer_id': _selectedCustomer!['id'],
                          'user_id': user?.id,
                          'amount': amount,
                          'payment_method': 'cash',
                          'notes': notesCtrl.text.isEmpty ? S.t('cust_manual_payment') : notesCtrl.text,
                        });

                        try {
                          await Supabase.instance.client.from('activity_logs').insert({
                            'user_id': AppSession.currentUserId,
                            'action_type': 'debt_payment',
                            'description': 'Paiement reçu de ${_selectedCustomer!['full_name']} — ${amount.toStringAsFixed(2)} DA',
                            'store_id': AppSession.currentStoreId,
                          });
                        } catch (e, s) { debugPrint('[GestionClients] error: $e\n$s'); }

                        _fetchCustomerHistory(_selectedCustomer!['id']);
                        _fetchCustomers(_searchController.text);
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.t('msg_payment_recorded')), backgroundColor: _T.statusPaidText));
                      } on PostgrestException catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.code == '42501' ? S.t('msg_access_denied') : '${S.t('msg_error')}: ${e.message}'), backgroundColor: _T.statusUnpaidText));
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${S.t('msg_error')}: $e'), backgroundColor: _T.statusUnpaidText));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _T.accentBlue,
                      foregroundColor: _T.textPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    child: Text(S.t('action_confirm'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bgPage,
      appBar: AppBar(
        title: Text(S.t('cust_title_full'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _T.textPrimary)),
        backgroundColor: _T.bgAppBar,
        elevation: 0,
        foregroundColor: _T.textPrimary,
      ),
      body: Row(
        children: [
          // --- LEFT PANEL: LISTE DES CLIENTS ---
          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _T.bgCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _T.borderColor),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: _T.bgTable,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: _T.borderColor),
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  style: const TextStyle(color: _T.textPrimary, fontSize: 14),
                                  decoration: InputDecoration(
                                    hintText: S.t('cust_search_hint'),
                                    hintStyle: const TextStyle(color: _T.textMuted, fontSize: 13),
                                    prefixIcon: const Icon(Icons.search_rounded, color: _T.textMuted, size: 18),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onChanged: (val) => _fetchCustomers(val),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: _T.accentGold,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: IconButton(
                                onPressed: () => _showAddEditCustomerDialog(),
                                icon: const Icon(Icons.person_add_alt_1),
                                color: _T.bgPage,
                                tooltip: S.t('cust_add_tooltip'),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(S.t('cust_with_debt'), style: const TextStyle(color: _T.textSecondary, fontSize: 13)),
                            Switch(
                              value: _showOnlyWithDebt,
                              activeColor: _T.accentGold,
                              onChanged: (val) {
                                setState(() {
                                  _showOnlyWithDebt = val;
                                  _fetchCustomers(_searchController.text);
                                });
                              },
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: _T.borderColor),
                  Expanded(
                    child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: _T.accentGold))
                      : _customers.isEmpty
                        ? Center(child: Text(S.t('cust_no_results'), style: const TextStyle(color: _T.textSecondary)))
                        : ListView.separated(
                          itemCount: _customers.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, color: _T.borderColor),
                          itemBuilder: (context, index) {
                            final c = _customers[index];
                            final isSelected = _selectedCustomer?['id'] == c['id'];
                            final balance = (c['balance'] as num?)?.toDouble() ?? 0.0;
                            final hasDebt = balance > 0;

                            return ListTile(
                              selected: isSelected,
                              selectedTileColor: _T.accentBlue.withValues(alpha: 0.1),
                              leading: CircleAvatar(
                                backgroundColor: isSelected ? _T.accentBlue : _T.bgTableHover,
                                child: Icon(Icons.person, color: isSelected ? _T.textPrimary : _T.textSecondary),
                              ),
                              title: Text(c['full_name'] ?? S.t('misc_unknown'),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: _T.textPrimary, fontSize: 14)),
                              subtitle: Text(c['phone'] ?? c['email'] ?? S.t('misc_no_phone'),
                                  style: const TextStyle(color: _T.textSecondary, fontSize: 12)),
                              trailing: hasDebt
                                  ? Text('${balance.toStringAsFixed(2)} ${S.t('misc_currency')}',
                                      style: const TextStyle(color: _T.statusUnpaidText, fontWeight: FontWeight.bold))
                                  : const Icon(Icons.check_circle, color: _T.statusPaidText, size: 16),
                              onTap: () => _selectCustomer(c),
                            );
                          },
                        ),
                  ),
                ],
              ),
            ),
          ),

          // --- RIGHT PANEL: CRM & PROFIL CLIENT ---
          Expanded(
            flex: 6,
            child: Container(
              margin: const EdgeInsetsDirectional.only(top: 16, bottom: 16, end: 16),
              decoration: BoxDecoration(
                color: _T.bgCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _T.borderColor),
              ),
              child: _selectedCustomer == null
                  ? Center(child: Text(S.t('cust_no_client_selected'), style: const TextStyle(color: _T.textSecondary, fontSize: 18)))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // HEADER DU CLIENT
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: const BoxDecoration(
                            color: _T.bgTableHeader,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_selectedCustomer!['full_name'],
                                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _T.accentGold, letterSpacing: -0.3)),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.phone, size: 16, color: _T.textSecondary),
                                        const SizedBox(width: 8),
                                        Text(_selectedCustomer!['phone'] ?? 'Non renseigné', style: const TextStyle(color: _T.textSecondary, fontSize: 13)),
                                        const SizedBox(width: 24),
                                        const Icon(Icons.email, size: 16, color: _T.textSecondary),
                                        const SizedBox(width: 8),
                                        Text(_selectedCustomer!['email'] ?? 'Non renseigné', style: const TextStyle(color: _T.textSecondary, fontSize: 13)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text("Crédit (Dette)", style: TextStyle(color: _T.textSecondary, fontSize: 12)),
                                  Text(
                                    '${_currentBalance.toStringAsFixed(2)} DA',
                                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _currentBalance > 0 ? _T.statusUnpaidText : _T.statusPaidText),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      if (AppSession.isOwner) ...[
                                        IconButton(icon: const Icon(Icons.edit, color: _T.accentGold, size: 20), onPressed: () => _showAddEditCustomerDialog(_selectedCustomer)),
                                        IconButton(icon: const Icon(Icons.delete, color: _T.statusUnpaidText, size: 20), onPressed: () => _deleteCustomer(_selectedCustomer!['id'])),
                                      ]
                                    ],
                                  )
                                ],
                              )
                            ],
                          ),
                        ),

                        // ONGLETS (TABS)
                        TabBar(
                          controller: _tabController,
                          labelColor: _T.accentGold,
                          unselectedLabelColor: _T.textSecondary,
                          indicatorColor: _T.accentGold,
                          tabs: [
                            Tab(icon: const Icon(Icons.shopping_bag), text: S.t('cust_tabs_invoices')),
                            Tab(icon: const Icon(Icons.account_balance_wallet), text: S.t('cust_tabs_payments')),
                          ],
                        ),

                        // CONTENU DES ONGLETS
                        Expanded(
                          child: _isLoadingHistory
                              ? const Center(child: CircularProgressIndicator(color: _T.accentGold))
                              : TabBarView(
                                  controller: _tabController,
                                  children: [
                                    _buildInvoicesTab(),
                                    _buildPaymentsTab(),
                                  ],
                                ),
                        ),

                        // BOUTON DE PAIEMENT RAPIDE
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: ElevatedButton.icon(
                            onPressed: _showAddPaymentDialog,
                            icon: const Icon(Icons.payments),
                            label: Text(S.t('cust_register_payment_btn'), style: const TextStyle(fontSize: 16)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _T.accentGold,
                              foregroundColor: _T.bgPage,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoicesTab() {
    if (_invoices.isEmpty) return Center(child: Text(S.t('cust_no_purchases'), style: const TextStyle(color: _T.textSecondary)));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _invoices.length,
      itemBuilder: (context, index) {
        final inv = _invoices[index];
        final total = (inv['total_amount'] as num?)?.toDouble() ?? 0;
        final paid = (inv['paid_amount'] as num?)?.toDouble() ?? 0;
        final date = DateTime.parse(inv['created_at']).toLocal();

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: _T.bgTable,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _T.borderColor),
          ),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: _T.bgTableHover, child: const Icon(Icons.shopping_bag, color: _T.accentBlue)),
            title: Text(inv['invoice_number'], style: const TextStyle(fontWeight: FontWeight.bold, color: _T.accentBlue)),
            subtitle: Text("${date.day}/${date.month}/${date.year} • ${S.t('sales_sold_by')}: ${inv['user_profiles']['full_name']}",
                style: const TextStyle(color: _T.textSecondary, fontSize: 12)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("${S.t('label_total')}: ${total.toStringAsFixed(2)} ${S.t('misc_currency')}",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: _T.accentGold)),
                Text("${S.t('pos_paid_status')}: ${paid.toStringAsFixed(2)} ${S.t('misc_currency')}",
                    style: TextStyle(color: paid < total ? _T.statusUnpaidText : _T.statusPaidText, fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentsTab() {
    if (_payments.isEmpty) return Center(child: Text(S.t('cust_no_payments'), style: const TextStyle(color: _T.textSecondary)));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _payments.length,
      itemBuilder: (context, index) {
        final pay = _payments[index];
        final amount = (pay['amount'] as num?)?.toDouble() ?? 0;
        final date = DateTime.parse(pay['payment_date']).toLocal();

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: _T.bgTable,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _T.borderColor),
          ),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: _T.statusPaidBg, child: const Icon(Icons.check_circle, color: _T.statusPaidText)),
            title: Text("${S.t('cust_payment_of')} ${amount.toStringAsFixed(2)} ${S.t('misc_currency')}",
                style: const TextStyle(fontWeight: FontWeight.bold, color: _T.statusPaidText)),
            subtitle: Text("${date.day}/${date.month}/${date.year} • ${S.t('label_notes')}: ${pay['notes']}",
                style: const TextStyle(color: _T.textSecondary, fontSize: 12)),
          ),
        );
      },
    );
  }
}