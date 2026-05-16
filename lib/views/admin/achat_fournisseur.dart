import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_strings.dart';

class AchatFournisseurScreen extends StatefulWidget {
  const AchatFournisseurScreen({super.key});

  @override
  State<AchatFournisseurScreen> createState() => _AchatFournisseurScreenState();
}

class _AchatFournisseurScreenState extends State<AchatFournisseurScreen> {
  List<dynamic> _suppliers = [];
  List<dynamic> _stores = [];
  List<dynamic> _variants = [];

  String? _selectedSupplierId;
  String? _selectedStoreId;
  String? _selectedVariantId;

  String? _userRole;
  String? _userStoreId;

  final _qtyController = TextEditingController();
  final _priceController = TextEditingController();

  final List<_PurchaseItem> _purchaseItems = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      // Fetch user role and store_id
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

      // جلب البيانات النشطة فقط (غير المحذوفة وهمياً)
      final results = await Future.wait([
        Supabase.instance.client.from('suppliers').select().eq('is_active', true),
        Supabase.instance.client.from('stores').select().eq('is_active', true),
        Supabase.instance.client.from('product_variants').select('id, size, color, barcode, buy_price, products(name)').eq('is_active', true),
      ]);
      
      if (mounted) {
        setState(() {
          _suppliers = results[0];
          _stores = results[1];
          _variants = results[2];
          
          if (_suppliers.isNotEmpty) _selectedSupplierId = _suppliers.first['id'];
          // Employee: lock to their store; Owner: default to first store
          if (_userRole == 'employee' && _userStoreId != null) {
            _selectedStoreId = _userStoreId;
          } else if (_stores.isNotEmpty) {
            _selectedStoreId = _stores.first['id'];
          }
          if (_variants.isNotEmpty) _selectedVariantId = _variants.first['id'];
          
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addItemToList() {
    if (_selectedVariantId == null || _selectedStoreId == null) return;
    final qty = int.tryParse(_qtyController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0;
    
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.t('buy_qty_invalid')), backgroundColor: Colors.red),
      );
      return;
    }

    // البحث عن اسم المنتج ومقاسه
    final variant = _variants.firstWhere((v) => v['id'] == _selectedVariantId);
    final productName = variant['products']['name'];
    final label = '$productName (${variant['size']} / ${variant['color']})';

    setState(() {
      _purchaseItems.add(_PurchaseItem(
        variantId: _selectedVariantId!,
        label: label,
        quantity: qty,
        unitPrice: price,
      ));
      _qtyController.clear();
      _priceController.clear();
    });
  }

