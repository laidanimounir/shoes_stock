import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_session.dart';
import '../../core/app_strings.dart';
import '../../local_db/isar_service.dart';
import '../../local_db/collections/transaction_local.dart';
import '../../services/refund_service.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});
  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  List<dynamic> _sales = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    if (AppSession.isOfflineMode) {
      try {
        final isar = await IsarService.getInstance();
        final storeId = AppSession.currentStoreId;
        var txns = await isar.transactionLocals.where().findAll();
        if (storeId != null) txns = txns.where((t) => t.storeId == storeId).toList();
        txns = txns.where((t) => t.type == 'out').toList();
        txns.sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
        final result = txns.take(100).map((t) => {'id': t.isarId, 'invoice_number': t.invoiceNumber, 'quantity': t.quantity, 'total_price': t.totalPrice, 'created_at': (t.createdAt ?? DateTime(2000)).toIso8601String(), 'type': t.type, 'variant_id': t.variantId}).toList();
        if (mounted) setState(() { _sales = result; _isLoading = false; });
      } catch (_) { if (mounted) setState(() => _isLoading = false); }
      return;
    }
    try {
      final res = await Supabase.instance.client
          .from('transactions')
          .select('id, invoice_number, invoice_id, quantity, total_price, created_at, type, invoices(status), product_variants(id, products(name), size, color)')
          .eq('type', 'out').eq('store_id', AppSession.currentStoreId!).order('created_at', ascending: false).limit(100);
      if (mounted) setState(() { _sales = res; _isLoading = false; });
    } catch (_) { if (mounted) setState(() => _isLoading = false); }
  }

  void _refund(Map<String, dynamic> sale) async {
    final createdAt = DateTime.tryParse(sale['created_at'] ?? '');
    if (createdAt != null) {
      final hours = DateTime.now().difference(createdAt).inHours;
      if (hours > 48 && !AppSession.isOwner) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.t('refund_48h_blocked')), backgroundColor: Colors.red));
        return;
      }
    }
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(S.t('refund_title')),
      content: Text('${S.t('refund_original_invoice')} ${sale['invoice_number']}\n${S.t('refund_total_amount')} ${sale['total_price']} ${S.t('misc_currency')}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.t('action_cancel'))),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: Text(S.t('refund_confirm'))),
      ],
    ));
    if (confirm != true) return;
    try {
      final items = [{'variant_id': sale['variant_id'] ?? sale['product_variants']?['id'], 'quantity': sale['quantity']}];
      await RefundService.instance.processRefund(invoiceId: sale['invoice_id'] ?? sale['id'], items: items, refundAmount: (sale['total_price'] as num).toDouble(), reason: '', storeId: AppSession.currentStoreId ?? '');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.t('refund_success')), backgroundColor: Colors.green));
      _fetch();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red)); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.t('nav_sales')), backgroundColor: Colors.indigo[900], foregroundColor: Colors.white, actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch)]),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : _sales.isEmpty
          ? Center(child: Text(S.t('label_no_data')))
          : RefreshIndicator(onRefresh: _fetch, child: ListView.builder(padding: const EdgeInsets.all(8), itemCount: _sales.length, itemBuilder: (_, i) {
              final s = _sales[i];
              final status = s['invoices']?['status'] as String?;
              final isRefunded = status == 'refunded';
              final pv = s['product_variants'];
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  title: Text('${pv?['products']?['name'] ?? s['invoice_number'] ?? ''}${pv?['size'] != null ? ' (${pv['size']})' : ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('${s['invoice_number'] ?? ''} • ${s['created_at']?.toString().substring(0, 10) ?? ''}', style: const TextStyle(fontSize: 11)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('${s['total_price']} ${S.t('misc_currency')}', style: TextStyle(decoration: isRefunded ? TextDecoration.lineThrough : null, color: isRefunded ? Colors.red : Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                    if (!isRefunded && status != 'refunded')
                      IconButton(icon: const Icon(Icons.assignment_return, color: Colors.red, size: 18), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => _refund(s)),
                  ]),
                ),
              );
            })),
    );
  }
}
