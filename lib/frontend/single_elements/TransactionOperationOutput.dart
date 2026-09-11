import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Reusable presentation model for a movement returned by a custom check.
/// It can later be mapped directly from BankTransaction, Income, and Outcome.
class TransactionOperationOutput {
  static final _formatter = NumberFormat.currency(locale: 'it_IT', symbol: '€');
  final String reference;
  final String accountName;
  final String? financialService;
  final String? counterParty;
  final double amount;
  final bool isIncome;
  final String category;
  final DateTime executionDate;
  final DateTime accountingDate;

  const TransactionOperationOutput({
    required this.reference,
    required this.accountName,
    this.financialService,
    this.counterParty,
    required this.amount,
    required this.isIncome,
    required this.category,
    required this.executionDate,
    required this.accountingDate,
  });

  Widget build() {
    final color = isIncome ? Colors.green : Colors.red;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(
          isIncome ? Icons.arrow_downward : Icons.arrow_upward,
          color: color,
          size: 18,
        ),
      ),
      title: Text(
        reference,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '$accountName • $category\n'
        'Controparte: ${counterParty ?? '-'}\n'
        'Esecuzione: ${DateFormat('dd/MM/yyyy').format(executionDate)} • '
        'Contabile: ${DateFormat('dd/MM/yyyy').format(accountingDate)}',
      ),
      isThreeLine: true,
      trailing: Text(
        '${isIncome ? '+' : '-'}${_formatter.format(amount)}',
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}