  // نافذة تأكيد الدفع قبل إرسال البيانات لقاعدة البيانات
  void _showPaymentDialog() {
    if (_purchaseItems.isEmpty || _selectedStoreId == null || _selectedSupplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.t('buy_fill_fields')), backgroundColor: Colors.orange),
      );
      return;
    }

    final totalAmount = _purchaseItems.fold<double>(0, (s, i) => s + i.quantity * i.unitPrice);
    final paymentController = TextEditingController(text: totalAmount.toStringAsFixed(2));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.account_balance_wallet, color: Colors.deepPurple),
              const SizedBox(width: 8),
              Text(S.t('buy_validation_title')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.deepPurple[50], borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(S.t('buy_total_invoice'), style: const TextStyle(fontSize: 16)),
                    Text('${totalAmount.toStringAsFixed(2)} ${S.t('misc_currency')}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: paymentController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: S.t('buy_amount_paid'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.payments_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                S.t('buy_payment_note'),
                style: const TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(S.t('action_cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                final paid = double.tryParse(paymentController.text) ?? 0;
                Navigator.pop(context); // إغلاق النافذة
                _processPurchaseTransaction(totalAmount, paid); // تنفيذ العملية
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
              child: Text(S.t('buy_confirm')),
            ),
          ],
        );
      }
    );
  }

 
  Future<void> _processPurchaseTransaction(double totalAmount, double paidAmount) async {
    setState(() => _isSubmitting = true);
    
    try {
      final invoiceNumber = 'ACH-${DateTime.now().millisecondsSinceEpoch}';

      await Supabase.instance.client.rpc('process_purchase', params: {
        'p_store_id': _selectedStoreId,
        'p_supplier_id': _selectedSupplierId,
        'p_invoice_number': invoiceNumber,
        'p_items': _purchaseItems.map((item) => {
          'variant_id': item.variantId,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'total_price': item.unitPrice * item.quantity,
        }).toList(),
        'p_total_amount': totalAmount,
        'p_paid_amount': paidAmount,
        'p_payment_method': 'cash',
        'p_notes': 'Paiement à la création de la facture $invoiceNumber',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(S.t('buy_success')),
          backgroundColor: Colors.green,
        ));
        setState(() {
          _purchaseItems.clear();
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${S.t('msg_error')}: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(S.t('buy_title')),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- LEFT: FORMULAR ---
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(S.t('buy_add_items'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                          const SizedBox(height: 24),

                          // Supplier
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _selectedSupplierId,
                            decoration: InputDecoration(labelText: S.t('suppliers_title'), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.local_shipping)),
                            items: _suppliers.map<DropdownMenuItem<String>>((s) {
                              return DropdownMenuItem(value: s['id'], child: Text(s['company_name']));
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedSupplierId = val),
                          ),
                          const SizedBox(height: 16),

                          // Store
                          if (_userRole == 'employee')
                            TextFormField(
                              readOnly: true,
                              decoration: InputDecoration(labelText: S.t('buy_store_receiving'), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.store)),
                              initialValue: _stores.where((s) => s['id'] == _userStoreId).isNotEmpty
                                  ? _stores.firstWhere((s) => s['id'] == _userStoreId)['name']
                                  : S.t('buy_my_store'),
                            )
                          else
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _selectedStoreId,
                              decoration: InputDecoration(labelText: S.t('buy_store_receiving'), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.store)),
                              items: _stores.map<DropdownMenuItem<String>>((s) {
                                return DropdownMenuItem(value: s['id'], child: Text(s['name']));
                              }).toList(),
                              onChanged: (val) => setState(() => _selectedStoreId = val),
                            ),
                          const SizedBox(height: 16),

                          // Variant
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _selectedVariantId,
                            decoration: InputDecoration(labelText: S.t('buy_product_variant'), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.category)),
                            items: _variants.map<DropdownMenuItem<String>>((v) {
                              final name = v['products']['name'];
                              return DropdownMenuItem(
                                value: v['id'],
                                child: Text('$name (${v['size']} / ${v['color']})'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedVariantId = val;
                                if (val != null) {
                                  final v = _variants.firstWhere((x) => x['id'] == val, orElse: () => null);
                                  if (v != null && v['buy_price'] != null) {
                                    _priceController.text = v['buy_price'].toString();
                                  }
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 16),

                          // Quantity & Price
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _qtyController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(labelText: S.t('label_quantity'), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.numbers)),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _priceController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(labelText: '${S.t('label_unit_price')} (${S.t('misc_currency')})', border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.attach_money)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          ElevatedButton.icon(
                            onPressed: _addItemToList,
                            icon: const Icon(Icons.add),
                            label: Text(S.t('action_add_to_list')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple[50],
                              foregroundColor: Colors.deepPurple,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),

                  // --- RIGHT: RECEIPT ---
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.receipt_long, color: Colors.deepPurple),
                              const SizedBox(width: 12),
                              Expanded(child: Text(S.t('buy_receipt'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurple))),
                              Chip(label: Text('${_purchaseItems.length} ${S.t('buy_items')}'), backgroundColor: Colors.deepPurple[50]),
                            ],
                          ),
                          const Divider(height: 32),

                          if (_purchaseItems.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 48),
                              child: Center(child: Text(S.t('buy_no_items'), style: const TextStyle(color: Colors.grey, fontSize: 16))),
                            )
                          else
                            ..._purchaseItems.asMap().entries.map((entry) {
                              final i = entry.key;
                              final item = entry.value;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.deepPurple[50],
                                    child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                                  ),
                                  title: Text(item.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('${S.t('label_qty_short')} ${item.quantity} × ${item.unitPrice.toStringAsFixed(2)} ${S.t('misc_currency')} = ${(item.quantity * item.unitPrice).toStringAsFixed(2)} ${S.t('misc_currency')}'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.close, color: Colors.red),
                                    onPressed: () => setState(() => _purchaseItems.removeAt(i)),
                                  ),
                                ),
                              );
                            }),

                          if (_purchaseItems.isNotEmpty) ...[
                            const Divider(height: 32),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(S.t('label_total'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                Text(
                                  '${_purchaseItems.fold<double>(0, (s, i) => s + i.quantity * i.unitPrice).toStringAsFixed(2)} ${S.t('misc_currency')}',
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 56,
                              child: ElevatedButton.icon(
                                onPressed: _isSubmitting ? null : _showPaymentDialog, // استدعاء نافذة الدفع
                                icon: _isSubmitting
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Icon(Icons.check_circle),
                                label: Text(S.t('buy_validate_pay'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _PurchaseItem {
  final String variantId;
  final String label;
  final int quantity;
  final double unitPrice;

  _PurchaseItem({
    required this.variantId,
    required this.label,
    required this.quantity,
    required this.unitPrice,
  });
}