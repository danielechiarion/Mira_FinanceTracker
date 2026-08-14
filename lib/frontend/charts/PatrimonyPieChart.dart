import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:mira_finance_tracker/backend/operation/chart/ChartElements.dart';
import 'package:mira_finance_tracker/frontend/charts/EmptyChartPlaceholder.dart';

/// Pie chart showing how total assets are distributed
/// across various accounts/institutions (explicitly requested for the Home Page).
class PatrimonyPieChart extends StatelessWidget {
  final List<AccountShare> distribution;

  const PatrimonyPieChart({super.key, required this.distribution});

  @override
  Widget build(BuildContext context) {
    if (distribution.isEmpty) {
      return const EmptyChartPlaceholder(
        icon: Icons.pie_chart_outline_rounded,
        message: 'Nessun conto con saldo disponibile.\nAggiungi un conto per vedere qui la distribuzione del tuo patrimonio.',
      );
    }

    final total = distribution.fold<double>(0, (sum, e) => sum + e.amount);

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 48,
              sections: distribution.map((share) {
                final percent = total == 0 ? 0.0 : (share.amount / total * 100);
                return PieChartSectionData(
                  value: share.amount,
                  color: share.color,
                  radius: 58,
                  title: '${percent.toStringAsFixed(0)}%',
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: distribution.map((share) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: share.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(share.label, style: const TextStyle(fontSize: 13)),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}