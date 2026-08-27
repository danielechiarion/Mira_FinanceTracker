import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';
import 'package:mira_finance_tracker/classes/bank_account/BankAccount.dart';
import 'package:mira_finance_tracker/classes/bank_account/Card.dart'
    as card_account;
import 'package:mira_finance_tracker/classes/bank_account/CurrentAccount.dart';
import 'package:mira_finance_tracker/classes/bank_account/SavingsAccount.dart';
import 'package:mira_finance_tracker/backend/operation/finance/InternalTransfer.dart';
import 'package:mira_finance_tracker/frontend/templates/ActionOperationPage.dart';
import 'package:mira_finance_tracker/frontend/single_elements/Toast.dart';

/// Page to create an [InternalTransfer] between two bank accounts
/// belonging to the same user, built on top of [ActionOperationPage].
/// Reuses the same account-selection and money-field pattern already
/// used for movements and periodic billings, applied twice (starting
/// account / ending account, amount / fee).
class NewInternalTransferPage extends StatelessWidget {
  final UserDatabaseWrapper database;

  const NewInternalTransferPage({
    super.key,
    required this.database
  });

  Future<List<BankAccount>> _loadAccounts() async {
    return await database.getBankAccounts();
  }

  String _accountTypeName(BankAccount account) {
    if (account is CurrentAccount) return 'conto corrente';
    if (account is SavingsAccount) return 'conto deposito';
    if (account is card_account.Card) return 'carta';
    return 'account';
  }

  /// Dedicated save function: builds the [InternalTransfer] and executes
  /// it. InternalTransfer's own constructor/execute already validate
  /// amounts, dates and available balance, so any failure is just
  /// surfaced to the user through a toast.
  Future<void> _saveTransfer(
    BuildContext context,
    BankAccount startingAccount,
    BankAccount endingAccount,
    double amount,
    double fee,
    DateTime executionDate,
    DateTime? accountingDate,
  ) async {
    try {
      final transfer = InternalTransfer(
        database,
        startingAccount,
        endingAccount,
        amount,
        fee: fee,
        executionDate: executionDate,
        accountingDate: accountingDate,
      );
      bool result = await transfer.execute();
      if(!result){
        AppToast.show(context, "Operazione di girofondo tra conti non riuscita", ToastType.error);
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.show(context, e.toString(), ToastType.fatal);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final amountController = TextEditingController();
    final feeController = TextEditingController(text: '0');
    final formKey = GlobalKey<FormState>();
    final dateFormat = DateFormat('dd/MM/yyyy');

    BankAccount? startingAccount;
    BankAccount? endingAccount;
    DateTime executionDate = DateTime.now();
    DateTime? accountingDate;
    bool useCustomAccountingDate = false;

    return ActionOperationPage(
      title: 'Nuovo trasferimento interno',
      formKey: formKey,
      inputBuilder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => Form(
          key: formKey,
          child: Column(
            children: [
              // --- STARTING ACCOUNT (the account to debit) ---
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
                    value: startingAccount,
                    decoration: const InputDecoration(
                      labelText: 'Conto di partenza',
                    ),
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
                      startingAccount = value;
                      // the ending account can't match the newly
                      // selected starting account
                      if (endingAccount == startingAccount) {
                        endingAccount = null;
                      }
                    }),
                    validator: (value) =>
                        value == null ? 'Seleziona un conto' : null,
                  );
                },
              ),
              const SizedBox(height: 16),

              /* make the other fields appear only
              when the starting account has been selected */
              if (startingAccount != null) ...[
                // --- ENDING ACCOUNT (the account to credit) ---
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

                    // exclude the starting account: a transfer can't
                    // target the same account it debits
                    final accounts = (snapshot.data ?? [])
                        .where((account) => account != startingAccount)
                        .toList();
                    return DropdownButtonFormField<BankAccount>(
                      value: endingAccount,
                      decoration: const InputDecoration(
                        labelText: 'Conto di destinazione',
                      ),
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
                          setLocalState(() => endingAccount = value),
                      validator: (value) =>
                          value == null ? 'Seleziona un conto' : null,
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
                    if (parsed == null || parsed <= 0)
                      return 'Inserisci un importo valido';
                    // quick client-side check mirroring the one done by
                    // InternalTransfer itself (amount + fee can't exceed
                    // the starting account's available balance)
                    final fee =
                        double.tryParse(
                          feeController.text.replaceAll(',', '.'),
                        ) ??
                        0;
                    if (parsed + fee > startingAccount!.availableBalance)
                      return 'Saldo disponibile insufficiente';
                    return null;
                  },
                ),
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
                    final parsed = double.tryParse(value.replaceAll(',', '.'));
                    if (parsed == null || parsed < 0)
                      return 'Inserisci un importo valido';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

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
                      setLocalState(() {
                        executionDate = picked;
                        // keep the accounting date consistent: it can
                        // never be before the execution date
                        if (accountingDate != null &&
                            accountingDate!.isBefore(executionDate)) {
                          accountingDate = executionDate;
                        }
                      });
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
                        // the accounting date can't be before the
                        // execution date (see InternalTransfer's checks)
                        firstDate: executionDate,
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
        if (startingAccount == null || endingAccount == null) return;

        await _saveTransfer(
          context,
          startingAccount!,
          endingAccount!,
          double.parse(amountController.text.trim().replaceAll(',', '.')),
          double.tryParse(
                feeController.text.trim().replaceAll(',', '.'),
              ) ??
              0,
          executionDate,
          useCustomAccountingDate ? accountingDate : null,
        );

        if (context.mounted) {
          Navigator.pop(context);
        }
      },
    );
  }
}