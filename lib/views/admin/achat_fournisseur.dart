import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final results = await Future.wait([
        Supabase.instance.client.from('suppliers').select(),
        Supabase.instance.client.from('stores').select(),
        Supabase.instance.client.from('product_variants').select('id, size, color, barcode, buy_price, products(name)'),
      ]);
      if (mounted) {
        setState(() {
          _suppliers = results[0];
          _stores = results[1];
          _variants = results[2];
          if (_suppliers.isNotEmpty) _selectedSupplierId = _suppliers.first['id'];
          if (_stores.isNotEmpty) _selectedStoreId = _stores.first['id'];
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
        const SnackBar(content: Text('La quantité doit être supérieure à 0.'), backgroundColor: Colors.red),
      );
      return;
    }

    // Find variant display name
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

  Future<void> _submitPurchase() async {
    if (_purchaseItems.isEmpty) return;
    if (_selectedStoreId == null) return;

    setState(() => _isSubmitting = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final invoiceNumber = 'ACH-${DateTime.now().millisecondsSinceEpoch}';

      for (var item in _purchaseItems) {
        // Insert transaction → Trigger auto-updates inventory
        await Supabase.instance.client.from('transactions').insert({
          'invoice_number': invoiceNumber,
          'type': 'in',
          'variant_id': item.variantId,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'total_price': item.unitPrice * item.quantity,
          'store_id': _selectedStoreId,
          'user_id': user!.id,
          'supplier_id': _selectedSupplierId,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Achat enregistré avec succès ! Le stock a été mis à jour.'),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
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
        title: const Text('Achat / Approvisionnement'),
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
                  // Left: Form
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Ajouter des articles', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                          const SizedBox(height: 24),

                          // Supplier selector
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _selectedSupplierId,
                            decoration: const InputDecoration(labelText: 'Fournisseur', border: OutlineInputBorder(), prefixIcon: Icon(Icons.local_shipping)),
                            items: _suppliers.map<DropdownMenuItem<String>>((s) {
                              return DropdownMenuItem(value: s['id'], child: Text(s['company_name']));
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedSupplierId = val),
                          ),
                          const SizedBox(height: 16),

                          // Store selector
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _selectedStoreId,
                            decoration: const InputDecoration(labelText: 'Magasin de réception', border: OutlineInputBorder(), prefixIcon: Icon(Icons.store)),
                            items: _stores.map<DropdownMenuItem<String>>((s) {
                              return DropdownMenuItem(value: s['id'], child: Text(s['name']));
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedStoreId = val),
                          ),
                          const SizedBox(height: 16),

                          // Variant selector
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _selectedVariantId,
                            decoration: const InputDecoration(labelText: 'Produit (Variante)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category)),
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
                                // Auto-fill price from DB if available
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

                          // Quantity + Price
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _qtyController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Quantité', border: OutlineInputBorder(), prefixIcon: Icon(Icons.numbers)),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _priceController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Prix unitaire (€)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.euro)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          ElevatedButton.icon(
                            onPressed: _addItemToList,
                            icon: const Icon(Icons.add),
                            label: const Text('Ajouter à la liste'),
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

                  // Right: Purchase list
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.receipt_long, color: Colors.deepPurple),
                              const SizedBox(width: 12),
                              const Expanded(child: Text('Bon d\'achat', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurple))),
                              Chip(label: Text('${_purchaseItems.length} articles'), backgroundColor: Colors.deepPurple[50]),
                            ],
                          ),
                          const Divider(height: 32),

                          if (_purchaseItems.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 48),
                              child: Center(child: Text('Aucun article ajouté.', style: TextStyle(color: Colors.grey, fontSize: 16))),
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
                                  subtitle: Text('Qté: ${item.quantity} × ${item.unitPrice.toStringAsFixed(2)} € = ${(item.quantity * item.unitPrice).toStringAsFixed(2)} €'),
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
                                const Text('Total:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                Text(
                                  '${_purchaseItems.fold<double>(0, (s, i) => s + i.quantity * i.unitPrice).toStringAsFixed(2)} €',
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 56,
                              child: ElevatedButton.icon(
                                onPressed: _isSubmitting ? null : _submitPurchase,
                                icon: _isSubmitting
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Icon(Icons.check_circle),
                                label: const Text('Valider l\'achat et mettre à jour le stock', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
