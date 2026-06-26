import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../core/app_strings.dart';

class StockTransferScreen extends StatefulWidget {
  const StockTransferScreen({super.key});

  @override
  State<StockTransferScreen> createState() => _StockTransferScreenState();
}

class _StockTransferScreenState extends State<StockTransferScreen> {
  bool _isLoading = true;
  List<dynamic> _stores = [];
  List<dynamic> _transfers = [];
  String? _selectedFromStoreId;
  String? _selectedToStoreId;
  String? _selectedVariantId;
  int _quantity = 1;
  List<Map<String, dynamic>> _variants = [];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([_fetchStores(), _fetchTransfers(), _fetchVariants()]);
    } catch (e) {
      debugPrint('Error init stock transfer: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchStores() async {
    final res = await Supabase.instance.client
        .from('stores')
        .select()
        .eq('is_active', true)
        .order('name');
    if (mounted) setState(() => _stores = res);
  }

  Future<void> _fetchTransfers() async {
    final res = await Supabase.instance.client
        .from('stock_transfers')
        .select('*, from_store:from_store_id(name), to_store:to_store_id(name), variant:variant_id(size, color, products(name))')
        .order('transferred_at', ascending: false);
    if (mounted) setState(() => _transfers = res);
  }

  Future<void> _fetchVariants() async {
    final res = await Supabase.instance.client
        .from('product_variants')
        .select('id, size, color, barcode, products(name)')
        .eq('is_active', true);
    if (mounted) {
      setState(() {
        _variants = List<Map<String, dynamic>>.from(res);
      });
    }
  }

  Future<void> _createTransfer() async {
    if (_selectedFromStoreId == null || _selectedToStoreId == null || _selectedVariantId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez remplir tous les champs'), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    if (_selectedFromStoreId == _selectedToStoreId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Les magasins doivent être différents'), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    if (_quantity < 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quantité invalide'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    try {
      await Supabase.instance.client.from('stock_transfers').insert({
        'from_store_id': _selectedFromStoreId,
        'to_store_id': _selectedToStoreId,
        'variant_id': _selectedVariantId,
        'quantity': _quantity,
        'transferred_by': Supabase.instance.client.auth.currentUser!.id,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transfert créé, en attente'), backgroundColor: Colors.green),
        );
      }

      setState(() {
        _selectedFromStoreId = null;
        _selectedToStoreId = null;
        _selectedVariantId = null;
        _quantity = 1;
      });
      _fetchTransfers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _executeTransfer(String transferId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.t('transfer_execute_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.t('action_cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.desktopPrimary),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(S.t('action_confirm')),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await Supabase.instance.client.rpc('execute_stock_transfer', params: {
        'p_transfer_id': transferId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transfert effectué avec succès'), backgroundColor: Colors.green),
        );
      }
      _fetchTransfers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.desktopBackground,
      appBar: AppBar(
        title: Text(S.t('transfer_title')),
        backgroundColor: AppColors.desktopSurface,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildTransferForm(),
                const Divider(height: 1),
                Expanded(child: _buildTransferList()),
              ],
            ),
    );
  }

  Widget _buildTransferForm() {
    final availableToStores = _stores.where((s) => s['id'] != _selectedFromStoreId).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.desktopSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.t('transfer_new'),
              style: AppTextStyles.headingLarge(
                  color: Colors.white)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedFromStoreId,
                  decoration: _inputDecoration(S.t('transfer_from')),
                  dropdownColor: AppColors.desktopSurface,
                  style: AppTextStyles.bodyMedium(color: Colors.white),
                  items: _stores.map<DropdownMenuItem<String>>((s) => DropdownMenuItem(
                    value: s['id'] as String?,
                    child: Text(s['name'] ?? '', style: const TextStyle(color: Colors.white)),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedFromStoreId = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedToStoreId,
                  decoration: _inputDecoration(S.t('transfer_to')),
                  dropdownColor: AppColors.desktopSurface,
                  style: AppTextStyles.bodyMedium(color: Colors.white),
                  items: availableToStores.map<DropdownMenuItem<String>>((s) => DropdownMenuItem(
                    value: s['id'] as String?,
                    child: Text(s['name'] ?? '', style: const TextStyle(color: Colors.white)),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedToStoreId = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Autocomplete<Map<String, dynamic>>(
            optionsBuilder: (textEditingValue) {
              if (textEditingValue.text.isEmpty) return _variants;
              final q = textEditingValue.text.toLowerCase();
              return _variants.where((v) {
                final name = (v['products']?['name'] as String? ?? '').toLowerCase();
                final size = (v['size'] as String? ?? '').toLowerCase();
                final color = (v['color'] as String? ?? '').toLowerCase();
                return name.contains(q) || size.contains(q) || color.contains(q);
              });
            },
            displayStringForOption: (v) =>
                '${v['products']?['name'] ?? ''} (${v['size'] ?? ''} - ${v['color'] ?? ''})',
            onSelected: (v) => setState(() => _selectedVariantId = v['id'] as String?),
            fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
              return TextFormField(
                controller: controller,
                focusNode: focusNode,
                decoration: _inputDecoration(S.t('transfer_variant')),
                style: AppTextStyles.bodyMedium(color: Colors.white),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: _quantity.toString(),
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration(S.t('transfer_qty')),
                  style: AppTextStyles.bodyMedium(color: Colors.white),
                  onChanged: (v) => _quantity = int.tryParse(v) ?? 1,
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _createTransfer,
                icon: const Icon(Icons.send, size: 16),
                label: Text(S.t('action_add')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.desktopPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: AppTextStyles.bodyMedium(color: AppColors.desktopTextSecondary),
      filled: true,
      fillColor: AppColors.desktopBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.desktopBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.desktopBorder),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  Widget _buildTransferList() {
    if (_transfers.isEmpty) {
      return Center(
        child: Text(S.t('transfer_no_transfers'),
            style: AppTextStyles.bodyMedium(color: AppColors.desktopTextSecondary)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _transfers.length,
      itemBuilder: (context, index) {
        final t = _transfers[index];
        final status = t['status'] as String? ?? 'pending';
        final fromName = t['from_store']?['name'] ?? '-';
        final toName = t['to_store']?['name'] ?? '-';
        final variantData = t['variant'];
        final variantName = variantData != null
            ? '${variantData['products']?['name'] ?? ''} (${variantData['size'] ?? ''} - ${variantData['color'] ?? ''})'
            : '-';
        final qty = t['quantity'] ?? 0;

        Color statusColor;
        String statusLabel;
        switch (status) {
          case 'completed':
            statusColor = Colors.green;
            statusLabel = S.t('transfer_status_done');
          case 'cancelled':
            statusColor = Colors.red;
            statusLabel = S.t('action_cancel');
          default:
            statusColor = Colors.orange;
            statusLabel = S.t('transfer_status_pending');
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.desktopSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.desktopBorder, width: 0.8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(variantName,
                        style: AppTextStyles.bodyMedium(
                            color: Colors.white),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('$fromName → $toName',
                        style: AppTextStyles.bodyMedium(color: AppColors.desktopTextSecondary)),
                    const SizedBox(height: 2),
                    Text('${S.t('label_quantity')}: $qty',
                        style: AppTextStyles.bodyMedium(color: AppColors.desktopTextSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(statusLabel,
                    style: AppTextStyles.bodyMedium(
                        color: statusColor)),
              ),
              if (status == 'pending') ...[
                const SizedBox(width: 8),
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: () => _executeTransfer(t['id'] as String),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(S.t('transfer_execute'),
                        style: AppTextStyles.bodyMedium(fontSize: 11)),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
