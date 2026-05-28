import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/app_strings.dart';

class DebtorsSection extends StatelessWidget {
  final List<Map<String, dynamic>> debtors;

  const DebtorsSection({super.key, required this.debtors});

  @override
  Widget build(BuildContext context) {
    if (debtors.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        _buildSectionHeader(S.t('contact_debt_list_title'), Icons.people_outline, Colors.orange),
        _buildDebtorsList(context),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildDebtorsList(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: debtors.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final debtor = debtors[index];
          final name = debtor['full_name'] ?? '—';
          final phone = debtor['phone'] as String?;
          final balance = (debtor['balance'] as num?)?.toDouble() ?? 0;
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange[50],
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(color: Colors.orange[800], fontWeight: FontWeight.bold)),
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text("${balance.toStringAsFixed(0)} ${S.t('misc_currency')}",
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 12)),
            trailing: _buildContactButtons(context, phone, name, balance),
          );
        },
      ),
    );
  }

  Widget _buildContactButtons(BuildContext context, String? phone, String name, double balance) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chat, color: Colors.green, size: 20),
          tooltip: 'WhatsApp',
          onPressed: () {
            if (phone == null || phone.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(S.t('contact_no_phone')), backgroundColor: Colors.orange),
              );
              return;
            }
            _sendWhatsApp(name, phone, balance);
          },
        ),
        IconButton(
          icon: const Icon(Icons.sms, color: Colors.blue, size: 20),
          tooltip: 'SMS',
          onPressed: () {
            if (phone == null || phone.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(S.t('contact_no_phone')), backgroundColor: Colors.orange),
              );
              return;
            }
            _sendSMS(name, phone, balance);
          },
        ),
      ],
    );
  }

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

  Future<void> _sendWhatsApp(String name, String phone, double balance) async {
    final cleanedPhone = _cleanPhone(phone).replaceAll('+', '');
    final message = S.t('contact_whatsapp_msg')
        .replaceAll('{name}', name)
        .replaceAll('{amount}', '${balance.toStringAsFixed(0)} ${S.t('misc_currency')}');
    final url = Uri.parse('https://wa.me/$cleanedPhone?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _sendSMS(String name, String phone, double balance) async {
    final cleanedPhone = _cleanPhone(phone);
    final message = S.t('contact_sms_msg')
        .replaceAll('{name}', name)
        .replaceAll('{amount}', '${balance.toStringAsFixed(0)} ${S.t('misc_currency')}');
    final url = Uri.parse('sms:$cleanedPhone?body=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }
}
