import 'package:flutter/material.dart';

/// A single "slice" of the net worth pie chart:
/// the weight of an account (or institution) relative to the total.
class AccountShare {
  final String label;   // name of the bank account or the institute
  final double amount;  // amount which represents
  final Color color;
 
  const AccountShare({
    required this.label,
    required this.amount,
    required this.color,
  });
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