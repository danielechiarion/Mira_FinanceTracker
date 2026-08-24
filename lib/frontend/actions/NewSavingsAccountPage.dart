import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:mira_finance_tracker/classes/bank_account/SavingsAccount.dart';
import 'package:mira_finance_tracker/classes/subjects/FinancialInstitute.dart';
import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';
import 'package:mira_finance_tracker/frontend/templates/ActionOperationPage.dart';
import 'package:mira_finance_tracker/frontend/single_elements/UniqueNameField.dart';
import 'package:mira_finance_tracker/frontend/single_elements/Toast.dart';

/// Page to create a new [SavingsAccount], built on top of
/// [ActionOperationPage]. Only the attributes relevant at creation time
/// are exposed here; fees, cashbacks, transactions, domiciliations and
/// periodic incomes are added afterwards from their own actions.
class NewSavingsAccountPage extends StatelessWidget {
  /* define attributes */
  final UserDatabaseWrapper database;

  const NewSavingsAccountPage({super.key, required this.database});

  Future<List<SavingsAccount>> _loadAccounts() async {
    return await database.getSavingsAccounts();
  }

  Future<List<FinancialInstitute>> _loadInstitutes() async {
    return await database.getFinancialInstitutes();
  }

  Future<bool> _isNameAvailable(String name) async {
    final accounts = await _loadAccounts();
    return !accounts.any((account) => account.name.toLowerCase() == name.toLowerCase());
  }

  Future<DateTime?> _pickDate(BuildContext context, DateTime initialDate) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nameController = TextEditingController();
    final ibanController = TextEditingController();
    final balanceController = TextEditingController(text: '0');
    final ledgerController = TextEditingController(text: '0');
    final interestController = TextEditingController(text: '0');
    final formKey = GlobalKey<FormState>();
    final dateFormat = DateFormat('dd/MM/yyyy');

    bool nameAvailable = false;
    FinancialInstitute? selectedInstitute;
    DateTime subscriptionDate = DateTime.now();
    DateTime? endingDate;
    bool isActive = true;
    bool updatingLedger = false;

    void updateLedgerBalance() {
      final availableBalance = double.tryParse(balanceController.text) ?? 0.0;
      final ledgerBalance = double.tryParse(ledgerController.text) ?? 0.0;

      if (ledgerBalance >= availableBalance || updatingLedger) return;

      updatingLedger = true;
      ledgerController.value = ledgerController.value.copyWith(
        text: availableBalance.toString(),
        selection: TextSelection.collapsed(offset: availableBalance.toString().length),
      );
      updatingLedger = false;
    }

    final decimalFormatter = TextInputFormatter.withFunction((oldValue, newValue) {
      final isValid = RegExp(r'^\d*(\.\d*)?$').hasMatch(newValue.text);
      return isValid ? newValue : oldValue;
    });

    return ActionOperationPage(
      title: 'Nuovo conto deposito',
      formKey: formKey,
      inputBuilder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => Form(
          key: formKey,
          child: Column(
            children: [
              UniqueNameField(
                controller: nameController,
                label: 'Nome conto',
                checkAvailability: _isNameAvailable,
                onAvailabilityChanged: (available) => nameAvailable = available,
              ),
              const SizedBox(height: 16),

              // --- FINANCIAL INSTITUTE SELECTION ---
              FutureBuilder<List<FinancialInstitute>>(
                future: _loadInstitutes(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator(color: Colors.teal)),
                    );
                  }

                  final institutes = snapshot.data ?? [];
                  return DropdownButtonFormField<FinancialInstitute>(
                    value: selectedInstitute,
                    decoration: const InputDecoration(labelText: 'Istituto finanziario'),
                    items: institutes
                        .map((institute) => DropdownMenuItem(value: institute, child: Text(institute.name)))
                        .toList(),
                    onChanged: (value) => setLocalState(() => selectedInstitute = value),
                    validator: (value) => value == null ? 'Seleziona un istituto finanziario' : null,
                  );
                },
              ),
              const SizedBox(height: 16),

              // --- SUBSCRIPTION DATE ---
              InkWell(
                onTap: () async {
                  final picked = await _pickDate(context, subscriptionDate);
                  if (picked != null) setLocalState(() => subscriptionDate = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data di sottoscrizione',
                    prefixIcon: Icon(Icons.calendar_today, color: Colors.teal),
                  ),
                  child: Text(dateFormat.format(subscriptionDate)),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: ibanController,
                decoration: const InputDecoration(labelText: 'IBAN'),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: balanceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [decimalFormatter],
                decoration: const InputDecoration(labelText: 'Saldo disponibile'),
                onChanged: (_) => updateLedgerBalance(),
                validator: (value) => (value != null && value.isNotEmpty && double.tryParse(value) == null)
                    ? 'Inserisci un numero valido'
                    : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: ledgerController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [decimalFormatter],
                decoration: const InputDecoration(labelText: 'Saldo contabile'),
                onChanged: (_) => updateLedgerBalance(),
                validator: (value) => (value != null && value.isNotEmpty && double.tryParse(value) == null)
                    ? 'Inserisci un numero valido'
                    : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: interestController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Tasso di interesse'),
                validator: (value) => (value != null && value.isNotEmpty && double.tryParse(value) == null)
                    ? 'Inserisci un numero valido'
                    : null,
              ),
            ],
          ),
        ),
      ),
      onConfirm: (context) async {
        if (!nameAvailable || selectedInstitute == null) return;

        final newAccount = SavingsAccount(
          nameController.text.trim(),
          selectedInstitute!,
          subscriptionDate,
          IBAN: ibanController.text.trim().isEmpty ? null : ibanController.text.trim(),
          availableBalance: double.tryParse(balanceController.text.trim()) ?? 0.0,
          ledgerBalance: [
            double.tryParse(ledgerController.text.trim()) ?? 0.0,
            double.tryParse(balanceController.text.trim()) ?? 0.0,
          ].reduce((maximum, value) => maximum > value ? maximum : value),
          interest: double.tryParse(interestController.text.trim()) ?? 0.0,
          active: isActive,
          endingDate: endingDate,
        );

        try{
          await database.saveSavingsAccount(newAccount);
        }catch(e){
          AppToast.show(context, e.toString(), ToastType.fatal);
        }

        Navigator.pop(context);
      },
    );
  }
}