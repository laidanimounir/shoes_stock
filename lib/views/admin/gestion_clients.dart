import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:isar/isar.dart';
import '../../core/app_session.dart';
import '../../local_db/isar_service.dart';
import '../../local_db/collections/customer_local.dart';
import '../../local_db/collections/invoice_local.dart';
import '../../local_db/collections/payment_local.dart';
import '../../local_db/collections/user_profile_local.dart';
import '../../core/app_strings.dart';

class GestionClientsScreen extends StatefulWidget {
  const GestionClientsScreen({super.key});

  @override
  State<GestionClientsScreen> createState() => _GestionClientsScreenState();
}

class _GestionClientsScreenState extends State<GestionClientsScreen> with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  
  List<dynamic> _customers = [];
  bool _isLoading = true;
  bool _showOnlyWithDebt = false; // فلتر الديون
  
  Map<String, dynamic>? _selectedCustomer;
  late TabController _tabController;
  
  // بيانات الملف التفصيلي
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
          .eq('is_active', true); // Soft Delete filter
      
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

  // تحديث استعلام التاريخ لجلب الفواتير والمدفوعات الفعلية
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
          
          // Recompute balance locally if needed
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

      // Employee: filter by store_id
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

          if (AppSession.isEmployee && AppSession.currentStoreId != null) {
            // Employee: compute balance from filtered invoices/payments
            double totalInvoiced = 0.0;
            for (var inv in _invoices) {
              totalInvoiced += (inv['total_amount'] as num?)?.toDouble() ?? 0.0;
            }
            double totalPaid = 0.0;
            for (var pay in _payments) {
              totalPaid += (pay['amount'] as num?)?.toDouble() ?? 0.0;
            }
            _currentBalance = totalInvoiced - totalPaid;
          } else {
            // Owner: read global balance from DB (unchanged behavior)
            _fetchGlobalBalance(customerId);
          }

          if (_selectedCustomer != null) {
            _selectedCustomer!['balance'] = _currentBalance;
          }
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingHistory = false);
      debugPrint("Error fetching history: $e");
    }
  }

  Future<void> _fetchGlobalBalance(String customerId) async {
    if (AppSession.isOfflineMode) {
      final isar = await IsarService.getInstance();
      final customer = await isar.customerLocals
          .filter()
          .supabaseIdEqualTo(customerId)
          .findFirst();
      if (customer != null && mounted) {
        setState(() {
          _currentBalance = customer.balance;
          if (_selectedCustomer != null) {
            _selectedCustomer!['balance'] = _currentBalance;
          }
        });
      }
      return;
    }

    try {
      final balanceRes = await Supabase.instance.client
          .from('customers')
          .select('balance')
          .eq('id', customerId)
          .single();
      if (mounted) {
        setState(() {
          _currentBalance = (balanceRes['balance'] as num?)?.toDouble() ?? 0.0;
          if (_selectedCustomer != null) {
            _selectedCustomer!['balance'] = _currentBalance;
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching global balance: $e");
    }
  }

  void _showAddEditCustomerDialog([Map<String, dynamic>? customer]) {
    final isEdit = customer != null;
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: customer?['full_name'] ?? '');
    final phoneCtrl = TextEditingController(text: customer?['phone'] ?? '');
    final emailCtrl = TextEditingController(text: customer?['email'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? S.t('cust_edit') : S.t('cust_add')),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: S.t('cust_full_name'), prefixIcon: const Icon(Icons.person), border: const OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? S.t('msg_required') : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneCtrl,
                decoration: InputDecoration(labelText: S.t('cust_phone'), prefixIcon: const Icon(Icons.phone), border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailCtrl,
                decoration: InputDecoration(labelText: S.t('cust_email'), prefixIcon: const Icon(Icons.email), border: const OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(S.t('action_cancel'))),
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
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.t('msg_access_denied')), backgroundColor: Colors.red));
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

                  // Log activity for new customer
                  try {
                    await Supabase.instance.client.from('activity_logs').insert({
                      'user_id': AppSession.currentUserId,
                      'action_type': 'add_customer',
                      'description': 'Nouveau client ajouté: ${data['full_name']}',
                      'store_id': AppSession.currentStoreId,
                    });
                  } catch (_) {}
                }
                
                _fetchCustomers(_searchController.text);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(isEdit ? 'Client modifié.' : 'Client ajouté.'),
                    backgroundColor: Colors.green,
                  ));
                }
              } on PostgrestException catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.code == '42501' ? 'Accès refusé : Autorisations insuffisantes' : 'Erreur: ${e.message}'), backgroundColor: Colors.red));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
            child: Text(isEdit ? 'Modifier' : 'Enregistrer'),
          ),
        ],
      ),
    );
  }

  // الإخفاء الآمن
  Future<void> _deleteCustomer(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.t('cust_archive_title')),
        content: Text(S.t('cust_archive_msg')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.t('action_cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.t('cust_archived')), backgroundColor: Colors.orange));
    } on PostgrestException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.code == '42501' ? S.t('msg_access_denied') : '${S.t('msg_error')}: ${e.message}'), backgroundColor: Colors.red));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${S.t('msg_error')}: $e'), backgroundColor: Colors.red));
    }
  }

  void _selectCustomer(Map<String, dynamic> customer) {
    setState(() {
      _selectedCustomer = customer;
    });
    _fetchCustomerHistory(customer['id']);
  }

  // تسجيل دفعة (استلام أموال من الزبون)
  void _showAddPaymentDialog() {
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.t('cust_receive_payment')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("${S.t('pos_credit')}: ${_currentBalance.toStringAsFixed(2)} ${S.t('misc_currency')}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 16),
            TextFormField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: S.t('cust_payment_amount'), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.euro)),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: notesCtrl,
              decoration: InputDecoration(labelText: S.t('cust_payment_notes'), border: const OutlineInputBorder()),
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
                  'customer_id': _selectedCustomer!['id'],
                  'user_id': user?.id,
                  'amount': amount,
                  'payment_method': 'cash',
                  'notes': notesCtrl.text.isEmpty ? S.t('cust_manual_payment') : notesCtrl.text,
                });

                // Log activity
                try {
                  await Supabase.instance.client.from('activity_logs').insert({
                    'user_id': AppSession.currentUserId,
                    'action_type': 'debt_payment',
                    'description': 'Paiement reçu de ${_selectedCustomer!['full_name']} — ${amount.toStringAsFixed(2)} DA',
                    'store_id': AppSession.currentStoreId,
                  });
                } catch (_) {}
                
                _fetchCustomerHistory(_selectedCustomer!['id']); // التحديث الآلي
                _fetchCustomers(_searchController.text); // لتحديث القائمة الجانبية
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.t('msg_payment_recorded')), backgroundColor: Colors.green));
              } on PostgrestException catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.code == '42501' ? S.t('msg_access_denied') : '${S.t('msg_error')}: ${e.message}'), backgroundColor: Colors.red));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${S.t('msg_error')}: $e'), backgroundColor: Colors.red));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            child: Text(S.t('action_confirm'), style: const TextStyle(color: Colors.white)),
          ),
        ],
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(S.t('cust_title_full')),
        backgroundColor: Colors.indigo[800],
        foregroundColor: Colors.white,
      ),
      body: Row(
        children: [
          // --- LEFT PANEL: LISTE DES CLIENTS ---
          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: S.t('cust_search_hint'),
                                  prefixIcon: const Icon(Icons.search),
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onChanged: (val) => _fetchCustomers(val),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => _showAddEditCustomerDialog(),
                              icon: const Icon(Icons.person_add_alt_1),
                              color: Colors.indigo,
                              tooltip: S.t('cust_add_tooltip'),
                            )
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(S.t('cust_with_debt'), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            Switch(
                              value: _showOnlyWithDebt,
                              activeColor: Colors.orange,
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
                  const Divider(height: 1),
                  Expanded(
                    child: _isLoading 
                      ? const Center(child: CircularProgressIndicator())
                      : _customers.isEmpty 
                        ? Center(child: Text(S.t('cust_no_results'), style: const TextStyle(color: Colors.grey)))
                        : ListView.separated(
                          itemCount: _customers.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final c = _customers[index];
                            final isSelected = _selectedCustomer?['id'] == c['id'];
                            final balance = (c['balance'] as num?)?.toDouble() ?? 0.0;
                            final hasDebt = balance > 0;
                            
                            return ListTile(
                              selected: isSelected,
                              selectedTileColor: Colors.indigo.withOpacity(0.1),
                              leading: CircleAvatar(
                                backgroundColor: isSelected ? Colors.indigo : Colors.grey[200],
                                child: Icon(Icons.person, color: isSelected ? Colors.white : Colors.grey[700]),
                              ),
                              title: Text(c['full_name'] ?? S.t('misc_unknown'), style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(c['phone'] ?? c['email'] ?? S.t('misc_no_phone')),
                              trailing: hasDebt 
                                  ? Text('${balance.toStringAsFixed(2)} ${S.t('misc_currency')}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                                  : const Icon(Icons.check_circle, color: Colors.green, size: 16),
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
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
              child: _selectedCustomer == null
                  ? Center(child: Text(S.t('cust_no_client_selected'), style: const TextStyle(color: Colors.grey, fontSize: 18)))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // HEADER DU CLIENT
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.indigo.withOpacity(0.05),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_selectedCustomer!['full_name'], style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.indigo)),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.phone, size: 16, color: Colors.grey),
                                        const SizedBox(width: 8),
                                        Text(_selectedCustomer!['phone'] ?? 'Non renseigné'),
                                        const SizedBox(width: 24),
                                        const Icon(Icons.email, size: 16, color: Colors.grey),
                                        const SizedBox(width: 8),
                                        Text(_selectedCustomer!['email'] ?? 'Non renseigné'),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text("Crédit (Dette)", style: TextStyle(color: Colors.grey)),
                                  Text(
                                    '${_currentBalance.toStringAsFixed(2)} DA',
                                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _currentBalance > 0 ? Colors.red : Colors.green),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      if (AppSession.isOwner) ...[
                                        IconButton(icon: const Icon(Icons.edit, color: Colors.orange, size: 20), onPressed: () => _showAddEditCustomerDialog(_selectedCustomer)),
                                        IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _deleteCustomer(_selectedCustomer!['id'])),
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
                          labelColor: Colors.indigo,
                          indicatorColor: Colors.indigo,
                          tabs: [
                            Tab(icon: const Icon(Icons.shopping_bag), text: S.t('cust_tabs_invoices')),
                            Tab(icon: const Icon(Icons.account_balance_wallet), text: S.t('cust_tabs_payments')),
                          ],
                        ),
                        
                        // CONTENU DES ONGLETS
                        Expanded(
                          child: _isLoadingHistory
                              ? const Center(child: CircularProgressIndicator())
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
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
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
    if (_invoices.isEmpty) return Center(child: Text(S.t('cust_no_purchases')));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _invoices.length,
      itemBuilder: (context, index) {
        final inv = _invoices[index];
        final total = (inv['total_amount'] as num?)?.toDouble() ?? 0;
        final paid = (inv['paid_amount'] as num?)?.toDouble() ?? 0;
        final date = DateTime.parse(inv['created_at']).toLocal();
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade200)),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: Colors.indigo[50], child: const Icon(Icons.shopping_bag, color: Colors.indigo)),
            title: Text(inv['invoice_number'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${date.day}/${date.month}/${date.year} • ${S.t('sales_sold_by')}: ${inv['user_profiles']['full_name']}"),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("${S.t('label_total')}: ${total.toStringAsFixed(2)} ${S.t('misc_currency')}", style: const TextStyle(fontWeight: FontWeight.bold)),
                Text("${S.t('pos_paid_status')}: ${paid.toStringAsFixed(2)} ${S.t('misc_currency')}", style: TextStyle(color: paid < total ? Colors.red : Colors.green, fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentsTab() {
    if (_payments.isEmpty) return Center(child: Text(S.t('cust_no_payments')));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _payments.length,
      itemBuilder: (context, index) {
        final pay = _payments[index];
        final amount = (pay['amount'] as num?)?.toDouble() ?? 0;
        final date = DateTime.parse(pay['payment_date']).toLocal();
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade200)),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: Colors.green[50], child: const Icon(Icons.check_circle, color: Colors.green)),
            title: Text("${S.t('cust_payment_of')} ${amount.toStringAsFixed(2)} ${S.t('misc_currency')}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            subtitle: Text("${date.day}/${date.month}/${date.year} • ${S.t('label_notes')}: ${pay['notes']}"),
          ),
        );
      },
    );
  }
}