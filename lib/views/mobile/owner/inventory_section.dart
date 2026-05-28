import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/app_strings.dart';
import '../../../local_db/isar_service.dart';
import '../../../local_db/collections/inventory_local.dart';
import '../../../local_db/collections/product_local.dart';
import '../../../local_db/collections/product_variant_local.dart';

class InventorySection extends StatefulWidget {
  const InventorySection({super.key});

  @override
  State<InventorySection> createState() => _InventorySectionState();
}

class _InventorySectionState extends State<InventorySection> {
  List<dynamic> _inventory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchInventory();
  }

  Future<void> _fetchInventory() async {
    try {
      final res = await Supabase.instance.client
          .from('inventory')
          .select('quantity, stores(name), product_variants(size, color, products(name))')
          .order('quantity', ascending: true);
      if (mounted) setState(() { _inventory = res; _isLoading = false; });
    } catch (e) {
      try {
        final isar = await IsarService.getInstance();
        final items = await isar.inventoryLocals.where().findAll();
        items.sort((a, b) => a.quantity.compareTo(b.quantity));
        final allVariants = await isar.productVariantLocals.where().findAll();
        final allProducts = await isar.productLocals.where().findAll();
        final result = <Map<String, dynamic>>[];
        for (final item in items) {
          final variant = allVariants.cast<ProductVariantLocal?>().firstWhere(
            (v) => v?.supabaseId == item.variantId,
            orElse: () => null,
          );
          final prod = variant != null ? allProducts.cast<ProductLocal?>().firstWhere(
            (p) => p?.supabaseId == variant.productId,
            orElse: () => null,
          ) : null;
          result.add({
            'quantity': item.quantity,
            'stores': {'name': item.storeId},
            'product_variants': {
              'size': variant?.size ?? '', 'color': variant?.color ?? '',
              'products': {'name': prod?.name ?? ''},
            },
          });
        }
        if (mounted) setState(() { _inventory = result; _isLoading = false; });
      } catch (_) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.inventory_2, color: Colors.indigo[900], size: 22),
                    const SizedBox(width: 10),
                    Text(S.t('owner_inv_all_stores'),
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.indigo[900])),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _inventory.isEmpty
                        ? Center(child: Text(S.t('owner_no_items_stock')))
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: _inventory.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                            itemBuilder: (context, index) {
                              final item = _inventory[index];
                              final qty = (item['quantity'] as num?)?.toInt() ?? 0;
                              final isLow = qty < 3;
                              final productName = item['product_variants']?['products']?['name'] ?? '—';
                              final size = item['product_variants']?['size'] ?? '';
                              final color = item['product_variants']?['color'] ?? '';
                              final storeName = item['stores']?['name'] ?? '—';
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isLow ? Colors.red[50] : Colors.indigo[50],
                                  child: Icon(
                                    isLow ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                                    color: isLow ? Colors.red : Colors.indigo,
                                    size: 20,
                                  ),
                                ),
                                title: Text('$productName  •  ${S.t('pos_size')} $size',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text('$storeName  |  ${S.t('pos_color')}: $color',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isLow ? Colors.red[50] : Colors.green[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text('$qty ${S.t('inv_units')}',
                                      style: TextStyle(
                                        color: isLow ? Colors.red : Colors.green[700],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      )),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}
