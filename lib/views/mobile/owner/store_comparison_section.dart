import 'package:flutter/material.dart';
import '../../../core/app_strings.dart';

class StoreComparisonSection extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const StoreComparisonSection({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        _sectionHeader(),
        const SizedBox(height: 8),
        _buildCard(),
      ],
    );
  }

  Widget _sectionHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.compare_arrows, color: Colors.teal, size: 20),
          const SizedBox(width: 8),
          Text(S.t('owner_store_comp_today'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
        ],
      ),
    );
  }

  Widget _buildCard() {
    final headers = ['Magasin', 'Revenu', 'Dépenses', 'Profit'];
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: headers.map((h) => Expanded(
                child: Text(h,
                    style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
              )).toList(),
            ),
            const Divider(height: 1),
            ...data.map((s) {
              final rev = (s['total_revenue'] as num?)?.toDouble() ?? 0;
              final exp = (s['total_expenses'] as num?)?.toDouble() ?? 0;
              final profit = (s['net_profit'] as num?)?.toDouble() ?? 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: Text(s['store_name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                    Expanded(child: Text('${rev.toStringAsFixed(0)} ${S.t('misc_currency')}',
                        style: const TextStyle(color: Colors.blue, fontSize: 12), textAlign: TextAlign.center)),
                    Expanded(child: Text('${exp.toStringAsFixed(0)} ${S.t('misc_currency')}',
                        style: const TextStyle(color: Colors.orange, fontSize: 12), textAlign: TextAlign.center)),
                    Expanded(child: Text('${profit.toStringAsFixed(0)} ${S.t('misc_currency')}',
                        style: TextStyle(color: profit >= 0 ? Colors.green : Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.end)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
