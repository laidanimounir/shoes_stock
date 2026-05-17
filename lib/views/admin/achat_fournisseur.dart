import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_strings.dart';
import '../../core/app_session.dart';

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

  final _qtyController = TextEditingController();
  final _priceController = TextEditingController();

  final List<_PurchaseItem> _purchaseItems = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  // Smart selection state
  List<Map<String, dynamic>> _purchaseHistory = [];
  int _currentStock = 0;
  double? _lastPurchasePrice;
  DateTime? _lastPurchaseDate;
  bool _isLoadingHistory = false;

  // Unit type state
  String _unitType = 'piece';
  int _unitsPerCarton = 1;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
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
          if (_stores.isNotEmpty) {
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
    final inputQty = int.tryParse(_qtyController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0;
    
    if (inputQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.t('buy_qty_invalid')), backgroundColor: Colors.red),
      );
      return;
    }

    // البحث عن اسم المنتج ومقاسه
    final variant = _variants.firstWhere((v) => v['id'] == _selectedVariantId);
    final productName = variant['products']['name'];
    final effectiveQty = _unitType == 'carton' ? inputQty * _unitsPerCarton : inputQty;
    final label = _unitType == 'carton'
        ? '$productName (${variant['size']} / ${variant['color']}) [$inputQty cartons × $_unitsPerCarton pcs]'
        : '$productName (${variant['size']} / ${variant['color']})';

    setState(() {
      _purchaseItems.add(_PurchaseItem(
        variantId: _selectedVariantId!,
        label: label,
        quantity: effectiveQty,
        unitPrice: price,
      ));
      _qtyController.clear();
      _priceController.clear();
    });
  }

  // نافذة تأكيد الدفع قبل إرسال البيانات لقاعدة البيانات
  void _showPaymentDialog() {
    if (AppSession.isEmployee) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.t('buy_no_permission')), backgroundColor: Colors.red),
      );
      return;
    }
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

  // ========== SMART SELECTION ==========

  Future<List<Map<String, dynamic>>> _fetchPurchaseHistory(String variantId) async {
    try {
      final response = await Supabase.instance.client
          .from('transactions')
          .select('created_at, quantity, unit_price')
          .eq('variant_id', variantId)
          .eq('type', 'in')
          .order('created_at', ascending: false)
          .limit(3);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<int> _fetchVariantStock(String variantId, String storeId) async {
    try {
      final response = await Supabase.instance.client
          .from('inventory')
          .select('quantity')
          .eq('variant_id', variantId)
          .eq('store_id', storeId)
          .maybeSingle();
      return response?['quantity'] as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<void> _loadVariantSmartInfo(dynamic selectedVariant) async {
    setState(() => _isLoadingHistory = true);
    try {
      final vid = selectedVariant['id']?.toString() ?? '';
      final sid = _selectedStoreId ?? '';
      final results = await Future.wait([
        _fetchPurchaseHistory(vid),
        _fetchVariantStock(vid, sid),
      ]);
      final history = results[0] as List<Map<String, dynamic>>;
      final stock = results[1] as int;
      if (mounted) {
        setState(() {
          _purchaseHistory = history;
          _currentStock = stock;
          _isLoadingHistory = false;
          if (history.isNotEmpty) {
            _lastPurchasePrice = (history.first['unit_price'] as num?)?.toDouble();
            _lastPurchaseDate = DateTime.tryParse(history.first['created_at']?.toString() ?? '');
          } else {
            _lastPurchasePrice = null;
            _lastPurchaseDate = null;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  void _clearSmartInfo() {
    setState(() {
      _purchaseHistory = [];
      _currentStock = 0;
      _lastPurchasePrice = null;
      _lastPurchaseDate = null;
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Widget _buildSmartInfoCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: const Color(0xFF1B4F72).withOpacity(0.3)),
      ),
      color: const Color(0xFF1B4F72).withOpacity(0.04),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: _isLoadingHistory
          ? const Center(child: SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1B4F72))))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.inventory_2_outlined, size: 16, color: Color(0xFF1B4F72)),
                  const SizedBox(width: 6),
                  Text('Stock actuel: ',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _currentStock > 5 ? const Color(0xFF2ECC71)
                           : _currentStock > 0 ? const Color(0xFFE67E22)
                           : _currentStock == 0 ? const Color(0xFFE74C3C)
                           : const Color(0xFF7B0000),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('$_currentStock pcs',
                      style: GoogleFonts.raleway(
                        color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ]),
                if (_lastPurchasePrice != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(children: [
                      const Icon(Icons.history_outlined, size: 16, color: Color(0xFF6B7C93)),
                      const SizedBox(width: 6),
                      Text('Dernier achat: ',
                        style: GoogleFonts.cairo(fontSize: 13, color: Color(0xFF6B7C93))),
                      Text('${_lastPurchasePrice!.toStringAsFixed(2)} DA',
                        style: GoogleFonts.raleway(
                          fontWeight: FontWeight.bold, fontSize: 13,
                          color: const Color(0xFF1B4F72))),
                      if (_lastPurchaseDate != null) ...[
                        const SizedBox(width: 8),
                        Text('le ${_formatDate(_lastPurchaseDate!)}',
                          style: GoogleFonts.raleway(fontSize: 11, color: Color(0xFF6B7C93))),
                      ],
                    ]),
                  ),
                _buildPriceComparisonRow(),
              ],
            ),
      ),
    );
  }

  Widget _buildPriceComparisonRow() {
    final currentPrice = double.tryParse(_priceController.text);
    if (currentPrice == null || _lastPurchasePrice == null) {
      return const SizedBox.shrink();
    }
    final diff = currentPrice - _lastPurchasePrice!;
    final pct = (diff / _lastPurchasePrice!) * 100;
    if (diff == 0) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(children: [
          const Icon(Icons.check_circle, size: 16, color: Color(0xFF2ECC71)),
          const SizedBox(width: 6),
          Text('Prix identique au dernier achat',
            style: GoogleFonts.cairo(fontSize: 12, color: Color(0xFF2ECC71))),
        ]),
      );
    }
    final isHigher = diff > 0;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        Icon(isHigher ? Icons.warning_amber_rounded : Icons.info_outline,
          size: 16, color: isHigher ? const Color(0xFFE67E22) : const Color(0xFF1B4F72)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(isHigher
            ? 'Prix supérieur de ${diff.toStringAsFixed(2)} DA (+${pct.toStringAsFixed(1)}%)'
            : 'Prix inférieur de ${(-diff).toStringAsFixed(2)} DA (${pct.toStringAsFixed(1)}%)',
            style: GoogleFonts.cairo(fontSize: 12,
              color: isHigher ? const Color(0xFFE67E22) : const Color(0xFF1B4F72))),
        ),
      ]),
    );
  }

  Widget _buildPurchaseHistoryTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('📊 Historique des achats',
          style: GoogleFonts.cairo(
            fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6B7C93))),
        const SizedBox(height: 6),
        ..._purchaseHistory.map((h) {
          final date = DateTime.tryParse(h['created_at'] ?? '');
          final qty = h['quantity'] ?? 0;
          final price = h['unit_price'] ?? 0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              const Icon(Icons.circle, size: 6, color: Color(0xFF1B4F72)),
              const SizedBox(width: 8),
              Text(date != null ? _formatDate(date) : '—',
                style: GoogleFonts.raleway(fontSize: 12, color: Color(0xFF6B7C93))),
              const Spacer(),
              Text('$qty pcs', style: GoogleFonts.raleway(fontSize: 12)),
              const SizedBox(width: 16),
              Text('$price DA',
                style: GoogleFonts.raleway(fontSize: 12,
                  fontWeight: FontWeight.bold, color: Color(0xFF1B4F72))),
            ]),
          );
        }),
      ],
    );
  }

  Widget _unitTypeToggle(String type, String label) {
    final isSelected = _unitType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _unitType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1B4F72) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF1B4F72) : const Color(0xFFE0E6ED),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isSelected ? Colors.white : const Color(0xFF6B7C93))),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1B4F72), size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: const Color(0xFF1B4F72),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Container(height: 1, color: const Color(0xFFE0E6ED))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const kPrimary = Color(0xFF1B4F72);
    const kTextSec = Color(0xFF6B7C93);
    const kBorder = Color(0xFFE0E6ED);

    InputDecoration formStyle(String label, IconData icon) {
      return InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.raleway(color: kTextSec),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kPrimary, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        prefixIcon: Icon(icon, color: kTextSec),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: kPrimary,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text(
              'Achat / Approvisionnement',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          if (AppSession.isEmployee)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: kPrimary.withOpacity(0.08),
              child: Row(
                children: [
                  const Icon(Icons.visibility, size: 16, color: kPrimary),
                  const SizedBox(width: 8),
                  Text(S.t('buy_read_only'), style: const TextStyle(color: kPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- LEFT: FORM ---
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _sectionHeader('Fournisseur', Icons.local_shipping_outlined),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _selectedSupplierId,
                            decoration: formStyle(S.t('suppliers_title'), Icons.local_shipping_outlined),
                            items: _suppliers.map<DropdownMenuItem<String>>((s) {
                              return DropdownMenuItem(value: s['id'], child: Text(s['company_name']));
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedSupplierId = val),
                          ),
                          const SizedBox(height: 16),
                          _sectionHeader('Magasin de réception', Icons.store_outlined),
                          if (AppSession.isEmployee)
                            TextFormField(
                              readOnly: true,
                              decoration: formStyle(S.t('buy_store_receiving'), Icons.store_outlined),
                              initialValue: AppSession.currentStoreId != null && _stores.any((s) => s['id'] == AppSession.currentStoreId)
                                  ? (_stores.firstWhere((s) => s['id'] == AppSession.currentStoreId)['name'] as String)
                                  : S.t('buy_my_store'),
                            )
                          else
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _selectedStoreId,
                              decoration: formStyle(S.t('buy_store_receiving'), Icons.store_outlined),
                              items: _stores.map<DropdownMenuItem<String>>((s) {
                                return DropdownMenuItem(value: s['id'], child: Text(s['name']));
                              }).toList(),
                              onChanged: (val) => setState(() => _selectedStoreId = val),
                            ),
                          const SizedBox(height: 16),
                          _sectionHeader('Produit & Variante', Icons.inventory_2_outlined),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _selectedVariantId,
                            decoration: formStyle(S.t('buy_product_variant'), Icons.inventory_2_outlined),
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
                              });
                              if (val != null) {
                                final v = _variants.firstWhere((x) => x['id'] == val, orElse: () => null);
                                if (v != null) {
                                  if (v['buy_price'] != null) {
                                    _priceController.text = v['buy_price'].toString();
                                  }
                                  _loadVariantSmartInfo(v);
                                }
                              } else {
                                _clearSmartInfo();
                              }
                            },
                          ),
                          if (_selectedVariantId != null) ...[
                            _buildSmartInfoCard(),
                            const SizedBox(height: 8),
                            if (_purchaseHistory.isNotEmpty)
                              _buildPurchaseHistoryTable(),
                            const SizedBox(height: 16),
                          ] else
                            const SizedBox(height: 16),
                          _sectionHeader('Quantité & Prix', Icons.calculate_outlined),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _qtyController,
                                  keyboardType: TextInputType.number,
                                  decoration: formStyle(S.t('label_quantity'), Icons.tag_outlined),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _priceController,
                                  keyboardType: TextInputType.number,
                                  decoration: formStyle('${S.t('label_unit_price')} (${S.t('misc_currency')})', Icons.attach_money_outlined),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _sectionHeader('Unité de saisie', Icons.straighten_outlined),
                          Row(
                            children: [
                              _unitTypeToggle('piece', '📦 Pièce'),
                              const SizedBox(width: 12),
                              _unitTypeToggle('carton', '🗃️ Carton'),
                            ],
                          ),
                          if (_unitType == 'carton') ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              decoration: formStyle('Pièces par carton', Icons.grid_view_outlined),
                              keyboardType: TextInputType.number,
                              initialValue: _unitsPerCarton.toString(),
                              onChanged: (val) {
                                final parsed = int.tryParse(val) ?? 1;
                                if (parsed > 0) setState(() => _unitsPerCarton = parsed);
                              },
                            ),
                          ],
                          if (_unitType == 'carton') ...[
                            const SizedBox(height: 8),
                            Builder(
                              builder: (_) {
                                final qty = int.tryParse(_qtyController.text) ?? 0;
                                return Text('= ${qty * _unitsPerCarton} pièces au total',
                                  style: GoogleFonts.raleway(fontSize: 13, color: kTextSec));
                              },
                            ),
                          ],
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              minimumSize: const Size(double.infinity, 52),
                              elevation: 2,
                            ),
                            icon: const Icon(Icons.add_shopping_cart_outlined),
                            label: Text(
                              '+ Ajouter à la commande',
                              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            onPressed: _addItemToList,
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
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: kPrimary,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.receipt_long_outlined, color: Colors.white),
                                const SizedBox(width: 8),
                                Text('Bon de Commande',
                                  style: GoogleFonts.cairo(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  )),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text('${_purchaseItems.length} articles',
                                    style: GoogleFonts.raleway(color: Colors.white, fontSize: 13)),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: _purchaseItems.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.shopping_cart_outlined,
                                             size: 64, color: Color(0xFFE0E6ED)),
                                        const SizedBox(height: 12),
                                        Text('Aucun article ajouté',
                                          style: GoogleFonts.cairo(
                                            color: kTextSec, fontSize: 15)),
                                        Text('Sélectionnez un produit et ajoutez-le',
                                          style: GoogleFonts.raleway(
                                            color: Color(0xFFB0BEC5), fontSize: 13)),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    itemCount: _purchaseItems.length,
                                    itemBuilder: (ctx, i) {
                                      final item = _purchaseItems[i];
                                      return Card(
                                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          side: const BorderSide(color: kBorder),
                                        ),
                                        child: ListTile(
                                          dense: true,
                                          leading: CircleAvatar(
                                            backgroundColor: kPrimary.withOpacity(0.1),
                                            child: Text('${i + 1}',
                                              style: const TextStyle(color: kPrimary, fontWeight: FontWeight.bold)),
                                          ),
                                          title: Text(item.label,
                                            style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
                                          subtitle: Text('${item.quantity} × ${item.unitPrice.toStringAsFixed(2)} DA',
                                            style: GoogleFonts.raleway()),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text('${(item.quantity * item.unitPrice).toStringAsFixed(2)} DA',
                                                style: GoogleFonts.raleway(
                                                  fontWeight: FontWeight.bold,
                                                  color: kPrimary)),
                                              IconButton(
                                                icon: const Icon(Icons.close, size: 18, color: Color(0xFFE74C3C)),
                                                onPressed: () => setState(() => _purchaseItems.removeAt(i)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          if (_purchaseItems.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: kPrimary.withOpacity(0.05),
                                border: const Border(top: BorderSide(color: kBorder)),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Total commande:',
                                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                                      Text(
                                        '${_purchaseItems.fold<double>(0, (s, i) => s + i.quantity * i.unitPrice).toStringAsFixed(2)} DA',
                                        style: GoogleFonts.raleway(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: kPrimary)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Articles:',
                                        style: GoogleFonts.raleway(color: kTextSec)),
                                      Text('${_purchaseItems.fold<int>(0, (s, i) => s + i.quantity)} pcs',
                                        style: GoogleFonts.raleway(color: kTextSec)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Moy/pièce:',
                                        style: GoogleFonts.raleway(color: kTextSec)),
                                      Text(
                                        (() {
                                          final tp = _purchaseItems.fold<int>(0, (s, i) => s + i.quantity);
                                          return tp > 0
                                            ? '${(_purchaseItems.fold<double>(0, (s, i) => s + i.quantity * i.unitPrice) / tp).toStringAsFixed(2)} DA'
                                            : '0 DA';
                                        })(),
                                        style: GoogleFonts.raleway(color: kTextSec)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2ECC71),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  minimumSize: const Size(double.infinity, 56),
                                  elevation: 3,
                                ),
                                icon: _isSubmitting
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Icon(Icons.check_circle_outline),
                                label: Text('✅ Confirmer la commande',
                                  style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                                onPressed: _isSubmitting ? null : _showPaymentDialog,
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
          ),
        ],
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