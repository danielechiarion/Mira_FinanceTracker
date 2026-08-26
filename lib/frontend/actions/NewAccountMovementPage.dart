import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';
import 'package:mira_finance_tracker/classes/bank_account/BankAccount.dart';
import 'package:mira_finance_tracker/classes/bank_account/Card.dart'
    as card_account;
import 'package:mira_finance_tracker/classes/bank_account/CurrentAccount.dart';
import 'package:mira_finance_tracker/classes/bank_account/SavingsAccount.dart';
import 'package:mira_finance_tracker/classes/subjects/CounterParty.dart';
import 'package:mira_finance_tracker/classes/transaction/Income.dart';
import 'package:mira_finance_tracker/classes/transaction/Outcome.dart';
import 'package:mira_finance_tracker/frontend/templates/ActionOperationPage.dart';

/// Shared form to register a bank movement (income or outcome), built
/// on top of [ActionOperationPage]. Incomes and outcomes share the same
/// base fields (account, category, reference, amount and dates), so
/// this widget is parametrized with labels and the actual save logic,
/// keeping both pages visually and structurally identical -- exactly
/// the same approach used by PeriodicBillingFormPage for cashbacks and
/// bank fees.
class MovementFormPage extends StatelessWidget {
  final String title;
  final String referenceLabel;
  final UserDatabaseWrapper database;
  final Type classRequested; // Income or Outcome

  const MovementFormPage({
    super.key,
    required this.title,
    required this.referenceLabel,
    required this.database,
    required this.classRequested,
  });

  Future<List<BankAccount>> _loadAccounts() async {
    return await database.getBankAccounts();
  }

  /// Method to load the counterparties list from the database
  Future<List<CounterParty>> _loadCounterParties() async {
    return await database.getCounterParties();
  }

  String _accountTypeName(BankAccount account) {
    if (account is CurrentAccount) return 'conto corrente';
    if (account is SavingsAccount) return 'conto deposito';
    if (account is card_account.Card) return 'carta';
    return 'account';
  }

  /// Returns the category values selectable for [account], based on the
  /// account's runtime type (CurrentAccount / SavingsAccount / Card) and
  /// on whether this page is handling an [Income] or an [Outcome]
  /// (check `classRequested` to tell them apart).
  List<dynamic> _categoriesForAccount(BankAccount account) {
    if (classRequested == Income) {
      if (account is CurrentAccount) {
        return IncomeCategory.getCurrentAccountOperations();
      } else if (account is SavingsAccount) {
        return IncomeCategory.getSavingsAccountOperations();
      } else {
        return IncomeCategory.getCardOperations();
      }
    } else {
      if (account is CurrentAccount) {
        return OutcomeCategory.getCurrentAccountOperations();
      } else if (account is SavingsAccount) {
        return OutcomeCategory.getSavingsAccountOperations();
      } else {
        return OutcomeCategory.getCardOperations();
      }
    }
  }

  /// Returns the label to show in the dropdown for [category].
  String _categoryLabel(dynamic category) {
    return category.name;
  }

