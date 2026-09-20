import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mira_finance_tracker/classes/financial_instruments/service/TimeDeposit.dart';
import 'package:mira_finance_tracker/frontend/templates/ActionOperationPage.dart';

import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';

/// Edit page for a TimeDeposit. Unlike EditPeriodicTransactionPage, this
/// entity can't be rebuilt from scratch on confirm: the duration/cadence
/// ([TimeDeposit.timeInfo]) is locked once the instrument is created (its
/// setter throws by design), so this page mutates the existing [item] in
/// place through its own setters instead of constructing a new one.
///
/// NOTE: name, provider, initial value and the whole time schedule are
/// this entity's identity and can't be changed here, in line with the
/// other management pages (see EditPeriodicTransactionPage, where
/// name/counterparty are likewise locked). Interest rate, cashability and
/// early-withdrawal rate all refuse the change once the deposit is no
/// longer "ongoing" (or, for the interest rate, once the first coupon has
/// already been paid): those failures are caught and surfaced to the
/// user instead of crashing the page.
class EditTimeDepositPage extends StatelessWidget {
  final String title;
  final TimeDeposit item;
  final UserDatabaseWrapper _database;

  const EditTimeDepositPage({
    super.key,
    required this.title,
    required this.item,
    required UserDatabaseWrapper database,
  }) : _database = database;

  @override
  Widget build(BuildContext context) {
    final currentValueController = TextEditingController(text: item.currentValue.toString());
    final interestRateController = TextEditingController(text: (item.interestRate).toStringAsFixed(2));
    final earlyWithdrawalController = TextEditingController(text: (item.earlyWithdrawalInterestRate * 100).toStringAsFixed(2));
    final formKey = GlobalKey<FormState>();

    /* seed the local flag from the existing value, so the early-withdrawal
    field only shows up when it's actually relevant */
    bool isCashable = item.isCashable;

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
                controller: interestRateController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+[.,]?\d{0,2}'))],
                decoration: const InputDecoration(labelText: 'Tasso di interesse (%)'),
                validator: _validateAmount,
              ),
              const SizedBox(height: 16),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Svincolabile anticipatamente'),
                value: isCashable,
                activeColor: Colors.indigo,
                onChanged: (value) => setLocalState(() => isCashable = value),
              ),

              if (isCashable) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: earlyWithdrawalController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+[.,]?\d{0,2}'))],
                  decoration: const InputDecoration(labelText: 'Tasso di interesse per svincolo anticipato (%)'),
                  validator: _validateAmount,
                ),
              ],
            ],
          ),
        ),
      ),
      onConfirm: (context) async {
        final updatedCurrentValue = double.parse(currentValueController.text.trim().replaceAll(',', '.'));
        final updatedInterestRate = double.parse(interestRateController.text.trim().replaceAll(',', '.'));
        final updatedEarlyRate = double.parse(earlyWithdrawalController.text.trim().replaceAll(',', '.'));

        /* apply the changes through the entity's own setters, and only
        for the fields that actually changed: some of them refuse the
        change depending on the deposit's current state (see the class
        doc comment above), so failures are shown to the user instead of
        left uncaught */
        try {
          if (updatedCurrentValue != item.currentValue) item.currentValue = updatedCurrentValue;
          if (updatedInterestRate != item.interestRate) item.interestRate = updatedInterestRate;
          if (isCashable != item.isCashable) item.isCashable = isCashable;
          if (isCashable && updatedEarlyRate != item.earlyWithdrawalInterestRate) {
            item.earlyWithdrawalInterestRate = updatedEarlyRate;
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
          }
          return;
        }

        // BACKEND DATABASE CALL:
        // Persist the updated time deposit on the database
        await _database.updateSavingsAccountTimeDeposit(item);

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