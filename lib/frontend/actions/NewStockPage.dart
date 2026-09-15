import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';
import 'package:mira_finance_tracker/classes/bank_account/SavingsAccount.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/service/Stock.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/elements/Currency.dart';
import 'package:mira_finance_tracker/classes/subjects/FinancialInstitute.dart';
import 'package:mira_finance_tracker/frontend/templates/ActionOperationPage.dart';
import 'package:mira_finance_tracker/frontend/single_elements/UniqueNameField.dart';
import 'package:mira_finance_tracker/frontend/single_elements/NumericAmountField.dart';

/// Page to actually create a [Stock] position, built on top of
/// [ActionOperationPage] with the same graphics and structure as
/// [NewBondPage] and [NewTimeDepositPage].
///
/// Unlike time deposits and bonds, stocks have no model to draw from
/// (see [Stock]'s constructor: there's no equivalent of [BondModel] /
/// [TimeDepositModel]), so every field is always editable and there's
/// no "from scratch / from model" choice here.
///
/// ASSUMPTIONS MADE WHILE BUILDING THIS PAGE (please double-check them
/// against the real project before wiring it up):
/// * a stock is assumed to still be registered on a [SavingsAccount],
///   the same account type used by [NewBondPage] / [NewTimeDepositPage],
///   since no dedicated investment account class was shared for this
///   instrument.
/// * [Stock]'s `provider` is mandatory and isn't typed as public/private
///   like [FinancialInstrumentProvider] on the other instruments, so no
///   provider type selector is shown here: only the broker
///   ([FinancialInstitute]) itself is picked.
/// * `instrumentUsed` is a required field on [Stock] with no model to
///   source it from; its exact intended meaning for a stock wasn't
///   clear from the file shared, so it's exposed here as a plain text
///   field — please confirm/adjust its label and validation.
/// * [currentValue], [status] and [endingDate] are left to their
///   defaults and not exposed here, consistent with the other creation
///   pages.
/// * [totalShares], [averagePurchasePrice] and [totalDividends] are
///   exposed as optional fields (defaulting to 0, like the constructor
///   itself) in case the stock being created already has an existing
///   position to import.
class NewStockPage extends StatefulWidget {
  final UserDatabaseWrapper database;

  const NewStockPage({super.key, required this.database});

  @override
  State<NewStockPage> createState() => _NewStockPageState();
}

