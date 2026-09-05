import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';
import 'package:mira_finance_tracker/classes/bank_account/SavingsAccount.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/model/FinancialInstrumentModel.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/model/TimeDepositModel.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/service/TimeDeposit.dart';
import 'package:mira_finance_tracker/classes/subjects/FinancialInstitute.dart';
import 'package:mira_finance_tracker/classes/time_management/DurationType.dart';
import 'package:mira_finance_tracker/classes/time_management/LongDuration.dart';
import 'package:mira_finance_tracker/frontend/templates/ActionOperationPage.dart';
import 'package:mira_finance_tracker/frontend/single_elements/LongDurationField.dart';
import 'package:mira_finance_tracker/frontend/single_elements/NumericAmountField.dart';
import 'package:mira_finance_tracker/frontend/single_elements/UniqueNameField.dart';

/// Page to actually subscribe a [TimeDeposit] on a savings account
/// ("conto deposito"), built on top of [ActionOperationPage] just like
/// [PeriodicBillingFormPage]: a single [StatefulBuilder] wraps the whole
/// [Form] so every conditional field (account selected, model chosen,
/// cashability, month of year, ...) can react locally without turning
/// this widget itself into a [StatefulWidget].
///
/// The user can either build the time deposit from scratch, filling in
/// every financial condition by hand, or pick one of the saved
/// [TimeDepositModel]. In the latter case every field the model already
/// defines (provider, tax rate, interest rate, duration, payout
/// frequency, cashability) is locked and shown as a read-only summary;
/// only the instance-specific data (name, initial value, starting date,
/// day/month of payout) stays editable, exactly as [TimeDeposit.fromModel]
/// expects it.
///
/// ASSUMPTIONS MADE WHILE BUILDING THIS PAGE (please double-check them
/// against the real project before wiring it up):
/// * [includeStart], [includeEnd], [lastDateActivity] and [currentValue]
///   are left to their defaults and not exposed here, to keep the form
///   at the same level of detail as [PeriodicBillingFormPage].
/// * [TimeDeposit] requires an `instrumentUsed` value even when there's
///   no model behind it (see [TimeDeposit.fromModel] passing `model.name`
///   there): a placeholder string is used for the "from scratch" flow,
///   marked below, since its exact intended semantics weren't clear from
///   the files shared.
/// * [TimeDeposit.fromModel] doesn't forward `isCashable` /
///   `earlyWithdrawalInterestRate` from the model, so they're applied
///   right after construction to fully honor the model chosen.
/// * every call into [UserDatabaseWrapper] beyond the ones already used
///   by [FinancialInstituteManagementPage] / [FinancialInstrumentModelManagementPage]
///   is a guess at the actual method name and is marked with a "TODO".
class NewTimeDepositPage extends StatefulWidget {
  final UserDatabaseWrapper database;

  const NewTimeDepositPage({super.key, required this.database});

  @override
  State<NewTimeDepositPage> createState() => _NewTimeDepositPageState();
}

