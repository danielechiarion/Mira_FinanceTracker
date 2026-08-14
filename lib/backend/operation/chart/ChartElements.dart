import 'package:flutter/material.dart';

/// A single "slice" of the net worth pie chart:
/// the weight of an account (or institution) relative to the total.
class AccountShare {
  final String label;   // name of the bank account or the institute
  final double amount;  // amount which represents
  late Color color;
 
  AccountShare({
    required this.label,
    required this.amount,
    required int index,
  }) : color = _colorForIndex(index);

  /// Generates a color for the [i]-th index of the pie chart.
  ///
  /// Instead of picking from a fixed list (which repeats after N elements),
  /// it constructs HSL colors by distributing the hue using the "golden angle"
  /// (~137.5°): this is the same technique used to distribute points evenly
  /// on a circle, so even with many accounts, the colors remain
  /// visually distinct from each other instead of clustering in one area.
  /// Saturation and lightness are slightly varied every 2 hue revolutions
  /// to further differentiate "adjacent" accounts when the list is very long.
  static Color _colorForIndex(int i) {
    const double goldenAngle = 137.508;
    final hue = (i * goldenAngle) % 360;
    final cycle = i ~/ (360 / goldenAngle).round(); // how many times we spin
    final saturation = 0.55 + 0.10 * (cycle % 3); 
    final lightness = 0.45 + 0.08 * ((cycle + 1) % 2); // change slightly
    return HSLColor.fromAHSL(1.0, hue, saturation.clamp(0.0, 1.0), lightness.clamp(0.0, 1.0)).toColor();
  }
}
 
/// A data point for the monthly income/expense trend (bar chart).
class MonthlyFlow {
  final String monthLabel; // eg. 'Gen', 'Feb', 'Mar'...
  final double income;
  final double outcome;
 
  const MonthlyFlow({
    required this.monthLabel,
    required this.income,
    required this.outcome,
  });
}