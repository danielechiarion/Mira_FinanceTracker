import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mira_finance_tracker/classes/financial_instruments/service/Bond.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/model/BondModel.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/elements/StepInterest.dart';
import 'package:mira_finance_tracker/frontend/actions/StepInterestEditor.dart';
import 'package:mira_finance_tracker/frontend/templates/ActionOperationPage.dart';

import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';

/// Edit page for a Bond. As with EditTimeDepositPage, the time schedule
/// ([Bond.timeInfo]) is locked once the bond is created (its setter
/// throws by design), so this page mutates the existing [item] in place
/// through its own setters instead of rebuilding it from scratch.
///
/// NOTE: name, provider, purchase price and initial value are this
/// entity's identity and can't be changed here (see
/// EditPeriodicTransactionPage for the same convention applied to
/// name/counterparty). Interest type, minimum denomination and coupon
/// schedule all refuse the change once the bond has already paid its
/// first coupon: those failures are caught and surfaced to the user
/// instead of crashing the page. The coupon schedule itself is managed
/// with [StepInterestEditor], the same widget used to build it in the
/// first place on the bond model.
class EditBondPage extends StatelessWidget {
  final String title;
  final Bond item;
  final UserDatabaseWrapper _database;

  const EditBondPage({
    super.key,
    required this.title,
    required this.item,
    required UserDatabaseWrapper database,
  }) : _database = database;

  @override
  Widget build(BuildContext context) {
    final currentValueController = TextEditingController(text: item.currentValue.toString());
    final minimumDenominationController = TextEditingController(text: item.minimumDenomination.toString());
    final formKey = GlobalKey<FormState>();

    /* seed the local fields from what's already saved, so editing starts
    from the current situation instead of some default */
    BondType interestType = item.interestType;
    List<StepInterest> couponSchedule = item.couponSchedule;

    return ActionOperationPage(
      title: title,
      formKey: formKey,
      inputBuilder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => Form(
          key: formKey,
          child: Column(
            children: [
              TextFormField(
                controller: TextEditingController(text: item.name),
                enabled: false,
                decoration: const InputDecoration(labelText: 'Nome (non modificabile)'),
              ),
              const SizedBox(height: 16),
              _readOnlyField('Istituto (non modificabile)', item.provider?.name ?? '-'),
              const SizedBox(height: 16),
              _readOnlyField('Valore iniziale (non modificabile)', item.initialValue.toStringAsFixed(2)),
              const SizedBox(height: 16),
              _readOnlyField('Prezzo di acquisto (non modificabile)', '${item.purchasePrice.toStringAsFixed(2)}%'),
              const SizedBox(height: 16),
              _readOnlyField('Frequenza pagamento interessi (non modificabile)', item.timeInfo.timeFrequency.name),
              const SizedBox(height: 16),

              TextFormField(
                controller: currentValueController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+[.,]?\d{0,2}'))],
                decoration: const InputDecoration(
                  labelText: 'Valore attuale',
                  prefixIcon: Icon(Icons.euro, color: Colors.teal),
                ),
                validator: _validateAmount,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: minimumDenominationController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+[.,]?\d{0,2}'))],
                decoration: const InputDecoration(labelText: 'Taglio minimo'),
                validator: _validateAmount,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<BondType>(
                value: interestType,
                decoration: const InputDecoration(labelText: 'Tipo di interesse'),
                items: BondType.values
                    .map((type) => DropdownMenuItem<BondType>(value: type, child: Text(type.name)))
                    .toList(),
                onChanged: (value) => setLocalState(() => interestType = value ?? interestType),
              ),
              const SizedBox(height: 16),

              // A variable-rate bond has no fixed coupon schedule, so the
              // editor is only shown for fixed/step interest types.
              if (interestType != BondType.variable)
                StepInterestEditor(
                  key: const ValueKey('coupon-schedule-editor'),
                  initialInterests: couponSchedule,
                  onChanged: (updated) => couponSchedule = updated,
                ),
            ],
          ),
        ),
      ),
      onConfirm: (context) async {
        final updatedCurrentValue = double.parse(currentValueController.text.trim().replaceAll(',', '.'));
        final updatedMinimumDenomination = double.parse(minimumDenominationController.text.trim().replaceAll(',', '.'));

        /* apply the changes through the entity's own setters, and only
        for the fields that actually changed: interest type, minimum
        denomination and coupon schedule all refuse the change once the
        bond has already paid its first coupon, so failures are shown to
        the user instead of left uncaught */
        try {
          if (updatedCurrentValue != item.currentValue) item.currentValue = updatedCurrentValue;
          if (updatedMinimumDenomination != item.minimumDenomination) item.minimumDenomination = updatedMinimumDenomination;
          if (interestType != item.interestType) item.interestType = interestType;
          if (interestType != BondType.variable) item.couponSchedule = couponSchedule;
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
          }
          return;
        }

        // BACKEND DATABASE CALL:
        // Persist the updated bond (and its coupon schedule) on the
        // database
        await _database.updateSavingsAccountBondComplete(item);

        if (context.mounted) {
          Navigator.pop(context, item);
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