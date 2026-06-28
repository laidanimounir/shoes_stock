import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:isar/isar.dart';
import '../../core/app_session.dart';
import '../../local_db/isar_service.dart';
import '../../local_db/collections/supplier_local.dart';
import '../../local_db/collections/invoice_local.dart';
import '../../local_db/collections/payment_local.dart';
import '../../local_db/collections/user_profile_local.dart';
import '../../core/app_strings.dart';
import 'comparaison_fournisseur_sheet.dart';

class GestionFournisseursScreen extends StatefulWidget {
  const GestionFournisseursScreen({super.key});

  @override
  State<GestionFournisseursScreen> createState() => _GestionFournisseursScreenState();
}

class _GestionFournisseursScreenState extends State<GestionFournisseursScreen> {
  List<dynamic> _suppliers = [];
  List<dynamic> _filteredSuppliers = [];
  bool _isLoading = true;
  bool _showOnlyWithDebt = false;

  String? _userRole;

  @override
  void initState() {
    super.initState();
    _initRoleAndFetch();
  }

  Future<void> _initRoleAndFetch() async {
    if (AppSession.isOfflineMode) {
      final isar = await IsarService.getInstance();
      final userId = AppSession.currentUserId;
      if (userId != null) {
        final profile = await isar.userProfileLocals
            .filter()
            .supabaseIdEqualTo(userId)
            .findFirst();
        _userRole = profile?.role;
      }
      if (mounted) setState(() {});
      await _fetchSuppliers();
      return;
    }

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final profile = await Supabase.instance.client
            .from('user_profiles')
            .select('role')
            .eq('id', user.id)
            .single();
        _userRole = profile['role'];
      }
    } catch (e, s) { debugPrint('[GestionFournisseurs] initRole error: $e\n$s'); }
    if (mounted) setState(() {});
    await _fetchSuppliers();
  }

  Future<void> _fetchSuppliers() async {
    setState(() => _isLoading = true);

    if (AppSession.isOfflineMode) {
      final isar = await IsarService.getInstance();
      final response = await isar.supplierLocals
          .filter()
          .isActiveEqualTo(true)
          .findAll();
          
      if (mounted) {
        setState(() {
          _suppliers = response.map((s) => {
            'id': s.supabaseId,
            'company_name': s.companyName,
            'contact_name': s.contactName,
            'phone': s.phone,
            'balance': s.balance,
            'is_active': s.isActive,
          }).toList();
          _applyFilters();
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final res = await Supabase.instance.client
          .from('suppliers')
          .select()
          .eq('is_active', true) 
          .order('company_name', ascending: true);
          
      if (mounted) {
        setState(() {
          _suppliers = res;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Error fetching suppliers: $e");
    }
  }

  void _applyFilters() {
    if (_showOnlyWithDebt) {
      _filteredSuppliers = _suppliers.where((s) => (s['balance'] as num? ?? 0) > 0).toList();
    } else {
      _filteredSuppliers = List.from(_suppliers);
    }
  }

  void _showAddEditDialog([Map<String, dynamic>? supplier]) {
    final isEdit = supplier != null;
    final nameCtrl = TextEditingController(text: supplier?['company_name'] ?? '');
    final contactCtrl = TextEditingController(text: supplier?['contact_name'] ?? '');
    final phoneCtrl = TextEditingController(text: supplier?['phone'] ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? S.t('supp_edit') : S.t('supp_add')),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: S.t('supp_company'), prefixIcon: const Icon(Icons.business), border: const OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? S.t('msg_required') : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: contactCtrl,
                decoration: InputDecoration(labelText: S.t('supp_contact'), prefixIcon: const Icon(Icons.person), border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneCtrl,
                decoration: InputDecoration(labelText: S.t('label_phone'), prefixIcon: const Icon(Icons.phone), border: const OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.t('action_cancel'))),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              try {
          
                final Map<String, dynamic> data = {
                  'company_name': nameCtrl.text.trim(),
                  'contact_name': contactCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                };
                
                if (isEdit) {
                  await Supabase.instance.client.from('suppliers').update(data).eq('id', supplier['id']);
                } else {
                
                  data['balance'] = 0;
                  data['is_active'] = true;
                  await Supabase.instance.client.from('suppliers').insert(data);
                }
                
                _fetchSuppliers();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(isEdit ? S.t('msg_updated') : S.t('msg_saved')),
                    backgroundColor: Color(0xFF4ADE80),
                  ));
                }
              } on PostgrestException catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.code == '42501' ? S.t('msg_access_denied') : '${S.t('msg_error')}: ${e.message}'), backgroundColor: Color(0xFFF87171)));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${S.t('msg_error')}: $e'), backgroundColor: Color(0xFFF87171)));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF58A6FF), foregroundColor: Color(0xFFEEEEFF)),
            child: Text(isEdit ? S.t('action_edit') : S.t('action_add')),
          ),
        ],
      ),
    );
  }

 
  Future<void> _deleteSupplier(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.t('supp_archive_title')),
        content: Text(S.t('supp_archive_msg')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.t('action_cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFF0A500), foregroundColor: Color(0xFFEEEEFF)),
            child: Text(S.t('action_archive')),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    try {
     
      await Supabase.instance.client.from('suppliers').update({'is_active': false}).eq('id', id);
      _fetchSuppliers();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.t('supp_archived')), backgroundColor: Color(0xFFF0A500)));
    } on PostgrestException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.code == '42501' ? S.t('msg_access_denied') : '${S.t('msg_error')}: ${e.message}'), backgroundColor: Color(0xFFF87171)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${S.t('msg_error')}: $e'), backgroundColor: Color(0xFFF87171)));
    }
  }

  
  void _openSupplierProfile(Map<String, dynamic> supplier) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => SupplierProfileScreen(supplier: supplier)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0A14),
      appBar: AppBar(
        title: Text(S.t('supp_title')),
        backgroundColor: Color(0xFF0F0F1C),
        foregroundColor: Color(0xFFEEEEFF),
        actions: [
          IconButton(
            icon: const Icon(Icons.compare_arrows),
            tooltip: S.t('supp_compare'),
            onPressed: () => SupplierComparisonSheet.show(context),
          ),
          Row(
            children: [
              Text(S.t('supp_with_debt'), style: const TextStyle(color: Color(0xFFEEEEFF))),
              Switch(
                value: _showOnlyWithDebt,
                activeColor: Color(0xFFF0A500),
                onChanged: (val) {
                  setState(() {
                    _showOnlyWithDebt = val;
                    _applyFilters();
                  });
                },
              ),
            ],
          ),
          if (_userRole == 'owner')
            IconButton(icon: const Icon(Icons.add), tooltip: S.t('action_add'), onPressed: () => _showAddEditDialog()),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredSuppliers.isEmpty
              ? Center(child: Text(_showOnlyWithDebt ? S.t('supp_no_debt') : S.t('supp_no_results'), style: const TextStyle(fontSize: 18, color: Color(0xFF9090A8))))
              : ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: _filteredSuppliers.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final s = _filteredSuppliers[index];
                    final double balance = (s['balance'] as num?)?.toDouble() ?? 0.0;
                    final bool hasDebt = balance > 0;

                    return Container(
                      decoration: BoxDecoration(
                        color: Color(0xFFEEEEFF),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Color(0xFF0A0A14).withOpacity(0.04), blurRadius: 8)],
                        border: BorderDirectional(start: BorderSide(color: hasDebt ? Color(0xFFF87171) : Color(0xFF4ADE80), width: 6)), // مؤشر بصري للديون
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        onTap: () => _openSupplierProfile(s), // فتح الملف التفصيلي
                        title: Text(s['company_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        subtitle: Text('${S.t('supp_contact_prefix')}${s['contact_name'] ?? '-'} • ${S.t('label_phone_short')}${s['phone'] ?? '-'}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                      
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(S.t('supp_debt_credit'), style: const TextStyle(fontSize: 12, color: Color(0xFF9090A8))),
                                Text(
                                  '${balance.toStringAsFixed(2)} ${S.t('misc_currency')}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: hasDebt ? Color(0xFFF87171) : Color(0xFF4ADE80),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 24),
                            if (_userRole == 'owner') ...[
                              IconButton(icon: const Icon(Icons.edit, color: Color(0xFFF0A500)), onPressed: () => _showAddEditDialog(s)),
                              IconButton(icon: const Icon(Icons.delete_outline, color: Color(0xFFF87171)), onPressed: () => _deleteSupplier(s['id'])),
                            ]
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// -----------------------------------------------------------------------------
// (Supplier Profile) بالتبويبات
// -----------------------------------------------------------------------------
class SupplierProfileScreen extends StatefulWidget {
  final Map<String, dynamic> supplier;
  const SupplierProfileScreen({super.key, required this.supplier});

  @override
  State<SupplierProfileScreen> createState() => _SupplierProfileScreenState();
}

class _SupplierProfileScreenState extends State<SupplierProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _invoices = [];
  List<dynamic> _payments = [];
  bool _isLoading = true;
  double _currentBalance = 0.0;

  String? _userRole;
  String? _userStoreId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentBalance = (widget.supplier['balance'] as num?)?.toDouble() ?? 0.0;
    _loadProfileAndFetch();
  }

  Future<void> _loadProfileAndFetch() async {
    if (AppSession.isOfflineMode) {
      final isar = await IsarService.getInstance();
      final userId = AppSession.currentUserId;
      if (userId != null) {
        final profile = await isar.userProfileLocals
            .filter()
            .supabaseIdEqualTo(userId)
            .findFirst();
        _userRole = profile?.role;
        _userStoreId = profile?.storeId;
      }
      _fetchProfileData();
      return;
    }

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final profile = await Supabase.instance.client
            .from('user_profiles')
            .select('role, store_id')
            .eq('id', user.id)
            .single();
        _userRole = profile['role'];
        _userStoreId = profile['store_id'];
      }
    } catch (e) {
      debugPrint("Error loading user profile: $e");
    }
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    setState(() => _isLoading = true);
    final supplierId = widget.supplier['id'];
    
    if (AppSession.isOfflineMode) {
      final isar = await IsarService.getInstance();
      
      final localInvoices = await isar.invoiceLocals
          .filter()
          .supplierIdEqualTo(supplierId)
          .typeEqualTo('in')
          .findAll();
          
      final localPayments = await isar.paymentLocals
          .filter()
          .supplierIdEqualTo(supplierId)
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
          'payment_date': p.createdAt?.toIso8601String(), // UI expects payment_date
          'notes': p.notes,
          'user_profiles': profile != null ? {'full_name': profile.fullName} : null,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _invoices = mappedInvoices;
          _payments = mappedPayments;
          _isLoading = false;
        });
      }
      final balRes = await Supabase.instance.client.rpc('get_supplier_balance', params: {'p_supplier_id': supplierId});
      if (mounted) {
        setState(() {
          _currentBalance = (balRes as num?)?.toDouble() ?? 0.0;
        });
      }
      return;
    }

    try {
      var invoicesQuery = Supabase.instance.client.from('invoices')
          .select('*, user_profiles(full_name)')
          .eq('supplier_id', supplierId)
          .eq('type', 'in');

      var paymentsQuery = Supabase.instance.client.from('payments')
          .select('*, user_profiles(full_name)')
          .eq('supplier_id', supplierId);

      // Employee: filter by store_id
      if (_userRole == 'employee' && _userStoreId != null) {
        invoicesQuery = invoicesQuery.eq('store_id', _userStoreId!);
        paymentsQuery = paymentsQuery.eq('store_id', _userStoreId!);
      }

      final invoicesRes = await invoicesQuery.order('created_at', ascending: false);
      final paymentsRes = await paymentsQuery.order('payment_date', ascending: false);

      if (mounted) {
        setState(() {
          _invoices = invoicesRes;
          _payments = paymentsRes;
          _isLoading = false;
        });
      }
      final balRes = await Supabase.instance.client.rpc('get_supplier_balance', params: {'p_supplier_id': supplierId});
      if (mounted) {
        setState(() {
          _currentBalance = (balRes as num?)?.toDouble() ?? 0.0;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Error fetching profile: $e");
    }
  }

  void _showAddPaymentDialog() {
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.t('supp_new_payment')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("${S.t('supp_current_debt')}${_currentBalance.toStringAsFixed(2)} ${S.t('misc_currency')}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF87171))),
            const SizedBox(height: 16),
            TextFormField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: S.t('supp_payment_amount'), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.euro)),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: notesCtrl,
              decoration: InputDecoration(labelText: S.t('supp_payment_notes'), border: const OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.t('action_cancel'))),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text);
              if (amount == null || amount <= 0) return;
              Navigator.pop(ctx);
              
              try {
                final user = Supabase.instance.client.auth.currentUser;
             
                await Supabase.instance.client.from('payments').insert({
                  'supplier_id': widget.supplier['id'],
                  'user_id': user?.id,
                  'amount': amount,
                  'payment_method': 'cash',
                  'notes': notesCtrl.text.isEmpty ? S.t('supp_manual_payment') : notesCtrl.text,
                });
                
                _fetchProfileData();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.t('supp_payment_recorded')), backgroundColor: Color(0xFF4ADE80)));
              } on PostgrestException catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.code == '42501' ? S.t('msg_access_denied') : '${S.t('msg_error')}: ${e.message}'), backgroundColor: Color(0xFFF87171)));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${S.t('msg_error')}: $e'), backgroundColor: Color(0xFFF87171)));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF58A6FF)),
            child: Text(S.t('debt_confirm_payment'), style: const TextStyle(color: Color(0xFFEEEEFF))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.supplier['company_name']),
        backgroundColor: Color(0xFF0F0F1C),
        foregroundColor: Color(0xFFEEEEFF),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Color(0xFFEEEEFF),
          unselectedLabelColor: Color(0xFF9090A8),
          indicatorColor: Color(0xFFF0A500),
          tabs: [
            Tab(icon: const Icon(Icons.receipt), text: S.t('supp_tabs_purchases')),
            Tab(icon: const Icon(Icons.payments), text: S.t('supp_tabs_payments')),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildInvoicesTab(),
                _buildPaymentsTab(),
              ],
            ),
      floatingActionButton: _userRole == 'owner' ? FloatingActionButton.extended(
        onPressed: _showAddPaymentDialog,
        backgroundColor: Color(0xFFF0A500),
        icon: const Icon(Icons.add, color: Color(0xFFEEEEFF)),
        label: Text(S.t('supp_make_payment'), style: const TextStyle(color: Color(0xFFEEEEFF), fontWeight: FontWeight.bold)),
      ) : null,
    );
  }

  Widget _buildInvoicesTab() {
    if (_invoices.isEmpty) return Center(child: Text(S.t('supp_no_invoices')));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _invoices.length,
      itemBuilder: (context, index) {
        final inv = _invoices[index];
        final total = (inv['total_amount'] as num?)?.toDouble() ?? 0;
        final paid = (inv['paid_amount'] as num?)?.toDouble() ?? 0;
        final date = DateTime.parse(inv['created_at']).toLocal();
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFF58A6FF), child: Icon(Icons.receipt, color: Color(0xFFEEEEFF))),
            title: Text(inv['invoice_number'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${date.day}/${date.month}/${date.year} • ${S.t('sales_sold_by')}: ${inv['user_profiles']['full_name']}"),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("${S.t('label_total')}: ${total.toStringAsFixed(2)} ${S.t('misc_currency')}", style: const TextStyle(fontWeight: FontWeight.bold)),
                Text("${S.t('pos_paid_status')}: ${paid.toStringAsFixed(2)} ${S.t('misc_currency')}", style: TextStyle(color: paid < total ? Color(0xFFF87171) : Color(0xFF4ADE80), fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentsTab() {
    if (_payments.isEmpty) return Center(child: Text(S.t('supp_no_payments')));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _payments.length,
      itemBuilder: (context, index) {
        final pay = _payments[index];
        final amount = (pay['amount'] as num?)?.toDouble() ?? 0;
        final date = DateTime.parse(pay['payment_date']).toLocal();
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFF4ADE80), child: Icon(Icons.monetization_on, color: Color(0xFFEEEEFF))),
            title: Text("${S.t('supp_payment_of')}${amount.toStringAsFixed(2)} ${S.t('misc_currency')}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4ADE80))),
            subtitle: Text("${date.day}/${date.month}/${date.year} • ${S.t('supp_reason')}${pay['notes']}"),
          ),
        );
      },
    );
  }
}