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
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+[.,]?\d{0,2}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Saldo disponibile',
                  prefixIcon: Icon(Icons.euro, color: Colors.teal),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return null; // campo opzionale, default 0
                  final parsed = double.tryParse(value.replaceAll(',', '.'));
                  if (parsed == null) return 'Inserisci un numero valido';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: ledgerController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+[.,]?\d{0,2}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Saldo contabile',
                  prefixIcon: Icon(Icons.euro, color: Colors.teal),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return null; // campo opzionale, default 0
                  final parsed = double.tryParse(value.replaceAll(',', '.'));
                  if (parsed == null) return 'Inserisci un numero valido';
                  return null;
                },
              ),

              TextFormField(
                controller: interestController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+[.,]?\d{0,2}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Tasso di interesse',
                  prefixIcon: Icon(Icons.percent, color: Colors.teal),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return null;
                  final parsed = double.tryParse(value.replaceAll(',', '.'));
                  if (parsed == null) return 'Inserisci un numero valido';
                  if(parsed < 0 || parsed > 100) return 'Il tasso deve essere compreso tra 0% e 100%';
                  return null;
                },
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
          availableBalance: double.tryParse(balanceController.text.trim().replaceAll(',', '.')) ?? 0.0,
          ledgerBalance: [
            double.tryParse(ledgerController.text.trim().replaceAll(',', '.')) ?? 0.0,
            double.tryParse(balanceController.text.trim().replaceAll(',', '.')) ?? 0.0,
          ].reduce((maximum, value) => maximum > value ? maximum : value),
          interest: double.tryParse(interestController.text.trim().replaceAll(',', '.')) ?? 0.0,
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