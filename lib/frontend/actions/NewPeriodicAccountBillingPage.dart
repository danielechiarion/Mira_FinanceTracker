import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';
import 'package:mira_finance_tracker/classes/bank_account/BankAccount.dart';
import 'package:mira_finance_tracker/classes/bank_account/Card.dart'
    as card_account;
import 'package:mira_finance_tracker/classes/bank_account/CurrentAccount.dart';
import 'package:mira_finance_tracker/classes/bank_account/SavingsAccount.dart';
import 'package:mira_finance_tracker/classes/time_management/DurationType.dart';
import 'package:mira_finance_tracker/classes/periodic_transactions/PeriodicAccountBillings.dart';
import 'package:mira_finance_tracker/classes/periodic_transactions/Cashback.dart';
import 'package:mira_finance_tracker/classes/periodic_transactions/BankFee.dart';
import 'package:mira_finance_tracker/classes/time_management/PeriodicAccountDuration.dart';
import 'package:mira_finance_tracker/frontend/templates/ActionOperationPage.dart';
import 'package:mira_finance_tracker/frontend/single_elements/UniqueNameField.dart';

/// Shared form to create a periodic account billing (cashback or bank
/// fee), built on top of [ActionOperationPage]. Cashback and bank fees
/// share the exact same fields (PeriodiAccountBillings), so this widget
/// is parametrized with labels, icon, color and the actual save logic,
/// keeping both pages visually and structurally identical.
class PeriodicBillingFormPage extends StatelessWidget {
  final String title;
  final String nameLabel;
  final UserDatabaseWrapper database;
  final Type classRequested;

  const PeriodicBillingFormPage({
    super.key,
    required this.title,
    required this.nameLabel,
    required this.database,
    required this.classRequested,
  });

  Future<List<BankAccount>> _loadAccounts() async {
    return (await database.getBankAccounts()).where((account) => account.isActive).toList();
  }

  Future<bool> _isNameAvailable(String name, BankAccount account) async {
    List<PeriodicAccountBillings> billings = [];
    if (classRequested == Cashback) {
      billings = await database.getAccountCashbacks(account);
    } else {
      billings = await database.getAccountFees(account);
    }

    return !billings.any(
      (billing) => billing.name.toLowerCase() == name.toLowerCase(),
    );
  }

  String _accountTypeName(BankAccount account) {
    if (account is CurrentAccount) return 'conto corrente';
    if (account is SavingsAccount) return 'conto deposito';
    if (account is card_account.Card) return 'carta';
    return 'account';
  }

  Future<PeriodicAccountBillings> _saveBilling(
    BuildContext context,
    BankAccount account,
    String name,
    double amount,
    String? description,
    DurationType frequency,
    int dayOfMonth,
    int? monthOfYear,
    DateTime startingDate,
  ) async {
    PeriodicAccountBillings billing; // declare variable for the future object
    if (classRequested == Cashback) {
      billing = Cashback(
        name,
        amount,
        PeriodicAccountDuration(
          startingDate,
          frequency,
          dayOfMonth,
          monthOfYear: monthOfYear,
        ),
        description: description,
      );
      await database.saveAccountCashback(account, billing as Cashback);
    } else {
      billing = BankFee(
        name,
        amount,
        PeriodicAccountDuration(
          startingDate,
          frequency,
          dayOfMonth,
          monthOfYear: monthOfYear,
        ),
        description: description,
      );
      await database.saveAccountFee(account, billing as BankFee);
    }

    return billing;
  }

  @override
  Widget build(BuildContext context) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final dateFormat = DateFormat('dd/MM/yyyy');

    bool nameAvailable = false;
    BankAccount? selectedAccount;
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
              // --- ACCOUNT SELECTION (this billing applies to a single account) ---
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
                    onChanged: (value) =>
                        setLocalState(() => selectedAccount = value),
                    validator: (value) =>
                        value == null ? 'Seleziona un conto' : null,
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
        if (!nameAvailable || selectedAccount == null) return;

        PeriodicAccountBillings billing = await _saveBilling(
          context,
          selectedAccount!,
          nameController.text.trim(),
          double.parse(amountController.text.trim().replaceAll(',', '.')),
          descriptionController.text.trim().isEmpty
              ? null
              : descriptionController.text.trim(),
          frequency,
          dayOfMonth,
          frequency.index >= DurationType.annual.index ? monthOfYear : null,
          startingDate,
        );

        if (context.mounted) {
          Navigator.pop(context, billing);
        }
      },
    );
  }
}