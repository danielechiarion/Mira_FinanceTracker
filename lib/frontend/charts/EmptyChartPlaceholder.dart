import 'package:flutter/material.dart';

/// Placeholder shown instead of a chart when there is not enough
/// data to display (no accounts, no transactions, all zero
/// balances...). Reusable by any Home chart (and in the future,
/// also by detail pages/Custom Check).
class EmptyChartPlaceholder extends StatelessWidget {
  final String message;
  final IconData icon;
  final double height;

  const EmptyChartPlaceholder({
    super.key,
    required this.message,
    this.icon = Icons.insert_chart_outlined_rounded,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}