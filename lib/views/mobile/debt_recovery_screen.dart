import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_session.dart';
import '../../core/app_strings.dart';
import '../../services/debt_recovery_service.dart';

class DebtRecoveryScreen extends StatefulWidget {
  const DebtRecoveryScreen({super.key});
  @override
  State<DebtRecoveryScreen> createState() => _DebtRecoveryScreenState();
}

class _DebtRecoveryScreenState extends State<DebtRecoveryScreen> {
  List<Map<String, dynamic>> _debts = [];
  bool _isLoading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _fetch(); }
  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      final data = await DebtRecoveryService.instance.fetchCustomersWithDebt(AppSession.currentStoreId!);
      if (mounted) setState(() { _debts = data; _isLoading = false; });
    } catch (_) { if (mounted) setState(() => _isLoading = false); }
  }

  void _recordPayment(Map<String, dynamic> debtor) async {
    final amountCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(S.t('cust_receive_payment')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${S.t('pos_credit')}: ${(debtor['balance'] as num?)?.toDouble() ?? 0} ${S.t('misc_currency')}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        const SizedBox(height: 12),
        TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Montant', border: OutlineInputBorder())),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.t('action_cancel'))),
        ElevatedButton(onPressed: () async {
          final amount = double.tryParse(amountCtrl.text);
          if (amount == null || amount <= 0) return;
          Navigator.pop(ctx);
          try {
            await DebtRecoveryService.instance.recordDebtPayment(
              customerId: debtor['id'] as String, amount: amount,
              paymentMethod: 'cash', storeId: AppSession.currentStoreId!, notes: 'Recouvrement dette',
            );
            _fetch();
          } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red)); }
        }, child: Text(S.t('action_confirm'))),
      ],
    ));
  }

  // ─── WhatsApp / SMS ─────────────────────────────────────────
  String _cleanPhone(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[\s\-\.\(\)]'), '');
    if (cleaned.startsWith('00213')) {
      cleaned = '+213${cleaned.substring(5)}';
    } else if (cleaned.startsWith('0')) {
      cleaned = '+213${cleaned.substring(1)}';
    } else if (!cleaned.startsWith('+')) {
      cleaned = '+213$cleaned';
    }
    return cleaned;
  }

  Future<void> _sendWhatsApp(String phone, String name, double balance) async {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.t('contact_no_phone')), backgroundColor: Colors.orange),
      );
      return;
    }
    final cleanedPhone = _cleanPhone(phone).replaceAll('+', '');
    final message = S.t('contact_whatsapp_msg')
        .replaceAll('{name}', name)
        .replaceAll('{amount}', '${balance.toStringAsFixed(0)} ${S.t('misc_currency')}');
    final url = Uri.parse('https://wa.me/$cleanedPhone?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _sendSMS(String phone, String name, double balance) async {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.t('contact_no_phone')), backgroundColor: Colors.orange),
      );
      return;
    }
    final cleanedPhone = _cleanPhone(phone);
    final message = S.t('contact_sms_msg')
        .replaceAll('{name}', name)
        .replaceAll('{amount}', '${balance.toStringAsFixed(0)} ${S.t('misc_currency')}');
    final url = Uri.parse('sms:$cleanedPhone?body=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _searchCtrl.text.isEmpty ? _debts : _debts.where((d) => (d['full_name'] ?? '').toString().toLowerCase().contains(_searchCtrl.text.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(title: Text(S.t('nav_debt_recovery')), backgroundColor: Colors.indigo[900], foregroundColor: Colors.white),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(hintText: S.t('cust_search_hint'), prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator()) : filtered.isEmpty
            ? Center(child: Text(S.t('label_no_data')))
            : ListView.builder(padding: const EdgeInsets.all(8), itemCount: filtered.length, itemBuilder: (_, i) {
                final d = filtered[i];
                final bal = (d['balance'] as num?)?.toDouble() ?? 0;
                return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
                  leading: CircleAvatar(child: Text(((d['full_name'] as String?)?[0] ?? '?').toUpperCase())),
                  title: Text(d['full_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${S.t('pos_credit')}: ${bal.toStringAsFixed(0)} ${S.t('misc_currency')}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chat, color: Colors.green, size: 20),
                        tooltip: 'WhatsApp',
                        onPressed: () => _sendWhatsApp(d['phone'], d['full_name'], bal),
                      ),
                      IconButton(
                        icon: const Icon(Icons.sms, color: Colors.blue, size: 20),
                        tooltip: 'SMS',
                        onPressed: () => _sendSMS(d['phone'], d['full_name'], bal),
                      ),
                      IconButton(
                        icon: const Icon(Icons.payments, color: Colors.green, size: 20),
                        onPressed: () => _recordPayment(d),
                      ),
                    ],
                  ),
                ));
              }),
        ),
      ]),
    );
  }
}
