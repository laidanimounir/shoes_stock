import 'package:flutter/material.dart';
import '../../../core/app_strings.dart';
import '../../../shared/utils/contact_utils.dart';

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
          onPressed: () => ContactUtils.sendWhatsApp(context, phone ?? '', name, balance),
        ),
        IconButton(
          icon: const Icon(Icons.sms, color: Colors.blue, size: 20),
          tooltip: 'SMS',
          onPressed: () => ContactUtils.sendSMS(context, phone ?? '', name, balance),
        ),
      ],
    );
  }
}
