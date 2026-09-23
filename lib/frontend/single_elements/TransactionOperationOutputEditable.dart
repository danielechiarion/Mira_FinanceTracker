import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:mira_finance_tracker/classes/transaction/BankTransaction.dart';
import 'package:mira_finance_tracker/classes/transaction/Income.dart';
import 'package:mira_finance_tracker/classes/transaction/Outcome.dart';
import 'package:mira_finance_tracker/classes/subjects/CounterParty.dart';
import 'package:mira_finance_tracker/classes/bank_account/BankAccount.dart';
import 'package:mira_finance_tracker/classes/bank_account/CurrentAccount.dart';
import 'package:mira_finance_tracker/classes/bank_account/SavingsAccount.dart';

import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';

/// Editable version of [TransactionOperationOutput] that allows the user
/// to modify or delete a transaction. It only needs the original
/// [transaction] (which already carries all its presentation data) and the
/// [account] it belongs to.
class TransactionOperationOutputEditable extends StatefulWidget {
  /// The original transaction object (Income or Outcome).
  final BankTransaction transaction;

  /// The account to which the transaction belongs.
  final BankAccount account;

  /// Callback invoked to reload the page after a change.
  final Future<void> Function() updatePage;

  /// Database wrapper used to persist changes.
  final UserDatabaseWrapper database;

  TransactionOperationOutputEditable({
    super.key,
    required this.transaction,
    required this.account,
    required this.updatePage,
    required this.database,
  }) {
    account.addRawTransactions([transaction]); // add the transaction to the list of transactions to make operations
  }

  @override
  State<TransactionOperationOutputEditable> createState() =>
      _TransactionOperationOutputEditableState();
}

class _TransactionOperationOutputEditableState
    extends State<TransactionOperationOutputEditable> {
  static final _formatter =
      NumberFormat.currency(locale: 'it_IT', symbol: '€');

  /// Whether the underlying transaction is an income.
  bool get _isIncome => widget.transaction is Income;

  /// Human readable category label of the transaction.
  String get _categoryLabel {
    final transaction = widget.transaction;
    if (transaction is Income) {
      return transaction.category.name;
    } else if (transaction is Outcome) {
      return transaction.category.name;
    }
    return '';
  }

  /// Name of the counterparty, if any.
  String? get _counterPartyName => widget.transaction.counterParty?.name;

  @override
  Widget build(BuildContext context) {
    final transaction = widget.transaction;
    final color = _isIncome ? Colors.green : Colors.red;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(
          _isIncome ? Icons.arrow_downward : Icons.arrow_upward,
          color: color,
          size: 18,
        ),
      ),
      title: Text(
        transaction.reference,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${widget.account.name} • $_categoryLabel\n'
        'Controparte: ${_counterPartyName ?? '-'}\n'
        'Esecuzione: '
        '${DateFormat('dd/MM/yyyy').format(transaction.executionDate)} • '
        'Contabile: '
        '${DateFormat('dd/MM/yyyy').format(transaction.accountingDate)}',
      ),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_isIncome ? '+' : '-'}${_formatter.format(transaction.amount)}',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            onPressed: () => _showEditDialog(context),
            tooltip: 'Modifica',
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 20),
            onPressed: () => _showDeleteDialog(context),
            tooltip: 'Elimina',
          ),
        ],
      ),
    );
  }

  /// Returns the category values selectable for [account], based on the
  /// account's runtime type (CurrentAccount / SavingsAccount / Card) and
  /// on whether this page is handling an [Income] or an [Outcome].
  List<String> _categoriesForAccount(BankAccount account) {
    if (widget.transaction is Income) {
      if (account is CurrentAccount) {
        return IncomeCategory.getCurrentAccountOperations()
            .map((category) => category.name)
            .toList();
      } else if (account is SavingsAccount) {
        return IncomeCategory.getSavingsAccountOperations()
            .map((category) => category.name)
            .toList();
      } else {
        return IncomeCategory.getCardOperations()
            .map((category) => category.name)
            .toList();
      }
    } else {
      if (account is CurrentAccount) {
        return OutcomeCategory.getCurrentAccountOperations()
            .map((category) => category.name)
            .toList();
      } else if (account is SavingsAccount) {
        return OutcomeCategory.getSavingsAccountOperations()
            .map((category) => category.name)
            .toList();
      } else {
        return OutcomeCategory.getCardOperations()
            .map((category) => category.name)
            .toList();
      }
    }
  }

  /// Shows a dialog to edit the transaction.
  /// * [context] the build context used to show the dialog.
  Future<void> _showEditDialog(BuildContext context) async {
    final updatedTransaction = await showDialog<BankTransaction>(
      context: context,
      builder: (context) => EditTransactionDialog(
        transaction: widget.transaction,
        availableCategories: _categoriesForAccount(widget.account),
        database: widget.database,
      ),
    );
    if (updatedTransaction == null || !mounted) return;

    setState(() {
      // Update the in-memory transaction of the account.
      widget.account.replaceTransaction(updatedTransaction);
    });
    /* update also the database with the transactions and the balance */
    await widget.database.updateTransaction(updatedTransaction);
    await widget.database.updateBankAccountBalance(widget.account);

    await widget.updatePage();
  }

  /// Shows a confirmation dialog to delete the transaction.
  /// * [context] the build context used to show the dialog.
  Future<void> _showDeleteDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma eliminazione'),
        content: Text(
          'Sei sicuro di voler eliminare il movimento '
          '"${widget.transaction.reference}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      // Remove the transaction from the in-memory account.
      widget.account.removeTransaction(widget.transaction);
    });
    /* update also the database with the transactions and the balance */
    await widget.database.deleteTransaction(widget.transaction);
    await widget.database.updateBankAccountBalance(widget.account);
    await widget.updatePage();
  }
}

