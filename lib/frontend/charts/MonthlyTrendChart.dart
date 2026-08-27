import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:mira_finance_tracker/backend/operation/chart/ChartElements.dart';
import 'package:mira_finance_tracker/frontend/charts/EmptyChartPlaceholder.dart';

/// Grouped bar chart: compares income (green) and expenses (red)
/// month by month. Complements the pie chart with a "over time" view.
class MonthlyTrendChart extends StatelessWidget {
  final List<MonthlyFlow> data;

  const MonthlyTrendChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final maxValue = data
        .expand((m) => [m.income, m.outcome])
        .fold<double>(0, (max, v) => v > max ? v : max);

    if (data.isEmpty || maxValue <= 0) {
      return const EmptyChartPlaceholder(
        icon: Icons.show_chart_rounded,
        message: 'Nessun movimento registrato in questo periodo.',
      );
    }
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              maxY: maxValue == 0 ? 100 : maxValue * 1.2,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= data.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(data[index].monthLabel, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      );
                    },
                  ),
                ),
              ),
              barGroups: List.generate(data.length, (index) {
                final flow = data[index];
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(toY: flow.income, color: Colors.green, width: 10, borderRadius: BorderRadius.circular(4)),
                    BarChartRodData(toY: flow.outcome, color: Colors.red, width: 10, borderRadius: BorderRadius.circular(4)),
                  ],
                  barsSpace: 4,
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legendDot(Colors.green, 'Entrate'),
            const SizedBox(width: 20),
            _legendDot(Colors.red, 'Uscite'),
          ],
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}