import 'package:flutter/material.dart';
import '../../../core/app_strings.dart';

class KpiCardsSection extends StatelessWidget {
  final double salesToday;
  final double profitToday;
  final double customerDebt;
  final double supplierDebt;
  final double totalProfit;
  final double avgMargin;

  const KpiCardsSection({
    super.key,
    required this.salesToday,
    required this.profitToday,
    required this.customerDebt,
    required this.supplierDebt,
    required this.totalProfit,
    required this.avgMargin,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(child: _buildMetricCard(S.t('dash_revenue'), "${salesToday.toStringAsFixed(0)} ${S.t('misc_currency')}", Icons.point_of_sale, Colors.blue)),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard(S.t('dash_net_profit'), "+${profitToday.toStringAsFixed(0)} ${S.t('misc_currency')}", Icons.trending_up, Colors.green)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(child: _buildMetricCard(S.t('dash_customer_debt'), "${customerDebt.toStringAsFixed(0)} ${S.t('misc_currency')}", Icons.account_balance_wallet, Colors.orange)),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard(S.t('dash_supplier_debt'), "${supplierDebt.toStringAsFixed(0)} ${S.t('misc_currency')}", Icons.money_off, Colors.red)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(child: _buildMetricCard(S.t('dash_total_profit'), "${totalProfit.toStringAsFixed(0)} ${S.t('misc_currency')}", Icons.bar_chart, Colors.purple)),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard(S.t('dash_avg_margin'), "${avgMargin.toStringAsFixed(0)} ${S.t('misc_currency')}", Icons.pie_chart, Colors.teal)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        border: Border(bottom: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              CircleAvatar(radius: 4, backgroundColor: color),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
