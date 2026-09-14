import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';
import 'package:mira_finance_tracker/classes/bank_account/CurrentAccount.dart';
import 'package:mira_finance_tracker/classes/subjects/CounterParty.dart';
import 'package:mira_finance_tracker/classes/time_management/DurationType.dart';
import 'package:mira_finance_tracker/classes/periodic_transactions/PeriodicTransaction.dart';
import 'package:mira_finance_tracker/classes/periodic_transactions/PeriodicIncome.dart';
import 'package:mira_finance_tracker/classes/periodic_transactions/Domiciliation.dart';
import 'package:mira_finance_tracker/classes/time_management/PeriodicAccountDuration.dart';
import 'package:mira_finance_tracker/frontend/templates/ActionOperationPage.dart';
import 'package:mira_finance_tracker/frontend/single_elements/UniqueNameField.dart';

/// Shared form to create a periodic transaction coming from a
/// counterparty (periodic income or domiciliation), built on top of
/// [ActionOperationPage]. Both share the exact same fields
/// (PeriodicTransaction) plus a mandatory counterparty, and only apply
/// to current accounts, so this widget is parametrized with labels and
/// the actual save logic, keeping both pages visually and structurally
/// identical -- the same approach used by PeriodicBillingFormPage for
/// cashbacks and bank fees.
class PeriodicTransactionFormPage extends StatelessWidget {
  final String title;
  final String nameLabel;
  final UserDatabaseWrapper database;
  final Type classRequested;

  const PeriodicTransactionFormPage({
    super.key,
    required this.title,
    required this.nameLabel,
    required this.database,
    required this.classRequested,
  });

  // these operations only apply to current accounts
  Future<List<CurrentAccount>> _loadAccounts() async {
    return (await database.getCurrentAccounts()).where((account) => account.isActive).toList();
  }

  Future<List<CounterParty>> _loadCounterParties() async {
    return await database.getCounterParties();
  }

  Future<bool> _isNameAvailable(String name, CurrentAccount account) async {
    List<PeriodicTransaction> transactions = [];
    // NOTE: adjust the method names below to match your
    // UserDatabaseWrapper API.
    if (classRequested == PeriodicIncome) {
      transactions = await database.getAccountPeriodicIncomes(account);
    } else {
      transactions = await database.getAccountDomiciliations(account);
    }

    return !transactions.any(
      (transaction) => transaction.name.toLowerCase() == name.toLowerCase(),
    );
  }

  Future<PeriodicTransaction> _saveTransaction(
    BuildContext context,
    CurrentAccount account,
    String name,
    CounterParty counterParty,
    double amount,
    String? description,
    DurationType frequency,
    int dayOfMonth,
    int? monthOfYear,
    DateTime startingDate,
    double fee,
  ) async {
    PeriodicTransaction transaction; // declare variable for the future object
    if (classRequested == PeriodicIncome) {
      transaction = PeriodicIncome(
        name,
        amount,
        PeriodicAccountDuration(
          startingDate,
          frequency,
          dayOfMonth,
          monthOfYear: monthOfYear,
        ),
        counterParty,
        description: description,
      );
      // NOTE: adjust the method name below to match your
      // UserDatabaseWrapper API.
      await database.saveAccountPeriodicIncome(
        account,
        transaction as PeriodicIncome,
      );
    } else {
      transaction = Domiciliation(
        name,
        amount,
        PeriodicAccountDuration(
          startingDate,
          frequency,
          dayOfMonth,
          monthOfYear: monthOfYear,
        ),
        counterParty,
        description: description,
        fee: fee,
      );
      
      await database.saveAccountDomiciliation(
        account,
        transaction as Domiciliation,
      );
    }

    return transaction;
  }

  @override
  Widget build(BuildContext context) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final feeController = TextEditingController(text: '0');
    final descriptionController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final dateFormat = DateFormat('dd/MM/yyyy');

    bool nameAvailable = false;
    CurrentAccount? selectedAccount;
    CounterParty? selectedCounterParty;
    DurationType frequency = DurationType.monthly;
    int dayOfMonth = 1;
    int monthOfYear = 1;
    DateTime startingDate = DateTime.now();

