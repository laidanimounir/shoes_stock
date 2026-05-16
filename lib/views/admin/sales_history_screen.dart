import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../desktop/refund_modal.dart';
import '../../core/app_strings.dart';
import '../../core/app_session.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final supabase = Supabase.instance.client;
  List<dynamic> _sales = [];
  List<dynamic> _stores = [];
  bool _isLoading = true;
  
  String? _userStoreId;
  String? _filterStoreId; 

  @override
  void initState() {
    super.initState();
    _initAndFetch();
  }

  Future<void> _initAndFetch() async {
    try {
      final user = supabase.auth.currentUser;
      _userStoreId = AppSession.currentStoreId;

      if (AppSession.isOwner) {
        _stores = await supabase.from('stores').select('id, name').order('name');
      } else {
        _filterStoreId = _userStoreId; 
      }
      await _fetchSales();
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> _fetchSales() async {
    setState(() => _isLoading = true);
    try {
    
      var query = supabase.from('transactions').select('''
        id, invoice_number, invoice_id, quantity, total_price, created_at, type,
        product_variants(id, products(name), size, color),
        customers(full_name),
        stores(name),
        invoices(status)
      ''').eq('type', 'out'); 

      if (_filterStoreId != null) {
        query = query.eq('store_id', _filterStoreId!);
      }

      final res = await query.order('created_at', ascending: false);
      setState(() {
        _sales = res;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  Widget _buildStatusBadge(String? status) {
    if (status == 'refunded') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade400),
        ),
        child: Text(
          S.t('label_refunded_badge'),
          style: TextStyle(
            color: Colors.red.shade700,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    if (status == 'paid') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade400),
        ),
        child: Text(
          S.t('label_paid_badge'),
          style: TextStyle(
            color: Colors.green.shade700,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(S.t('nav_sales')),
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
        actions: [
          if (AppSession.isOwner)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DropdownButton<String?>(
                dropdownColor: Colors.indigo[800],
                style: const TextStyle(color: Colors.white),
                underline: const SizedBox(),
                value: _filterStoreId,
                hint: Text(S.t('label_all_stores'), style: const TextStyle(color: Colors.white70)),
                items: [
                  DropdownMenuItem(value: null, child: Text(S.t('label_all_stores'))),
                  ..._stores.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name'] as String))),
                ],
                onChanged: (val) {
                  setState(() => _filterStoreId = val);
                  _fetchSales();
                },
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sales.isEmpty
              ? Center(child: Text(S.t('label_no_data')))
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: _sales.length,
                  itemBuilder: (context, index) {
                    final s = _sales[index];
                    final status = s['invoices']?['status'] as String?;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const Icon(Icons.receipt, color: Colors.indigo),
                        title: Row(
                          children: [
                            Expanded(child: Text("${s['product_variants']['products']['name']} (${s['product_variants']['size']})")),
                            const SizedBox(width: 8),
                            _buildStatusBadge(status),
                          ],
                        ),
                        subtitle: Text(
                          "${S.t('label_invoice')}: ${s['invoice_number']}\n"
                          "${S.t('label_client')}: ${s['customers']?['full_name'] ?? S.t('label_guest')} | ${S.t('label_store')}: ${s['stores']['name']}",
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "${s['total_price']} ${S.t('misc_currency')}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                decoration: status == 'refunded' ? TextDecoration.lineThrough : TextDecoration.none,
                                color: status == 'refunded' ? Colors.red.shade400 : Colors.black87,
                              ),
                            ),
                            if (status == 'paid') ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.assignment_return, color: Colors.red),
                                tooltip: S.t('label_return'),
                                onPressed: () async {
                                  final createdAtStr = s['created_at'] as String?;
                                  if (createdAtStr == null) return;
                                  final createdAt = DateTime.parse(createdAtStr);
                                  final hoursSince = DateTime.now().difference(createdAt).inHours;

                                  if (hoursSince > 48) {
                                    if (AppSession.isOwner) {
                                      final proceed = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: Text(S.t('refund_48h_warning_title')),
                                          content: Text(S.t('refund_48h_warning_body')),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, false),
                                              child: Text(S.t('action_cancel')),
                                            ),
                                            ElevatedButton(
                                              onPressed: () => Navigator.pop(ctx, true),
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                                              child: Text(S.t('refund_48h_continue')),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (proceed != true) return;
                                    } else {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(S.t('refund_48h_blocked')), backgroundColor: Colors.red),
                                        );
                                      }
                                      return;
                                    }
                                  }

                                  final result = await showDialog(
                                    context: context,
                                    builder: (_) => RefundModal(
                                      invoice: s,
                                      isOwner: AppSession.isOwner,
                                    ),
                                  );
                                  if (result == true) {
                                    _fetchSales();
                                  }
                                },
                              ),
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