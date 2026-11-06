import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:mira_finance_tracker/classes/periodic_transactions/PeriodicTransaction.dart';
import 'package:mira_finance_tracker/classes/periodic_transactions/Domiciliation.dart';
import 'package:mira_finance_tracker/classes/periodic_transactions/PeriodicIncome.dart';
import 'package:mira_finance_tracker/classes/time_management/DurationType.dart';
import 'package:mira_finance_tracker/classes/time_management/PeriodicAccountDuration.dart';
import 'package:mira_finance_tracker/frontend/templates/ActionOperationPage.dart';

import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';

/// Edit page shared by Domiciliation and PeriodicIncome, since both are
/// just PeriodicTransaction with a different meaning (outgoing vs income) -
/// Domiciliation additionally carries its own bank fee. [classRequested]
/// picks which of the two concrete classes gets rebuilt on confirm,
/// following the same convention used by PeriodicBillingFormPage for the
/// "add" flow - the recurrence controls below are in fact mirrored from
/// that same page, just pre-filled with the existing cadence instead of
/// the form's defaults.
///
/// NOTE: name and counterparty are this entity's identity (see the doc
/// comments on Domiciliation/PeriodicIncome) and can't be changed here, in
/// line with the other management pages (see
/// FinancialInstituteManagementPage, where name is likewise locked).
class EditPeriodicTransactionPage extends StatelessWidget {
  final String title;
  final PeriodicTransaction item;
  final Type classRequested;
  final UserDatabaseWrapper _database;

  const EditPeriodicTransactionPage({
    super.key,
    required this.title,
    required this.item,
    required this.classRequested,
    required this._database,
  });

  bool get _isDomiciliation => classRequested == Domiciliation;

  @override
  Widget build(BuildContext context) {
    final nameController = TextEditingController(text: item.name);
    final amountController = TextEditingController(text: item.amount.toString());
    final descriptionController = TextEditingController(text: item.description ?? '');
    final feeController = TextEditingController(
      text: _isDomiciliation ? (item as Domiciliation).fee.toString() : '0',
    );
    final formKey = GlobalKey<FormState>();
    final dateFormat = DateFormat('dd/MM/yyyy');

    /* seed the recurrence fields from the existing cadence, so editing
    starts from what's already saved instead of the form's defaults */
    DurationType frequency = item.cadence.timeFrequency;
    int dayOfMonth = item.cadence.dayOfMonth;
    int monthOfYear = item.cadence.monthOfYear ?? 1;
    DateTime startingDate = item.cadence.startingDate;

    return ActionOperationPage(
      title: title,
      formKey: formKey,
      inputBuilder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => Form(
          key: formKey,
          child: Column(
            children: [
              TextFormField(
                controller: nameController,
                enabled: false,
                decoration: const InputDecoration(labelText: 'Nome (non modificabile)'),
              ),
              const SizedBox(height: 16),
              _readOnlyField('Controparte (non modificabile)', item.counterParty.name),
              const SizedBox(height: 16),

              TextFormField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+[.,]?\d{0,2}'))],
                decoration: const InputDecoration(
                  labelText: 'Importo',
                  prefixIcon: Icon(Icons.euro, color: Colors.teal),
                ),
                validator: _validateAmount,
              ),

              if (_isDomiciliation) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: feeController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+[.,]?\d{0,2}'))],
                  decoration: const InputDecoration(labelText: 'Commissione applicata'),
                  validator: _validateAmount,
                ),
              ],
              const SizedBox(height: 16),

              TextFormField(
                controller: descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Descrizione (opzionale)'),
              ),
              const SizedBox(height: 24),

              // --- RECURRENCE ---
              DropdownButtonFormField<DurationType>(
                value: frequency,
                decoration: const InputDecoration(labelText: 'Ricorrenza'),
                items: DurationType.values
                    .where((durationType) => durationType != DurationType.atMaturity)
                    .map((durationType) => DropdownMenuItem<DurationType>(value: durationType, child: Text(durationType.name)))
                    .toList(),
                onChanged: (value) => setLocalState(() => frequency = value ?? frequency),
              ),
              const SizedBox(height: 16),

              TextFormField(
                initialValue: dayOfMonth.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Giorno del mese'),
                onChanged: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null) dayOfMonth = parsed;
                },
                validator: (value) {
                  final parsed = int.tryParse(value ?? '');
                  if (parsed == null || parsed < 1 || parsed > 31) return 'Inserisci un giorno tra 1 e 31';
                  return null;
                },
              ),

              if (frequency.index >= DurationType.annual.index) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: monthOfYear,
                  decoration: const InputDecoration(labelText: 'Mese'),
                  items: List.generate(12, (index) => index + 1)
                      .map((month) => DropdownMenuItem(value: month, child: Text(DateFormat.MMMM('it_IT').format(DateTime(2024, month)))))
                      .toList(),
                  onChanged: (value) => setLocalState(() => monthOfYear = value ?? 1),
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
                  if (picked != null) setLocalState(() => startingDate = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data di inizio',
                    prefixIcon: Icon(Icons.calendar_today, color: Colors.teal),
                  ),
                  child: Text(dateFormat.format(startingDate)),
                ),
              ),
            ],
          ),
        ),
      ),
      onConfirm: (context) async {
        final updatedAmount = double.parse(amountController.text.trim().replaceAll(',', '.'));
        final updatedDescription = descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim();
        final updatedFee = _isDomiciliation ? double.parse(feeController.text.trim().replaceAll(',', '.')) : 0.0;
        final updatedCadence = PeriodicAccountDuration(
          startingDate,
          frequency,
          dayOfMonth,
          monthOfYear: frequency.index >= DurationType.annual.index ? monthOfYear : null,
        );
        final updated = _rebuild(updatedAmount, updatedDescription, updatedFee, updatedCadence);

        /* then save the updated information
        permanently inside the database */
        if(classRequested == Domiciliation){
          await _database.updateCurrentAccountDomiciliation(updated as Domiciliation);
        }else{
          await _database.updateCurrentAccountPeriodicIncome(updated as PeriodicIncome);
        }

        if (context.mounted) {
          Navigator.pop(context, updated);
        }
      },
    );
  }

  String? _validateAmount(String? value) {
    if (value == null || value.isEmpty) return 'Il valore deve essere impostato';
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null || parsed < 0) return 'Inserisci un importo valido';
    return null;
  }

  /// Rebuilds the entity as the concrete type in [classRequested], keeping
  /// the identity fields (name, counterParty, id) and applying the edited
  /// amount, description, fee and cadence.
  PeriodicTransaction _rebuild(double amount, String? description, double fee, PeriodicAccountDuration cadence) {
    if (classRequested == Domiciliation) {
      return Domiciliation(
        item.name,
        amount,
        cadence,
        item.counterParty.clone(),
        description: description,
        id: item.id,
        fee: fee,
      );
    }
    if (classRequested == PeriodicIncome) {
      return PeriodicIncome(
        item.name,
        amount,
        cadence,
        item.counterParty.clone(),
        description: description,
        id: item.id,
      );
    }
    throw ArgumentError('Unsupported classRequested for EditPeriodicTransactionPage: $classRequested');
  }

  /// Small read-only row used for fields we can show but not edit.
  Widget _readOnlyField(String label, String value) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}