class _NewStockPageState extends State<NewStockPage> {
  late TextEditingController nameController;
  late TextEditingController tickerController;
  late TextEditingController taxRateController;
  late TextEditingController initialValueController;
  late TextEditingController totalSharesController;
  late TextEditingController averagePurchasePriceController;
  late TextEditingController totalDividendsController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
    tickerController = TextEditingController();
    taxRateController = TextEditingController(text: '0');
    initialValueController = TextEditingController();
    totalSharesController = TextEditingController(text: '0');
    averagePurchasePriceController = TextEditingController(text: '0');
    totalDividendsController = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    nameController.dispose();
    tickerController.dispose();
    taxRateController.dispose();
    initialValueController.dispose();
    totalSharesController.dispose();
    averagePurchasePriceController.dispose();
    totalDividendsController.dispose();
    super.dispose();
  }

  /// Stocks are assumed to be registered on the same account type used
  /// for time deposits and bonds (see class-level NOTE above).
  Future<List<SavingsAccount>> _loadAccounts() async {
    return (await widget.database.getSavingsAccounts()).where((account) => account.isActive).toList();
  }

  Future<List<FinancialInstitute>> _loadInstitutes() async {
    return await widget.database.getFinancialInstitutes();
  }

  Future<bool> _isNameAvailable(String name) async {
    return await widget.database.checkStockNameAvailability(name);
  }

  /// Validates if the selected broker is compatible with the savings
  /// account, same warning pattern used by [NewBondPage] / [NewTimeDepositPage].
  String _validateProviderCompatibility(SavingsAccount account, FinancialInstitute provider) {
    if (provider.id != account.bank.id) {
      return 'Avviso: L\'istituto finanziario (${provider.name}) dell\'azione è diverso dalla banca del conto (${account.bank.name}). Operazione potrebbe non essere consentita.';
    }

    return '';
  }

  Future<Stock> _saveStock(
    BuildContext context,
    SavingsAccount account,
    String name,
    String ticker,
    FinancialInstitute provider,
    Currency currency,
    double taxRate,
    double initialValue,
    double totalShares,
    double averagePurchasePrice,
    double totalDividends,
    DateTime startingDate,
  ) async {
    final stock = Stock(
      name,
      initialValue,
      taxRate,
      provider,
      ticker,
      currency,
      startingDate,
      totalShares: totalShares,
      averagePurchasePrice: averagePurchasePrice,
      totalDividends: totalDividends,
    );

    await widget.database.saveAccountStock(account, stock);
    return stock;
  }

  @override
  Widget build(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final dateFormat = DateFormat('dd/MM/yyyy');

    SavingsAccount? selectedAccount;
    bool nameAvailable = false;
    FinancialInstitute? provider;
    Currency currency = Currency.values.first;
    DateTime startingDate = DateTime.now();

    return ActionOperationPage(
      title: 'Registra una nuova azione',
      formKey: formKey,
      inputBuilder: (context) => StatefulBuilder(
        builder: (context, setLocalState) {
          return Form(
            key: formKey,
            child: Column(
              children: [
                // --- ACCOUNT SELECTION (the stock is registered on a single savings account) ---
                FutureBuilder<List<SavingsAccount>>(
                  future: _loadAccounts(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator(color: Colors.teal)),
                      );
                    }

                    final accounts = snapshot.data ?? [];
                    return DropdownButtonFormField<SavingsAccount>(
                      value: selectedAccount,
                      decoration: const InputDecoration(labelText: 'Conto'),
                      items: accounts.map((account) => DropdownMenuItem(value: account, child: Text(account.name))).toList(),
                      onChanged: (value) => setLocalState(() => selectedAccount = value),
                      validator: (value) => value == null ? 'Seleziona un conto' : null,
                    );
                  },
                ),
                const SizedBox(height: 16),

                /* make the rest of the form appear only
                when the account has been selected */
                if (selectedAccount != null) ...[
                  // --- IDENTIFYING DATA ---
                  UniqueNameField(
                    controller: nameController,
                    label: 'Nome azione',
                    checkAvailability: _isNameAvailable,
                    onAvailabilityChanged: (available) => nameAvailable = available,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: tickerController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Ticker'),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Inserisci il ticker' : null,
                  ),
                  const SizedBox(height: 16),

                  // --- BROKER / PROVIDER (always a financial institution for stocks) ---
                  FutureBuilder<List<FinancialInstitute>>(
                    future: _loadInstitutes(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator(color: Colors.teal));
                      }

                      final institutes = snapshot.data ?? [];
                      return Column(
                        children: [
                          DropdownButtonFormField<FinancialInstitute>(
                            value: provider,
                            decoration: const InputDecoration(labelText: 'Istituto finanziario'),
                            items: institutes.map((institute) => DropdownMenuItem(value: institute, child: Text(institute.name))).toList(),
                            validator: (value) => value == null ? 'Seleziona un istituto finanziario' : null,
                            onChanged: (value) => setLocalState(() => provider = value),
                          ),
                          if (provider != null)
                            Builder(
                              builder: (context) {
                                final validationMsg = _validateProviderCompatibility(selectedAccount!, provider!);
                                if (validationMsg.isNotEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.1),
                                        border: Border.all(color: Colors.orange),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        validationMsg,
                                        style: const TextStyle(color: Colors.orange, fontSize: 12),
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<Currency>(
                    value: currency,
                    decoration: const InputDecoration(labelText: 'Valuta'),
                    items: Currency.values.map((value) => DropdownMenuItem(value: value, child: Text(value.name))).toList(),
                    onChanged: (value) => setLocalState(() => currency = value ?? currency),
                  ),
                  const SizedBox(height: 16),

                  InterestAmountField(controller: taxRateController, label: 'Aliquota fiscale'),
                  const SizedBox(height: 16),

                  DollarAmountField(controller: initialValueController, label: 'Valore iniziale', isRequired: true),
                  const SizedBox(height: 24),

                  // --- EXISTING POSITION (optional, defaults to an empty one) ---
                  DoubleAmountField(controller: totalSharesController, label: 'Azioni acquistate'),
                  const SizedBox(height: 16),

                  DollarAmountField(controller: averagePurchasePriceController, label: 'Prezzo medio di acquisto'),
                  const SizedBox(height: 16),

                  DollarAmountField(controller: totalDividendsController, label: 'Dividendi già percepiti'),
                  const SizedBox(height: 24),

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
              ],
            ),
          );
        },
      ),
      onConfirm: (context) async {
        if (selectedAccount == null) return;
        if (provider == null) return;

        Stock savedStock = await _saveStock(
          context,
          selectedAccount!,
          nameController.text.trim(),
          tickerController.text.trim().toUpperCase(),
          provider!,
          currency,
          double.tryParse(taxRateController.text) ?? 0.0,
          double.tryParse(initialValueController.text) ?? 0.0,
          double.tryParse(totalSharesController.text) ?? 0.0,
          double.tryParse(averagePurchasePriceController.text) ?? 0.0,
          double.tryParse(totalDividendsController.text) ?? 0.0,
          startingDate,
        );

        if (context.mounted) {
          Navigator.pop(context, savedStock);
        }
      },
    );
  }
}