  Future<void> _saveMovement(
    BuildContext context,
    BankAccount account,
    dynamic category,
    String reference,
    double amount,
    DateTime executionDate,
    DateTime? accountingDate,
    CounterParty? counterParty,
  ) async {
    if (classRequested == Income) {
      final movement = Income(
        category,
        reference,
        amount,
        executionDate,
        counterParty: counterParty,
        accountingDate: accountingDate,
      );

      await database.saveTransactions(account, [movement]);
    } else {
      final movement = Outcome(
        category,
        reference,
        amount,
        executionDate,
        counterParty: counterParty,
        accountingDate: accountingDate,
      );

      await database.saveTransactions(account, [movement]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final referenceController = TextEditingController();
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final dateFormat = DateFormat('dd/MM/yyyy');

    BankAccount? selectedAccount;
    dynamic selectedCategory;
    DateTime executionDate = DateTime.now();
    DateTime? accountingDate;
    bool useCustomAccountingDate = false;
    CounterParty? selectedCounterParty;

    return ActionOperationPage(
      title: title,
      formKey: formKey,
      inputBuilder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => Form(
          key: formKey,
          child: Column(
            children: [
              // --- ACCOUNT SELECTION (this movement applies to a single account) ---
              FutureBuilder<List<BankAccount>>(
                future: _loadAccounts(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.teal),
                      ),
                    );
                  }

                  final accounts = snapshot.data ?? [];
                  return DropdownButtonFormField<BankAccount>(
                    value: selectedAccount,
                    decoration: const InputDecoration(labelText: 'Conto'),
                    items: accounts
                        .map(
                          (account) => DropdownMenuItem(
                            value: account,
                            child: Text(
                              '${account.name} (${_accountTypeName(account)})',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setLocalState(() {
                      selectedAccount = value;
                      // reset category and counterparty when account changes
                      selectedCategory = null;
                      selectedCounterParty = null;
                    }),
                    validator: (value) =>
                        value == null ? 'Seleziona un conto' : null,
                  );
                },
              ),
              const SizedBox(height: 16),

              /* make the other fields appear only
              when the account has been selected */
              if (selectedAccount != null) ...[
                // --- MOVEMENT CATEGORY (depends on the selected account type) ---
                DropdownButtonFormField<dynamic>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Tipologia'),
                  items: _categoriesForAccount(selectedAccount!)
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(_categoryLabel(category)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setLocalState(() {
                    selectedCategory = value;
                    // reset counterparty when category changes
                    selectedCounterParty = null;
                  }),
                  validator: (value) =>
                      value == null ? 'Seleziona una tipologia' : null,
                ),
                const SizedBox(height: 16),

                // --- COUNTERPARTY SELECTION ---
                // Required by some categories (when counterPartyRequired is true)
                if (selectedCategory != null &&
                    (selectedCategory.counterPartyRequired == true)) ...[
                  FutureBuilder<List<CounterParty>>(
                    future: _loadCounterParties(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.teal,
                            ),
                          ),
                        );
                      }

                      final counterParties = snapshot.data ?? [];
                      return DropdownButtonFormField<CounterParty>(
                        value: selectedCounterParty,
                        decoration:
                            const InputDecoration(labelText: 'Controparte'),
                        items: counterParties
                            .map(
                              (counterParty) => DropdownMenuItem(
                                value: counterParty,
                                child: Text(counterParty.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setLocalState(
                          () => selectedCounterParty = value,
                        ),
                        validator: (value) => value == null
                            ? 'Seleziona una controparte'
                            : null,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                TextFormField(
                  controller: referenceController,
                  decoration: InputDecoration(labelText: referenceLabel),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Il valore deve essere impostato'
                      : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+[.,]?\d{0,2}'),
                    ),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Importo',
                    prefixIcon: Icon(Icons.euro, color: Colors.teal),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Il valore deve essere impostato';
                    final parsed =
                        double.tryParse(value.replaceAll(',', '.'));
                    if (parsed == null || parsed < 0)
                      return 'Inserisci un importo valido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // --- EXECUTION DATE ---
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: executionDate,
                      firstDate: DateTime(1970),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null)
                      setLocalState(() => executionDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data di esecuzione',
                      prefixIcon: Icon(
                        Icons.calendar_today,
                        color: Colors.teal,
                      ),
                    ),
                    child: Text(dateFormat.format(executionDate)),
                  ),
                ),
                const SizedBox(height: 16),

                // --- OPTIONAL ACCOUNTING DATE (defaults to the execution date when left unset) ---
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: Colors.teal,
                  title: const Text('Data di contabilizzazione diversa'),
                  value: useCustomAccountingDate,
                  onChanged: (value) => setLocalState(() {
                    useCustomAccountingDate = value;
                    if (!value) accountingDate = null;
                  }),
                ),
                if (useCustomAccountingDate) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: accountingDate ?? executionDate,
                        firstDate: DateTime(1970),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null)
                        setLocalState(() => accountingDate = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Data di contabilizzazione',
                        prefixIcon: Icon(Icons.event, color: Colors.teal),
                      ),
                      child: Text(
                        accountingDate == null
                            ? 'Seleziona una data'
                            : dateFormat.format(accountingDate!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ],
          ),
        ),
      ),
      onConfirm: (context) async {
        if (selectedAccount == null || selectedCategory == null) return;

        // Ensure counterParty is selected if required by category
        if (selectedCategory.counterPartyRequired == true &&
            selectedCounterParty == null) {
          return;
        }

        await _saveMovement(
          context,
          selectedAccount!,
          selectedCategory,
          referenceController.text.trim(),
          double.parse(amountController.text.trim().replaceAll(',', '.')),
          executionDate,
          useCustomAccountingDate ? accountingDate : null,
          selectedCounterParty,
        );

        if (context.mounted) {
          Navigator.pop(context);
        }
      },
    );
  }
}