/// Dialog for editing a transaction.
/// It allows modifying all fields and returns the updated transaction.
class EditTransactionDialog extends StatefulWidget {
  final BankTransaction transaction;
  final List<String> availableCategories;
  final UserDatabaseWrapper database;

  const EditTransactionDialog({
    super.key,
    required this.transaction,
    required this.availableCategories,
    required this.database,
  });

  @override
  State<EditTransactionDialog> createState() => _EditTransactionDialogState();
}

class _EditTransactionDialogState extends State<EditTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _referenceController;
  late TextEditingController _amountController;
  late TextEditingController _counterPartyController;
  late DateTime _executionDate;
  late DateTime _accountingDate;
  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    _referenceController = TextEditingController(text: transaction.reference);
    _amountController =
        TextEditingController(text: transaction.amount.toString());
    _counterPartyController =
        TextEditingController(text: transaction.counterParty?.name ?? '');
    _executionDate = transaction.executionDate;
    _accountingDate = transaction.accountingDate;
    if (transaction is Income) {
      _selectedCategory = transaction.category.name;
    } else if (transaction is Outcome) {
      _selectedCategory = transaction.category.name;
    } else {
      _selectedCategory = widget.availableCategories.first;
    }
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _amountController.dispose();
    _counterPartyController.dispose();
    super.dispose();
  }

  /// Checks if the currently selected category requires a counterparty.
  bool _isCounterPartyRequired() {
    if (widget.transaction is Income) {
      final category = IncomeCategory.values.firstWhere(
        (e) => e.name == _selectedCategory,
        orElse: () => IncomeCategory.other,
      );
      return category.counterPartyRequired;
    } else if (widget.transaction is Outcome) {
      final category = OutcomeCategory.values.firstWhere(
        (e) => e.name == _selectedCategory,
        orElse: () => OutcomeCategory.other,
      );
      return category.counterPartyRequired;
    }
    return false;
  }

  Future<void> _pickDate(bool isExecutionDate) async {
    final initialDate = isExecutionDate ? _executionDate : _accountingDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isExecutionDate) {
          _executionDate = picked;
        } else {
          _accountingDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final reference = _referenceController.text;
    final amount = double.parse(_amountController.text);
    final counterPartyName = _counterPartyController.text.trim();

    // Reuse the original counterparty when the name has not changed,
    // otherwise look it up in the database to keep the same identity.
    CounterParty? counterParty;
    final originalName = widget.transaction.counterParty?.name;
    if (counterPartyName.isNotEmpty) {
      if (counterPartyName == originalName) {
        counterParty = widget.transaction.counterParty;
      } else {
        // Placeholder for backend lookup.
        // Fetch the existing counterparty from the database by name
        // (or create it if the backend supports upsert).
        counterParty =
            await widget.database.findCounterPartyByName(counterPartyName);
      }
    }

    BankTransaction updatedTransaction;
    if (widget.transaction is Income) {
      final category = IncomeCategory.values.firstWhere(
        (e) => e.name == _selectedCategory,
        orElse: () => IncomeCategory.other,
      );
      updatedTransaction = Income(
        category,
        reference,
        amount,
        _executionDate,
        id: widget.transaction.id,
        counterParty: counterParty,
        accountingDate: _accountingDate,
      );
    } else if (widget.transaction is Outcome) {
      final category = OutcomeCategory.values.firstWhere(
        (e) => e.name == _selectedCategory,
        orElse: () => OutcomeCategory.other,
      );
      updatedTransaction = Outcome(
        category,
        reference,
        amount,
        _executionDate,
        id: widget.transaction.id,
        counterParty: counterParty,
        accountingDate: _accountingDate,
      );
    } else {
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(updatedTransaction);
  }

  @override
  Widget build(BuildContext context) {
    final counterPartyRequired = _isCounterPartyRequired();
    return AlertDialog(
      title: const Text('Modifica movimento'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _referenceController,
                decoration: const InputDecoration(labelText: 'Riferimento'),
                validator: (value) => value == null || value.isEmpty
                    ? 'Inserisci un riferimento'
                    : null,
              ),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Importo'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Inserisci un importo';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Importo non valido';
                  }
                  return null;
                },
              ),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Categoria'),
                items: widget.availableCategories
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                  });
                },
              ),
              TextFormField(
                controller: _counterPartyController,
                decoration: InputDecoration(
                  labelText: 'Controparte',
                  enabled: counterPartyRequired,
                ),
                validator: (value) {
                  if (counterPartyRequired &&
                      (value == null || value.isEmpty)) {
                    return 'Controparte richiesta';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Esecuzione: '
                      '${DateFormat('dd/MM/yyyy').format(_executionDate)}',
                    ),
                  ),
                  TextButton(
                    onPressed: () => _pickDate(true),
                    child: const Text('Cambia'),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Contabile: '
                      '${DateFormat('dd/MM/yyyy').format(_accountingDate)}',
                    ),
                  ),
                  TextButton(
                    onPressed: () => _pickDate(false),
                    child: const Text('Cambia'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        TextButton(
          onPressed: _save,
          child: const Text('Salva'),
        ),
      ],
    );
  }
}