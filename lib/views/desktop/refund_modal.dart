import 'package:flutter/material.dart';
import '../../core/app_strings.dart';
import '../../core/app_session.dart';
import '../../services/refund_service.dart';

class RefundModal extends StatefulWidget {
  final Map<String, dynamic> invoice;
  final bool isOwner;
  const RefundModal({super.key, required this.invoice, this.isOwner = false});

  @override
  State<RefundModal> createState() => _RefundModalState();
}

class _RefundModalState extends State<RefundModal> {
  final _reasonController = TextEditingController();
  final _refundService = RefundService.instance;
  bool _isLoading = false;

  // Track checked state and quantity to refund for each item
  final List<Map<String, dynamic>> _refundableItems = [];
  
  @override
  void initState() {
    super.initState();
    _initItems();
  }

  void _initItems() {
    // Expected structure could vary depending on whether we came from sales_history_screen 'transactions'
    // or from getRefundableInvoices. Let's adapt based on widget.invoice details.
    if (widget.invoice.containsKey('product_variants')) {
      // It's a single transaction row from sales_history
      _refundableItems.add({
        'transaction_id': widget.invoice['id'],
        'variant_id': widget.invoice['product_variants'] != null 
            ? widget.invoice['product_variants']['id'] ?? widget.invoice['variant_id'] // Ensure we have variant id
            : widget.invoice['variant_id'],
        'name': widget.invoice['product_variants']?['products']?['name'] ?? 'Produit',
        'size': widget.invoice['product_variants']?['size'] ?? '',
        'max_qty': widget.invoice['quantity'] as int,
        'unit_price': ((widget.invoice['total_price'] as num) / (widget.invoice['quantity'] as num)).toDouble(),
        'selected': true,
        'refund_qty': widget.invoice['quantity'] as int,
      });
    } else if (widget.invoice.containsKey('transactions')) {
      // It's an invoice row containing multiple transactions
      final items = widget.invoice['transactions'] as List<dynamic>;
      for (var item in items) {
        if (item['type'] == 'out') {
          _refundableItems.add({
            'transaction_id': item['id'],
            'variant_id': item['variant_id'],
            'name': 'Article (ID: ${item['variant_id'].toString().substring(0,6)})',
            'size': '',
            'max_qty': item['quantity'] as int,
            'unit_price': (item['unit_price'] as num?)?.toDouble() ?? ((item['total_price'] as num) / (item['quantity'] as num)).toDouble(),
            'selected': true,
            'refund_qty': item['quantity'] as int,
          });
        }
      }
    }
  }

  double get _totalRefundAmount {
    double total = 0.0;
    for (var item in _refundableItems) {
      if (item['selected']) {
        total += item['refund_qty'] * item['unit_price'];
      }
    }
    return total;
  }

  Future<void> _processRefund() async {
    final selectedItems = _refundableItems.where((i) => i['selected']).toList();
    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.t('refund_min_one_item')), backgroundColor: Color(0xFFF87171)),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Construct JSON payload
      final itemsPayload = selectedItems.map((i) => {
        'variant_id': i['variant_id'] ?? widget.invoice['variant_id'],
        'quantity': i['refund_qty'],
        'unit_price': i['unit_price'] ?? ((widget.invoice['total_price'] as num?)?.toDouble() ?? 0) / ((widget.invoice['quantity'] as num?)?.toDouble() ?? 1),
      }).toList();

      // Find original invoice ID. From sales_history it might be in 'invoice_id' if transaction.
      final invoiceId = widget.invoice['invoice_id'] ?? widget.invoice['id'];

      await _refundService.processRefund(
        invoiceId: invoiceId,
        items: itemsPayload,
        refundAmount: _totalRefundAmount,
        reason: _reasonController.text.trim(),
        storeId: widget.invoice['store_id'] ?? AppSession.currentStoreId ?? '',
      );

      // ignore: use_build_context_synchronously
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.t('refund_success')), backgroundColor: Color(0xFF4ADE80)),
      );
      Navigator.of(context).pop(true); // Return true to indicate refresh
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Color(0xFFF87171)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildInvoiceAgeBanner() {
    final createdAtStr = widget.invoice['created_at'] as String?;
    if (createdAtStr == null) return const SizedBox.shrink();
    final createdAt = DateTime.parse(createdAtStr);
    final hoursSince = DateTime.now().difference(createdAt).inHours;
    final ageText = S.t('refund_invoice_age').replaceAll('{hours}', hoursSince.toString());

    final ageColor = hoursSince > 48 ? Color(0xFFF87171) : Color(0xFF4ADE80);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ageColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ageColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(hoursSince > 48 ? Icons.warning_amber_rounded : Icons.access_time, size: 16, color: ageColor),
          const SizedBox(width: 8),
          Text(ageText, style: TextStyle(color: ageColor, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(S.t('refund_title'), textAlign: TextAlign.center),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${S.t('refund_original_invoice')} ${widget.invoice['invoice_number'] ?? "N/A"}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildInvoiceAgeBanner(),
            const SizedBox(height: 16),
            Text(S.t('refund_select_items'), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _refundableItems.length,
                itemBuilder: (context, index) {
                  final item = _refundableItems[index];
                  return Card(
                    child: CheckboxListTile(
                      value: item['selected'],
                      onChanged: (val) {
                        setState(() => item['selected'] = val ?? false);
                      },
                      title: Text('${item['name']} ${item['size']}'),
                      subtitle: Row(
                        children: [
                          Text('${S.t('refund_unit_price')} ${item['unit_price']} DA | '),
                          Text('${S.t('refund_quantity')} '),
                          SizedBox(
                            width: 60,
                            child: DropdownButton<int>(
                              value: item['refund_qty'],
                              items: List.generate(item['max_qty'], (i) => i + 1)
                                  .map((q) => DropdownMenuItem(value: q, child: Text(q.toString())))
                                  .toList(),
                              onChanged: item['selected'] ? (val) {
                                if (val != null) setState(() => item['refund_qty'] = val);
                              } : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              color: Color(0xFF2B0D0D),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(S.t('refund_total_amount'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFF87171))),
                  Text('${_totalRefundAmount.toStringAsFixed(2)} DA', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFF87171))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'سبب الإرجاع (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(S.t('action_cancel'), style: const TextStyle(color: Color(0xFF9090A8))),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _processRefund,
          style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFF87171), foregroundColor: Color(0xFFEEEEFF)),
          child: _isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Color(0xFFEEEEFF), strokeWidth: 2)) : Text(S.t('refund_confirm')),
        ),
      ],
    );
  }
}
