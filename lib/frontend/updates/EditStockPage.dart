import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:mira_finance_tracker/classes/financial_instruments/service/Stock.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/elements/Currency.dart';
import 'package:mira_finance_tracker/frontend/templates/ActionOperationPage.dart';

import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';

/// Edit page for a Stock. Unlike bonds and time deposits, a stock barely
/// exposes any setter at all: shares, average purchase price and
/// dividends only ever change through the dedicated operations
/// ([Stock.buyShares], [Stock.sellShares], [Stock.addDividend]), not from
/// a generic edit form. This page therefore only lets the user correct
/// the currency and the current value - everything else is shown
/// read-only for reference.
///
/// NOTE: name, provider, ticker and starting date are this entity's
/// identity and can't be changed here (see EditPeriodicTransactionPage
/// for the same convention applied to name/counterparty).
class EditStockPage extends StatelessWidget {
  final String title;
  final Stock item;
  final UserDatabaseWrapper _database;

  const EditStockPage({
    super.key,
    required this.title,
    required this.item,
    required UserDatabaseWrapper database,
  }) : _database = database;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'it_IT', symbol: '€');
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currentValueController = TextEditingController(text: item.currentValue.toString());
    final formKey = GlobalKey<FormState>();

    /* seed the local field from what's already saved */
    Currency currency = item.currency;

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
              _readOnlyField('Ticker (non modificabile)', item.ticker),
              const SizedBox(height: 16),
              _readOnlyField('Istituto (non modificabile)', item.provider?.name ?? '-'),
              const SizedBox(height: 16),
              _readOnlyField('Azioni possedute (non modificabile)', item.totalShares.toStringAsFixed(4)),
              const SizedBox(height: 16),
              _readOnlyField('Prezzo medio di carico (non modificabile)', formatter.format(item.averagePurchasePrice)),
              const SizedBox(height: 16),
              _readOnlyField('Dividendi totali (non modificabile)', formatter.format(item.totalDividends)),
              const SizedBox(height: 16),
              _readOnlyField('Data di inizio (non modificabile)', dateFormat.format(item.startingDate)),
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

              DropdownButtonFormField<Currency>(
                value: currency,
                decoration: const InputDecoration(labelText: 'Valuta'),
                items: Currency.values
                    .map((value) => DropdownMenuItem<Currency>(value: value, child: Text('${value.name} (${value.symbol})')))
                    .toList(),
                onChanged: (value) => setLocalState(() => currency = value ?? currency),
              ),
            ],
          ),
        ),
      ),
      onConfirm: (context) async {
        final updatedCurrentValue = double.parse(currentValueController.text.trim().replaceAll(',', '.'));

        /* currency has no validity guard on the entity, but currentValue
        still goes through the base class setter */
        item.currentValue = updatedCurrentValue;
        item.currency = currency;

        // BACKEND DATABASE CALL:
        // Persist the updated stock on the database, e.g.
        await _database.updateSavingsAccountStock(item);

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