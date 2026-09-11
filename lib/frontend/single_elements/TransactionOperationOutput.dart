/// Reusable presentation model for a movement returned by a custom check.
/// It can later be mapped directly from BankTransaction, Income, and Outcome.
class TransactionOperatioOutput {
  final String reference;
  final String accountName;
  final String? financialService;
  final String? counterParty;
  final double amount;
  final bool isIncome;
  final String category;
  final DateTime executionDate;
  final DateTime accountingDate;

  const TransactionOperatioOutput({
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
}