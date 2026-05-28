import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_strings.dart';
import '../../core/app_session.dart';
import '../../services/purchase_service.dart';

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

  // Error state
  bool _hasError = false;
  String _errorMessage = '';

  // Smart selection state
  List<Map<String, dynamic>> _purchaseHistory = [];
  int _currentStock = 0;
  double? _lastPurchasePrice;
  DateTime? _lastPurchaseDate;
  bool _isLoadingHistory = false;
  double _enteredPrice = 0;
  bool _isPriceDifferent = false;
  double _priceDiffPercent = 0;
  int _infoLoadVersion = 0;

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
        Supabase.instance.client.from('product_variants').select('id, product_id, size, color, barcode, buy_price, sell_price, products(name)').eq('is_active', true),
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

          // Load smart info for initial variant
          if (_selectedVariantId != null && _selectedStoreId != null) {
            _loadVariantSmartInfo(variantId: _selectedVariantId!, storeId: _selectedStoreId!);
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Impossible de charger les données : ${e.toString()}';
      });
    } finally {
      if (mounted && _isLoading) setState(() => _isLoading = false);
    }
  }

  void _addItemToList() {
    if (_selectedVariantId == null || _selectedStoreId == null) return;
    final inputQty = int.tryParse(_qtyController.text) ?? 0;
    final enteredPrice = double.tryParse(_priceController.text) ?? 0;

    if (inputQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.t('buy_qty_invalid')), backgroundColor: Colors.red),
      );
      return;
    }

    // Check for price difference from last purchase
    if (_lastPurchasePrice != null && enteredPrice != 0 && enteredPrice != _lastPurchasePrice) {
      _showNouvelleArrivageDialog(enteredPrice);
      return;
    }

    _confirmAddItem(price: enteredPrice, isNouvelleArrivage: false);
  }

  // ========== NOUVELLE ARRIVAGE ==========

  void _showNouvelleArrivageDialog(double newPrice) {
    final diff = newPrice - _lastPurchasePrice!;
    final pct = (diff / _lastPurchasePrice! * 100).toStringAsFixed(1);
    final isHigher = diff > 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.compare_arrows_outlined, color: Color(0xFFE67E22), size: 24),
          const SizedBox(width: 8),
          Text('Prix différent détecté',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 17)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE0E6ED)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(children: [
                    Text('Ancien prix',
                      style: GoogleFonts.raleway(fontSize: 12, color: Color(0xFF6B7C93))),
                    Text('${_lastPurchasePrice!.toStringAsFixed(0)} DA',
                      style: GoogleFonts.raleway(fontSize: 16, fontWeight: FontWeight.bold)),
                  ]),
                  Icon(Icons.arrow_forward,
                    color: isHigher ? const Color(0xFFE67E22) : const Color(0xFF2ECC71)),
                  Column(children: [
                    Text('Nouveau prix',
                      style: GoogleFonts.raleway(fontSize: 12, color: Color(0xFF6B7C93))),
                    Text('${newPrice.toStringAsFixed(0)} DA',
                      style: GoogleFonts.raleway(fontSize: 16, fontWeight: FontWeight.bold,
                        color: isHigher ? const Color(0xFFE67E22) : const Color(0xFF2ECC71))),
                  ]),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isHigher ? const Color(0xFFE67E22) : const Color(0xFF2ECC71)).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${isHigher ? "+" : ""}$pct%',
                      style: GoogleFonts.raleway(fontWeight: FontWeight.bold,
                        color: isHigher ? const Color(0xFFE67E22) : const Color(0xFF2ECC71))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Comment traiter cet achat?',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 12),
            _arrivageOption(
              icon: Icons.add_circle_outline,
              color: const Color(0xFF1B4F72),
              title: 'Ajouter au stock existant',
              subtitle: 'Même produit, prix mis à jour',
              onTap: () {
                Navigator.pop(ctx);
                _confirmAddItem(price: newPrice, isNouvelleArrivage: false);
              },
            ),
            const SizedBox(height: 8),
            _arrivageOption(
              icon: Icons.new_releases_outlined,
              color: const Color(0xFF2ECC71),
              title: 'Nouvelle arrivage',
              subtitle: 'Stock séparé avec nouveau prix d\'achat',
              onTap: () async {
                Navigator.pop(ctx);
                final created = await _createArrivageVariant(newPrice);
                if (created != null && mounted) {
                  setState(() {
                    _variants = [..._variants, created];
                    _selectedVariantId = created['id'];
                  });
                  if (_selectedStoreId != null) {
                    _loadVariantSmartInfo(variantId: created['id'], storeId: _selectedStoreId!);
                  }
                  _confirmAddItem(price: newPrice, isNouvelleArrivage: true);
                } else if (mounted) {
                  _confirmAddItem(price: newPrice, isNouvelleArrivage: false);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: GoogleFonts.cairo(color: Color(0xFF6B7C93))),
          ),
        ],
      ),
    );
  }

  Widget _arrivageOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(10),
          color: color.withOpacity(0.05),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
              Text(subtitle,
                style: GoogleFonts.raleway(fontSize: 12, color: Color(0xFF6B7C93))),
            ],
          )),
          Icon(Icons.arrow_forward_ios, size: 14, color: color),
        ]),
      ),
    );
  }

  void _confirmAddItem({required double price, required bool isNouvelleArrivage}) {
    final inputQty = int.tryParse(_qtyController.text) ?? 0;

    final variant = _variants.firstWhere((v) => v['id'] == _selectedVariantId);
    final p = variant['products'];
    final productName = (p is Map) ? (p['name'] ?? 'Inconnu') : 'Inconnu';
    final effectiveQty = _unitType == 'carton' ? inputQty * _unitsPerCarton : inputQty;
    final label = _unitType == 'carton'
        ? '$productName (${variant['size']} / ${variant['color']}) [$inputQty cartons × $_unitsPerCarton pcs]'
        : '$productName (${variant['size']} / ${variant['color']})';

    final arrivageId = isNouvelleArrivage ? _generateUuidV4() : null;

    setState(() {
      _purchaseItems.add(_PurchaseItem(
        variantId: _selectedVariantId!,
        label: label,
        quantity: effectiveQty,
        unitPrice: price,
        isNouvelleArrivage: isNouvelleArrivage,
        arrivageId: arrivageId,
        purchasePrice: isNouvelleArrivage ? price : null,
      ));
      _qtyController.clear();
      _priceController.clear();
      _clearSmartInfo();
    });
  }

  Future<Map<String, dynamic>?> _createArrivageVariant(double newPrice) async {
    try {
      final original = _variants.firstWhere((v) => v['id'] == _selectedVariantId);
      final productId = original['product_id'];
      final size = original['size'] as String;
      final colorBase = (original['color'] as String).replaceAll(RegExp(r'\s*\[Arrivage.*?\]$'), '');

      final count = _variants.where((v) =>
          v['product_id'] == productId &&
          v['size'] == size &&
          (v['color'] as String).replaceAll(RegExp(r'\s*\[Arrivage.*?\]$'), '') == colorBase).length;

      final now = DateTime.now();
      final dateStr = '${now.day.toString().padLeft(2, '0')}/'
          '${now.month.toString().padLeft(2, '0')}/${now.year}';
      final label = '[Arrivage ${count + 1} • $dateStr]';
      final newColor = '$colorBase $label';

      final response = await Supabase.instance.client
          .from('product_variants')
          .insert({
            'product_id': productId,
            'size': size,
            'color': newColor,
            'buy_price': newPrice,
            'sell_price': original['buy_price'],
            'barcode': null,
          })
          .select('id, product_id, size, color, barcode, buy_price, sell_price, products(name)')
          .single();

      return response;
    } catch (e) {
      debugPrint('Error creating arrivage variant: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur création arrivage: ${e.toString()}'),
          backgroundColor: Colors.red,
        ));
      }
      return null;
    }
  }

  // ========== DEFINE + BUY ==========

  void _showDefinePlusAchetDialog() {
    final nameCtrl = TextEditingController();
    final buyPriceCtrl = TextEditingController();
    final sellPriceCtrl = TextEditingController();
    final colorCtrl = TextEditingController(text: 'Noir');
    String dlgCategory = 'homme';
    String dlgSize = '';
    int dlgQty = 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.add_business_outlined, color: Color(0xFF1B4F72)),
            const SizedBox(width: 8),
            Text('Définir + Acheter',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ce produit sera créé et ajouté au stock en une seule opération.',
                  style: GoogleFonts.raleway(fontSize: 13, color: Color(0xFF6B7C93))),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nom du produit',
                    labelStyle: GoogleFonts.raleway(color: Color(0xFF6B7C93)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE0E6ED))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE0E6ED))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF1B4F72), width: 2)),
                    filled: true, fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    prefixIcon: const Icon(Icons.inventory_2_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: ['homme', 'femme', 'enfant'].map((cat) =>
                  Expanded(child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                      label: Text(
                        cat == 'homme' ? '👨 Homme' : cat == 'femme' ? '👩 Femme' : '👶 Enfant',
                        style: GoogleFonts.cairo(fontSize: 12,
                          color: dlgCategory == cat ? Colors.white : null)),
                      selected: dlgCategory == cat,
                      selectedColor: const Color(0xFF1B4F72),
                      onSelected: (_) => setDlgState(() => dlgCategory = cat),
                    ),
                  ))
                ).toList()),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Pointure',
                      labelStyle: GoogleFonts.raleway(color: Color(0xFF6B7C93)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE0E6ED))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE0E6ED))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF1B4F72), width: 2)),
                      filled: true, fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => dlgSize = v,
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(
                    controller: colorCtrl,
                    decoration: InputDecoration(
                      labelText: 'Couleur',
                      labelStyle: GoogleFonts.raleway(color: Color(0xFF6B7C93)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE0E6ED))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE0E6ED))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF1B4F72), width: 2)),
                      filled: true, fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  )),
                ]),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Quantité achetée',
                    labelStyle: GoogleFonts.raleway(color: Color(0xFF6B7C93)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE0E6ED))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE0E6ED))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF1B4F72), width: 2)),
                    filled: true, fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    prefixIcon: const Icon(Icons.tag_outlined),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => dlgQty = int.tryParse(v) ?? 1,
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(
                    controller: buyPriceCtrl,
                    decoration: InputDecoration(
                      labelText: 'Prix achat (DA)',
                      labelStyle: GoogleFonts.raleway(color: Color(0xFF6B7C93)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE0E6ED))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE0E6ED))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF1B4F72), width: 2)),
                      filled: true, fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      prefixIcon: const Icon(Icons.arrow_downward, color: Color(0xFFE67E22)),
                    ),
                    keyboardType: TextInputType.number,
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(
                    controller: sellPriceCtrl,
                    decoration: InputDecoration(
                      labelText: 'Prix vente (DA)',
                      labelStyle: GoogleFonts.raleway(color: Color(0xFF6B7C93)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE0E6ED))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE0E6ED))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF1B4F72), width: 2)),
                      filled: true, fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      prefixIcon: const Icon(Icons.arrow_upward, color: Color(0xFF2ECC71)),
                    ),
                    keyboardType: TextInputType.number,
                  )),
                ]),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler', style: GoogleFonts.cairo(color: Color(0xFF6B7C93))),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: Text('Créer + Ajouter',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2ECC71),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await _defineAndBuy(
                  name: nameCtrl.text,
                  category: dlgCategory,
                  size: dlgSize,
                  color: colorCtrl.text,
                  quantity: dlgQty,
                  buyPrice: double.tryParse(buyPriceCtrl.text) ?? 0,
                  sellPrice: double.tryParse(sellPriceCtrl.text) ?? 0,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _defineAndBuy({
    required String name,
    required String category,
    required String size,
    required String color,
    required int quantity,
    required double buyPrice,
    required double sellPrice,
  }) async {
    if (name.isEmpty || size.isEmpty || buyPrice <= 0 || sellPrice <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Veuillez remplir tous les champs obligatoires'),
          backgroundColor: Color(0xFFE74C3C),
        ));
      }
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final invoiceNumber = 'ACH-${DateTime.now().millisecondsSinceEpoch}';

      // STEP 1: Create product
      final productResponse = await Supabase.instance.client
        .from('products')
        .insert({
          'name': name,
          'category': category,
          'supplier_id': _selectedSupplierId,
        })
        .select('id')
        .single();
      final productId = productResponse['id'];

      // STEP 2: Create variant (barcode auto-generated by DB trigger)
      final variantResponse = await Supabase.instance.client
        .from('product_variants')
        .insert({
          'product_id': productId,
          'size': size,
          'color': color,
          'buy_price': buyPrice,
          'sell_price': sellPrice,
          'barcode': null,
        })
        .select('id')
        .single();
      final variantId = variantResponse['id'];

      // STEP 3: Call process_purchase RPC (same params as existing)
      await Supabase.instance.client.rpc('process_purchase', params: {
        'p_store_id': _selectedStoreId,
        'p_supplier_id': _selectedSupplierId,
        'p_invoice_number': invoiceNumber,
        'p_items': [{
          'variant_id': variantId,
          'quantity': quantity,
          'unit_price': buyPrice,
          'total_price': buyPrice * quantity,
        }],
        'p_total_amount': buyPrice * quantity,
        'p_paid_amount': buyPrice * quantity,
        'p_payment_method': 'cash',
        'p_notes': 'Achat direct depuis Définir + Acheter',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Produit créé et ajouté au stock avec succès'),
          backgroundColor: Color(0xFF2ECC71),
        ));
      }

      // Reload dropdowns
      await _fetchData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: const Color(0xFFE74C3C),
        ));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
      final items = _purchaseItems.map((item) => {
        'variant_id': item.variantId,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
        'total_price': item.unitPrice * item.quantity,
      }).toList();

      await PurchaseService.instance.processPurchase(
        storeId: _selectedStoreId!,
        supplierId: _selectedSupplierId!,
        items: items,
        totalAmount: totalAmount,
        paidAmount: paidAmount,
        paymentMethod: 'cash',
        notes: 'Paiement à la création de la facture ACH-${DateTime.now().millisecondsSinceEpoch}',
      );

      // Update inventory for nouvelle arrivage items
      if (!AppSession.isOfflineMode) {
        for (final item in _purchaseItems.where((i) => i.isNouvelleArrivage)) {
          await Supabase.instance.client
            .from('inventory')
            .update({
              'arrivage_id': item.arrivageId,
              'arrivage_date': DateTime.now().toIso8601String(),
              'purchase_price': item.purchasePrice,
            })
            .eq('variant_id', item.variantId)
            .eq('store_id', _selectedStoreId!);
        }
      }

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

  Future<List<Map<String, dynamic>>> _fetchPurchaseHistory(String variantId, String storeId) async {
    try {
      final response = await Supabase.instance.client
          .from('transactions')
          .select('created_at, quantity, unit_price')
          .eq('variant_id', variantId)
          .eq('store_id', storeId)
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

  Future<void> _loadVariantSmartInfo({required String variantId, required String storeId}) async {
    final loadVersion = ++_infoLoadVersion;
    setState(() => _isLoadingHistory = true);
    try {
      final results = await Future.wait([
        _fetchPurchaseHistory(variantId, storeId),
        _fetchVariantStock(variantId, storeId),
      ]);
      if (loadVersion != _infoLoadVersion) return;
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
      if (mounted && loadVersion == _infoLoadVersion) {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  void _clearSmartInfo() {
    setState(() {
      _purchaseHistory = [];
      _currentStock = 0;
      _lastPurchasePrice = null;
      _lastPurchaseDate = null;
      _isPriceDifferent = false;
      _priceDiffPercent = 0;
      _enteredPrice = 0;
    });
  }

  String _generateUuidV4() {
    final r = Random();
    final hex = List.generate(32, (_) => r.nextInt(16).toRadixString(16));
    hex[12] = '4';
    hex[16] = (8 + r.nextInt(4)).toRadixString(16);
    return '${hex.sublist(0, 8).join()}-'
        '${hex.sublist(8, 12).join()}-'
        '${hex.sublist(12, 16).join()}-'
        '${hex.sublist(16, 20).join()}-'
        '${hex.sublist(20, 32).join()}';
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
                      color: _currentStock > 10 ? const Color(0xFF2ECC71)
                           : _currentStock >= 1 ? const Color(0xFFE67E22)
                           : _currentStock == 0 ? const Color(0xFFE74C3C)
                           : const Color(0xFF7B0000),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${_currentStock < 0 ? "⚠️ " : ""}$_currentStock pcs',
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
          : _hasError
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off, size: 64, color: Color(0xFFE74C3C)),
                        const SizedBox(height: 16),
                        Text(
                          'Erreur de chargement',
                          style: GoogleFonts.cairo(
                            fontSize: 18, fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A2533)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.raleway(fontSize: 14, color: Color(0xFF6B7C93)),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: Text('Réessayer',
                            style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B4F72),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            setState(() {
                              _hasError = false;
                              _errorMessage = '';
                              _isLoading = true;
                            });
                            _fetchData();
                          },
                        ),
                      ],
                    ),
                  ),
                )
              : LayoutBuilder(
        builder: (context, constraints) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _sectionHeader('Fournisseur', Icons.local_shipping_outlined),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _selectedSupplierId,
                            decoration: formStyle(S.t('suppliers_title'), Icons.local_shipping_outlined),
                            items: _suppliers.map<DropdownMenuItem<String>>((s) {
                              return DropdownMenuItem(value: s['id'], child: Text(s['company_name'] ?? ''));
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedSupplierId = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _sectionHeader('Magasin de réception', Icons.store_outlined),
                          if (AppSession.isEmployee)
                            TextFormField(
                              readOnly: true,
                              decoration: formStyle(S.t('buy_store_receiving'), Icons.store_outlined),
                              initialValue: AppSession.currentStoreId != null && _stores.any((s) => s['id'] == AppSession.currentStoreId)
                                  ? (_stores.firstWhere((s) => s['id'] == AppSession.currentStoreId)['name']?.toString() ?? '')
                                  : S.t('buy_my_store'),
                            )
                          else
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _selectedStoreId,
                              decoration: formStyle(S.t('buy_store_receiving'), Icons.store_outlined),
                              items: _stores.map<DropdownMenuItem<String>>((s) {
                                return DropdownMenuItem(value: s['id'], child: Text(s['name'] ?? ''));
                              }).toList(),
                              onChanged: (val) {
                                setState(() { _selectedStoreId = val; });
                                if (_selectedVariantId != null && val != null) {
                                  _loadVariantSmartInfo(variantId: _selectedVariantId!, storeId: val);
                                }
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 400,
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _sectionHeader('Produit & Variante', Icons.inventory_2_outlined),
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  value: _selectedVariantId,
                                  decoration: formStyle(S.t('buy_product_variant'), Icons.inventory_2_outlined),
                                  items: _variants.map<DropdownMenuItem<String>>((v) {
                                    final p = v['products'];
                                    final name = (p is Map) ? (p['name'] ?? 'Inconnu') : 'Inconnu';
                                    return DropdownMenuItem(
                                      value: v['id'],
                                      child: Text('$name (${v['size']} / ${v['color']})'),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val == null) return;
                                    setState(() {
                                      _selectedVariantId = val;
                                      _isPriceDifferent = false;
                                      _priceDiffPercent = 0;
                                      _enteredPrice = 0;
                                    });
                                    final matches = _variants.where((v) => v['id'] == val);
                                    if (matches.isNotEmpty) {
                                      final v = matches.first;
                                      if (v['buy_price'] != null) {
                                        _priceController.text = v['buy_price'].toString();
                                      }
                                    }
                                    if (_selectedStoreId != null) {
                                      _loadVariantSmartInfo(variantId: val, storeId: _selectedStoreId!);
                                    }
                                  },
                                ),
                                if (_selectedVariantId != null) ...[
                                  const SizedBox(height: 8),
                                  _buildSmartInfoCard(),
                                  const SizedBox(height: 8),
                                  if (_purchaseHistory.isNotEmpty)
                                    _buildPurchaseHistoryTable(),
                                ],
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
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _priceController,
                                        keyboardType: TextInputType.number,
                                        decoration: formStyle('${S.t('label_unit_price')} (${S.t('misc_currency')})', Icons.attach_money_outlined),
                                        onChanged: (val) {
                                          final newPrice = double.tryParse(val) ?? 0;
                                          setState(() {
                                            _enteredPrice = newPrice;
                                            if (_lastPurchasePrice != null && newPrice > 0 && newPrice != _lastPurchasePrice) {
                                              _isPriceDifferent = true;
                                              _priceDiffPercent = ((newPrice - _lastPurchasePrice!) / _lastPurchasePrice! * 100);
                                            } else {
                                              _isPriceDifferent = false;
                                              _priceDiffPercent = 0;
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                if (_isPriceDifferent && _lastPurchasePrice != null) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.orange.shade300),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange.shade700),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'Nouvelle arrivage: '
                                            '${_lastPurchasePrice!.toStringAsFixed(0)}'
                                            ' → ${_enteredPrice.toStringAsFixed(0)} DA '
                                            '(${_priceDiffPercent > 0 ? "+" : ""}'
                                            '${_priceDiffPercent.toStringAsFixed(1)}%)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.orange.shade700,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
                                const SizedBox(height: 16),
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
                                const Divider(color: Color(0xFFE0E6ED), height: 24),
                                Row(
                                  children: [
                                    const Icon(Icons.help_outline, size: 16, color: Color(0xFF6B7C93)),
                                    const SizedBox(width: 6),
                                    Text('Produit non enregistré?',
                                      style: GoogleFonts.cairo(fontSize: 13, color: Color(0xFF6B7C93))),
                                    const Spacer(),
                                    TextButton.icon(
                                      icon: const Icon(Icons.add_business_outlined, color: Color(0xFF1B4F72), size: 18),
                                      label: Text('Définir + Acheter',
                                        style: GoogleFonts.cairo(
                                          color: Color(0xFF1B4F72),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                      onPressed: _showDefinePlusAchetDialog,
                                      style: TextButton.styleFrom(
                                        backgroundColor: const Color(0xFF1B4F72).withOpacity(0.08),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                              const Divider(height: 1, color: Color(0xFFE0E6ED)),
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
                                              title: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(item.label,
                                                      style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
                                                  ),
                                                  if (item.isNouvelleArrivage)
                                                    Container(
                                                      margin: const EdgeInsets.only(left: 8),
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF2ECC71).withOpacity(0.15),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text('Nouvelle arrivage 🆕',
                                                        style: GoogleFonts.cairo(fontSize: 10, color: const Color(0xFF2ECC71))),
                                                    ),
                                                ],
                                              ),
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
                                const Divider(height: 1, color: Color(0xFFE0E6ED)),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: kPrimary.withOpacity(0.05),
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
                                  child: SizedBox(
                                    width: double.infinity,
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
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PurchaseItem {
  final String variantId;
  final String label;
  final int quantity;
  final double unitPrice;
  final bool isNouvelleArrivage;
  final String? arrivageId;
  final double? purchasePrice;

  _PurchaseItem({
    required this.variantId,
    required this.label,
    required this.quantity,
    required this.unitPrice,
    this.isNouvelleArrivage = false,
    this.arrivageId,
    this.purchasePrice,
  });
}