class _NewTimeDepositPageState extends State<NewTimeDepositPage> {
  late TextEditingController nameController;
  late TextEditingController initialValueController;
  late TextEditingController taxRateController;
  late TextEditingController interestRateController;
  late TextEditingController earlyWithdrawalController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
    initialValueController = TextEditingController();
    taxRateController = TextEditingController(text: '0');
    interestRateController = TextEditingController();
    earlyWithdrawalController = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    nameController.dispose();
    initialValueController.dispose();
    taxRateController.dispose();
    interestRateController.dispose();
    earlyWithdrawalController.dispose();
    super.dispose();
  }

  /// Only savings accounts ("conto deposito") can host a time deposit.
  Future<List<SavingsAccount>> _loadAccounts() async {
    return await widget.database.getSavingsAccounts();
  }

  Future<List<TimeDepositModel>> _loadModels() async {
    return widget.database.getTimeDepositModels();
  }

  Future<List<FinancialInstitute>> _loadInstitutes() async {
    return widget.database.getFinancialInstitutes();
  }

  Future<bool> _isNameAvailable(String name) async {
    return widget.database.checkTimeDepositNameAvailability(name);
  }

  /// Validates if the financial instrument provider is compatible with the savings account.
  /// If the provider type is financial institution, the provider must match the account's bank.
  /// Returns a validation message (empty if valid), or an error message if incompatible.
  String _validateProviderCompatibility(
    SavingsAccount account,
    FinancialInstrumentProvider providerType,
    FinancialInstitute? provider,
  ) {
    // If provider type is public institution, always compatible
    if (providerType == FinancialInstrumentProvider.publicInstitution) {
      return '';
    }

    // If provider type is financial institution, provider must match account's bank
    if (providerType == FinancialInstrumentProvider.financialInstitution) {
      if (provider == null) {
        return 'Seleziona un istituto finanziario';
      }
      if (provider.id != account.bank.id) {
        return 'Avviso: L\'istituto finanziario (${provider.name}) del deposito a termine è diverso dalla banca del conto (${account.bank.name}). Operazione potrebbe non essere consentita.';
      }
    }

    return '';
  }

  /// Validates provider compatibility for a model-based time deposit
  String _validateModelProviderCompatibility(SavingsAccount account, TimeDepositModel model) {
    return _validateProviderCompatibility(account, model.providerType, model.provider);
  }

  Future<void> _saveTimeDeposit(
    BuildContext context,
    SavingsAccount account,
    TimeDepositModel? model,
    String name,
    double initialValue,
    FinancialInstrumentProvider providerType,
    FinancialInstitute? provider,
    double taxRate,
    double interestRate,
    LongDuration duration,
    DurationType frequency,
    bool isCashable,
    double earlyWithdrawalInterestRate,
    DateTime startingDate,
    int dayOfMonth,
    int? monthOfYear,
  ) async {
    TimeDeposit timeDeposit; // declare variable for the instrument to save

    if (model != null) {
      timeDeposit = TimeDeposit.fromModel(
        model,
        name,
        initialValue,
        startingDate: startingDate,
        day: dayOfMonth,
        month: monthOfYear,
      );

      /* TimeDeposit.fromModel doesn't forward cashability, so it's
      applied right after creation to fully honor the model chosen */
      timeDeposit.isCashable = model.isCashable;
      timeDeposit.earlyWithdrawalInterestRate = model.earlyWithdrawalInterestRate;
    } else {
      timeDeposit = TimeDeposit(
        name,
        providerType,
        initialValue,
        taxRate,
        interestRate,
        startingDate,
        frequency,
        dayOfMonth,
        monthOfYear: monthOfYear,
        provider: provider,
        duration: duration,
        isCashable: isCashable,
        earlyWithdrawalInterestRate: earlyWithdrawalInterestRate,
      );
    }

    await widget.database.saveAccountTimeDeposit(account, timeDeposit);
  }

  /// Read-only summary of every field a chosen [TimeDepositModel]
  /// already defines: once picked, these can't be changed for the
  /// resulting time deposit (see [TimeDeposit.fromModel]).
  Widget _buildModelSummary(TimeDepositModel model) {
    final String providerText = model.provider != null ? '${model.providerType.name} (${model.provider!.name})' : model.providerType.name;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dati presi dal modello (non modificabili)', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Fornitore: $providerText'),
          Text('Aliquota fiscale: ${model.taxRate}%'),
          Text('Tasso di interesse annuo: ${model.interestRate}%'),
          Text('Durata: ${model.duration}'),
          Text('Frequenza pagamento interessi: ${model.payoutFrequency.name}'),
          Text('Riscattabile prima della scadenza: ${model.isCashable ? 'Sì' : 'No'}'),
          if (model.isCashable) Text('Tasso di interesse per riscatto anticipato: ${model.earlyWithdrawalInterestRate}%'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final dateFormat = DateFormat('dd/MM/yyyy');

    SavingsAccount? selectedAccount;
    bool nameAvailable = false;
    bool useModel = false; // false = from scratch, true = from a saved model
    TimeDepositModel? selectedModel;

    /* fields edited only when building the time deposit from scratch,
    since choosing a model locks all of them (see class-level NOTE) */
    FinancialInstrumentProvider providerType = FinancialInstrumentProvider.financialInstitution;
    FinancialInstitute? provider;
    LongDuration duration = const LongDuration();
    DurationType frequency = DurationType.monthly;
    bool isCashable = true;

    /* fields always needed, model or not */
    DateTime startingDate = DateTime.now();

    return ActionOperationPage(
      title: 'Apri un nuovo deposito a tempo',
      formKey: formKey,
      inputBuilder: (context) => StatefulBuilder(
        builder: (context, setLocalState) {
          return Form(
            key: formKey,
            child: Column(
              children: [
                // --- ACCOUNT SELECTION (the time deposit is opened on a single savings account) ---
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
                      decoration: const InputDecoration(labelText: 'Conto deposito'),
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
                  // --- CREATION MODE: from scratch or from a saved model ---
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Da zero'),
                          selected: !useModel,
                          selectedColor: Colors.indigo,
                          labelStyle: TextStyle(color: !useModel ? Colors.white : Colors.black87),
                          onSelected: (_) => setLocalState(() {
                            useModel = false;
                            selectedModel = null;
                          }),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Da modello'),
                          selected: useModel,
                          selectedColor: Colors.indigo,
                          labelStyle: TextStyle(color: useModel ? Colors.white : Colors.black87),
                          onSelected: (_) => setLocalState(() => useModel = true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (useModel) ...[
                    // --- MODEL SELECTION (locks every field it defines, see summary below) ---
                    FutureBuilder<List<TimeDepositModel>>(
                      future: _loadModels(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(child: CircularProgressIndicator(color: Colors.teal));
                        }

                        final models = snapshot.data ?? [];
                        return DropdownButtonFormField<TimeDepositModel>(
                          value: selectedModel,
                          decoration: const InputDecoration(labelText: 'Modello'),
                          items: models.map((model) => DropdownMenuItem(value: model, child: Text(model.name))).toList(),
                          onChanged: (value) => setLocalState(() => selectedModel = value),
                          validator: (value) => value == null ? 'Seleziona un modello' : null,
                        );
                      },
                    ),
                    if (selectedModel != null) ...[
                      const SizedBox(height: 12),
                      Builder(
                        builder: (context) {
                          final validationMsg = _validateModelProviderCompatibility(selectedAccount!, selectedModel!);
                          if (validationMsg.isNotEmpty) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
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
                      _buildModelSummary(selectedModel!),
                    ],
                  ] else ...[
                    // --- FIELDS DEFINED FROM SCRATCH (locked instead when a model is used) ---
                    DropdownButtonFormField<FinancialInstrumentProvider>(
                      value: providerType,
                      decoration: const InputDecoration(labelText: 'Tipo di fornitore'),
                      items: FinancialInstrumentProvider.values
                          .map((value) => DropdownMenuItem(value: value, child: Text(value.name)))
                          .toList(),
                      onChanged: (value) => setLocalState(() {
                        providerType = value ?? providerType;
                        if (providerType != FinancialInstrumentProvider.financialInstitution) provider = null;
                      }),
                    ),
                    if (providerType == FinancialInstrumentProvider.financialInstitution) ...[
                      const SizedBox(height: 16),
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
                                validator: (value) => providerType == FinancialInstrumentProvider.financialInstitution && value == null
                                    ? 'Seleziona un istituto finanziario'
                                    : null,
                                onChanged: (value) => setLocalState(() => provider = value),
                              ),
                              if (provider != null && selectedAccount != null)
                                Builder(
                                  builder: (context) {
                                    final validationMsg = _validateProviderCompatibility(selectedAccount!, providerType, provider);
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
                    ],
                    const SizedBox(height: 16),
                    LongDurationField(
                      label: 'Durata',
                      initialValue: duration,
                      onChanged: (value) => duration = value,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<DurationType>(
                      value: frequency,
                      decoration: const InputDecoration(labelText: 'Frequenza pagamento interessi'),
                      items: DurationType.values.map((value) => DropdownMenuItem(value: value, child: Text(value.name))).toList(),
                      onChanged: (value) => setLocalState(() => frequency = value ?? frequency),
                    ),
                    const SizedBox(height: 16),
                    InterestAmountField(controller: taxRateController, label: 'Aliquota fiscale'),
                    const SizedBox(height: 16),
                    InterestAmountField(controller: interestRateController, label: 'Tasso di interesse annuo', isRequired: true),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Riscattabile prima della scadenza'),
                      value: isCashable,
                      activeColor: Colors.indigo,
                      onChanged: (value) => setLocalState(() => isCashable = value),
                    ),
                    if (isCashable) ...[
                      InterestAmountField(controller: earlyWithdrawalController, label: 'Tasso di interesse per riscatto anticipato'),
                    ],
                  ],
                  const SizedBox(height: 16),

                  // --- INSTANCE-SPECIFIC DATA (always editable, model or not) ---
                  UniqueNameField(
                    controller: nameController,
                    label: 'Nome deposito',
                    checkAvailability: _isNameAvailable,
                    onAvailabilityChanged: (available) => nameAvailable = available,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: initialValueController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+[.,]?\d{0,2}'))],
                    decoration: const InputDecoration(
                      labelText: 'Valore iniziale',
                      prefixIcon: Icon(Icons.euro, color: Colors.teal),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Il valore deve essere impostato';
                      final parsed = double.tryParse(value.replaceAll(',', '.'));
                      if (parsed == null || parsed <= 0) return 'Inserisci un importo valido';
                      return null;
                    },
                  ),
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
        if (useModel && selectedModel == null) return;
        final name = nameController.text.trim();

        final DurationType effectiveFrequency = useModel ? (selectedModel?.payoutFrequency ?? DurationType.monthly) : frequency;
        final int effectiveDayOfMonth = startingDate.day;
        final int? effectiveMonthOfYear = effectiveFrequency.index >= DurationType.annual.index ? startingDate.month : null;

        await _saveTimeDeposit(
          context,
          selectedAccount!,
          useModel ? selectedModel : null,
          name,
          double.parse(initialValueController.text.trim().replaceAll(',', '.')),
          providerType,
          provider,
          double.tryParse(taxRateController.text) ?? 0.0,
          double.tryParse(interestRateController.text) ?? 0.0,
          duration,
          frequency,
          isCashable,
          double.tryParse(earlyWithdrawalController.text) ?? 0.0,
          startingDate,
          effectiveDayOfMonth,
          effectiveMonthOfYear,
        );

        if (context.mounted) {
          Navigator.pop(context);
        }
      },
    );
  }
}