    return ActionOperationPage(
      title: title,
      formKey: formKey,
      inputBuilder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => Form(
          key: formKey,
          child: Column(
            children: [
              // --- ACCOUNT SELECTION (this operation only applies to current accounts) ---
              FutureBuilder<List<CurrentAccount>>(
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
                  return DropdownButtonFormField<CurrentAccount>(
                    value: selectedAccount,
                    decoration: const InputDecoration(
                      labelText: 'Conto corrente',
                    ),
                    items: accounts
                        .map(
                          (account) => DropdownMenuItem(
                            value: account,
                            child: Text(account.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setLocalState(() => selectedAccount = value),
                    validator: (value) =>
                        value == null ? 'Seleziona un conto corrente' : null,
                  );
                },
              ),
              const SizedBox(height: 16),

              /* make the other fields appear only 
              when the account has been selected */
              if (selectedAccount != null) ...[
                UniqueNameField(
                  controller: nameController,
                  label: 'Nome $nameLabel',
                  checkAvailability: (name) =>
                      _isNameAvailable(name, selectedAccount!),
                  onAvailabilityChanged: (available) =>
                      nameAvailable = available,
                ),
                const SizedBox(height: 16),

                // --- COUNTERPARTY (required for both periodic incomes and domiciliations) ---
                FutureBuilder<List<CounterParty>>(
                  future: _loadCounterParties(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.teal),
                        ),
                      );
                    }

                    final counterParties = snapshot.data ?? [];
                    return DropdownButtonFormField<CounterParty>(
                      value: selectedCounterParty,
                      decoration: const InputDecoration(
                        labelText: 'Controparte',
                      ),
                      items: counterParties
                          .map(
                            (counterParty) => DropdownMenuItem(
                              value: counterParty,
                              child: Text(counterParty.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setLocalState(() => selectedCounterParty = value),
                      validator: (value) =>
                          value == null ? 'Seleziona una controparte' : null,
                    );
                  },
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
                    final parsed = double.tryParse(value.replaceAll(',', '.'));
                    if (parsed == null || parsed < 0)
                      return 'Inserisci un importo valido';
                    return null;
                  },
                ),

                // --- FEE (only meaningful for domiciliations) ---
                if (classRequested == Domiciliation) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: feeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+[.,]?\d{0,2}'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Commissione (opzionale)',
                      prefixIcon: Icon(Icons.euro, color: Colors.teal),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return null;
                      final parsed = double.tryParse(
                        value.replaceAll(',', '.'),
                      );
                      if (parsed == null || parsed < 0)
                        return 'Inserisci un importo valido';
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),

                TextFormField(
                  controller: descriptionController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Descrizione (opzionale)',
                  ),
                ),
                const SizedBox(height: 24),

                // --- RECURRENCE ---
                DropdownButtonFormField<DurationType>(
                  value: frequency,
                  decoration: const InputDecoration(labelText: 'Ricorrenza'),
                  items: DurationType.values
                      .where(
                        (durationType) =>
                            durationType != DurationType.atMaturity,
                      )
                      .map(
                        (durationType) => DropdownMenuItem<DurationType>(
                          value: durationType,
                          child: Text(durationType.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setLocalState(
                    () => frequency = value ?? DurationType.monthly,
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  initialValue: dayOfMonth.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Giorno del mese',
                  ),
                  onChanged: (value) {
                    final parsed = int.tryParse(value);
                    if (parsed != null) dayOfMonth = parsed;
                  },
                  validator: (value) {
                    final parsed = int.tryParse(value ?? '');
                    if (parsed == null || parsed < 1 || parsed > 31)
                      return 'Inserisci un giorno tra 1 e 31';
                    return null;
                  },
                ),

                if (frequency.index >= DurationType.annual.index) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: monthOfYear,
                    decoration: const InputDecoration(labelText: 'Mese'),
                    items: List.generate(12, (index) => index + 1)
                        .map(
                          (month) => DropdownMenuItem(
                            value: month,
                            child: Text(
                              DateFormat.MMMM(
                                'it_IT',
                              ).format(DateTime(2024, month)),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setLocalState(() => monthOfYear = value ?? 1),
                  ),
                ],
                const SizedBox(height: 16),

                // --- STARTING DATE ---
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: startingDate,
                      firstDate: DateTime(1970),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null)
                      setLocalState(() => startingDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data di inizio',
                      prefixIcon: Icon(
                        Icons.calendar_today,
                        color: Colors.teal,
                      ),
                    ),
                    child: Text(dateFormat.format(startingDate)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      onConfirm: (context) async {
        if (!nameAvailable ||
            selectedAccount == null ||
            selectedCounterParty == null)
          return;

        PeriodicTransaction periodicTransaction = await _saveTransaction(
          context,
          selectedAccount!,
          nameController.text.trim(),
          selectedCounterParty!,
          double.parse(amountController.text.trim().replaceAll(',', '.')),
          descriptionController.text.trim().isEmpty
              ? null
              : descriptionController.text.trim(),
          frequency,
          dayOfMonth,
          frequency.index >= DurationType.annual.index ? monthOfYear : null,
          startingDate,
          classRequested == Domiciliation
              ? (double.tryParse(
                      feeController.text.trim().replaceAll(',', '.'),
                    ) ??
                    0)
              : 0,
        );

        if (context.mounted) {
          Navigator.pop(context, periodicTransaction);
        }
      },
    );
  }
}