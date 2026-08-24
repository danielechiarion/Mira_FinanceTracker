import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:mira_finance_tracker/classes/bank_account/Card.dart' as card_account;
import 'package:mira_finance_tracker/classes/subjects/FinancialInstitute.dart';
import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';
import 'package:mira_finance_tracker/frontend/templates/ActionOperationPage.dart';
import 'package:mira_finance_tracker/frontend/single_elements/UniqueNameField.dart';
import 'package:mira_finance_tracker/frontend/single_elements/Toast.dart';

/// Page to create a new [Card], built on top of
/// [ActionOperationPage]. Only the attributes relevant at creation time
/// are exposed here; fees, cashbacks, transactions, domiciliations and
/// periodic incomes are added afterwards from their own actions.
class NewCardAccountPage extends StatelessWidget {
  /* define attributes */
  final UserDatabaseWrapper database;

  const NewCardAccountPage({super.key, required this.database});

  Future<List<card_account.Card>> _loadAccounts() async {
    return await database.getCardAccounts();
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
    final interestController = TextEditingController(text: '0');
    final creditDayController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final dateFormat = DateFormat('dd/MM/yyyy');

    bool nameAvailable = false;
    FinancialInstitute? selectedInstitute;
    card_account.CardType? cardType;
    DateTime subscriptionDate = DateTime.now();
    DateTime? endingDate;
    bool isActive = true;

    return ActionOperationPage(
      title: 'Nuova Carta',
      formKey: formKey,
      inputBuilder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => Form(
          key: formKey,
          child: Column(
            children: [
              UniqueNameField(
                controller: nameController,
                label: 'Nome carta',
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

              // --- CARD TYPE SELECTION ---
              DropdownButtonFormField<card_account.CardType>(
                decoration: const InputDecoration(labelText: 'Tipo di carta'),
                items: card_account.CardType.values
                    .map((type) => DropdownMenuItem(value: type, child: Text(type.name)))
                    .toList(),
                onChanged: (value) => setLocalState(() => cardType = value),
                validator: (value) => value == null ? 'Seleziona un tipo di carta' : null,
              ),
              const SizedBox(height:16),

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
                decoration: const InputDecoration(labelText: 'Saldo disponibile'),
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

              // --- CREDIT DAY SELECTION ---
              if (cardType == card_account.CardType.credit) ...[
                TextFormField(
                  controller: creditDayController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Giorno di credito',
                    prefixIcon: Icon(Icons.calendar_month, color: Colors.teal),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Inserisci il giorno di credito';
                    }
                    final day = int.tryParse(value);
                    if (day == null || day < 1 || day > 31) {
                      return 'Inserisci un giorno valido (1-31)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
      onConfirm: (context) async {
        if (!nameAvailable || selectedInstitute == null) return;

        final int? creditDay = cardType == card_account.CardType.credit
          ? int.tryParse(creditDayController.text.trim())
          : null;

        final newAccount = card_account.Card(
          nameController.text.trim(),
          selectedInstitute!,
          subscriptionDate,
          cardType!,
          IBAN: ibanController.text.trim().isEmpty ? null : ibanController.text.trim(),
          availableBalance: double.tryParse(balanceController.text.trim()) ?? 0.0,
          interest: double.tryParse(interestController.text.trim()) ?? 0.0,
          active: isActive,
          endingDate: endingDate,
          dayOfMonthCredit: creditDay
        );

        try{
          await database.saveCardAccount(newAccount);
        }catch(e){
          AppToast.show(context, e.toString(), ToastType.fatal);
        }

        Navigator.pop(context);
      },
    );
  }
}