import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';
import 'package:mira_finance_tracker/classes/bank_account/SavingsAccount.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/model/FinancialInstrumentModel.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/model/BondModel.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/service/Bond.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/elements/StepInterest.dart';
import 'package:mira_finance_tracker/classes/subjects/FinancialInstitute.dart';
import 'package:mira_finance_tracker/classes/time_management/DurationType.dart';
import 'package:mira_finance_tracker/classes/time_management/LongDuration.dart';
import 'package:mira_finance_tracker/frontend/templates/ActionOperationPage.dart';
import 'package:mira_finance_tracker/frontend/single_elements/LongDurationField.dart';
import 'package:mira_finance_tracker/frontend/single_elements/NumericAmountField.dart';
import 'package:mira_finance_tracker/frontend/single_elements/UniqueNameField.dart';
import 'package:mira_finance_tracker/frontend/single_elements/Toast.dart';
import 'package:mira_finance_tracker/frontend/actions/StepInterestEditor.dart';

/// Page to actually subscribe a [Bond] on a savings account ("conto
/// deposito"), built on top of [ActionOperationPage] just like
/// [NewTimeDepositPage] and [PeriodicBillingFormPage]: a single
/// [StatefulBuilder] wraps the whole [Form] so every conditional field
/// (account selected, model chosen, interest type, month of year, ...)
/// can react locally.
///
/// The user can either build the bond from scratch, filling in every
/// financial condition by hand, or pick one of the saved [BondModel].
/// In the latter case every field the model already defines (provider,
/// tax rate, duration, payout frequency, interest type, coupon
/// schedule) is locked and shown as a read-only summary; only the
/// instance-specific data (name, initial value, purchase price, minimum
/// denomination, starting date) stays editable, exactly as
/// [Bond.fromModel] expects it.
///
/// NOTE: [purchasePrice] and [minimumDenomination] have no equivalent on
/// [BondModel], so they stay editable regardless of the creation mode.
///
/// ASSUMPTIONS MADE WHILE BUILDING THIS PAGE (please double-check them
/// against the real project before wiring it up):
/// * bonds are assumed to be subscribed on a [SavingsAccount], the same
///   account type used by [NewTimeDepositPage], since no other account
///   class was shared for this instrument.
/// * [includeStart], [includeEnd], [lastDateActivity] and [currentValue]
///   are left to their defaults and not exposed here, matching
///   [NewTimeDepositPage].
/// * day and month of payout are derived from the chosen starting date
///   (`startingDate.day` / `startingDate.month`), exactly like the final
///   [NewTimeDepositPage] does, instead of asking for them separately.
class NewBondPage extends StatefulWidget {
  final UserDatabaseWrapper database;

  const NewBondPage({super.key, required this.database});

  @override
  State<NewBondPage> createState() => _NewBondPageState();
}

class _NewBondPageState extends State<NewBondPage> {
  late TextEditingController nameController;
  late TextEditingController initialValueController;
  late TextEditingController purchasePriceController;
  late TextEditingController minimumDenominationController;
  late TextEditingController taxRateController;
  late TextEditingController fixedRateController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
    initialValueController = TextEditingController();
    purchasePriceController = TextEditingController(text: '100');
    minimumDenominationController = TextEditingController(text: '1000');
    taxRateController = TextEditingController(text: '0');
    fixedRateController = TextEditingController();
  }

  @override
  void dispose() {
    nameController.dispose();
    initialValueController.dispose();
    purchasePriceController.dispose();
    minimumDenominationController.dispose();
    taxRateController.dispose();
    fixedRateController.dispose();
    super.dispose();
  }

  /// Bonds are assumed to be subscribed on the same account type used
  /// for time deposits (see class-level NOTE above).
  Future<List<SavingsAccount>> _loadAccounts() async {
    return await widget.database.getSavingsAccounts();
  }

  Future<List<BondModel>> _loadModels() async {
    return widget.database.getBondModels();
  }

  Future<List<FinancialInstitute>> _loadInstitutes() async {
    return widget.database.getFinancialInstitutes();
  }

  Future<bool> _isNameAvailable(String name) async {
    return widget.database.checkBondNameAvailability(name);
  }

  String? _validateInitialValue(String? value) {
    if (value == null || value.isEmpty) return 'Il valore deve essere impostato';

    final initialValue = double.tryParse(value.replaceAll(',', '.'));
    final minimumDenomination = double.tryParse(minimumDenominationController.text.replaceAll(',', '.'));
    if (initialValue == null || initialValue <= 0) return 'Inserisci un importo valido';
    if (minimumDenomination == null || minimumDenomination <= 0) return 'Inserisci prima un taglio minimo valido';
    if (initialValue < minimumDenomination) return "L'importo deve essere almeno pari al taglio minimo";

    final multiple = initialValue / minimumDenomination;
    if ((multiple - multiple.round()).abs() > 0.000001) {
      return 'L’importo deve essere un multiplo del taglio minimo';
    }

    return null;
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
        return 'Avviso: L\'istituto finanziario (${provider.name}) del titolo è diverso dalla banca del conto (${account.bank.name}). Operazione potrebbe non essere consentita.';
      }
    }

    return '';
  }

  /// Validates provider compatibility for a model-based bond
  String _validateModelProviderCompatibility(SavingsAccount account, BondModel model) {
    return _validateProviderCompatibility(account, model.providerType, model.provider);
  }

  Future<void> _saveBond(
    BuildContext context,
    SavingsAccount account,
    BondModel? model,
    String name,
    double initialValue,
    double purchasePrice,
    double minimumDenomination,
    FinancialInstrumentProvider providerType,
    FinancialInstitute? provider,
    double taxRate,
    BondType interestType,
    List<StepInterest> couponSchedule,
    LongDuration duration,
    DurationType frequency,
    DateTime startingDate,
    int dayOfMonth,
    int? monthOfYear,
  ) async {
    Bond bond; // declare variable for the instrument to save

    if (model != null) {
      bond = Bond.fromModel(
        model,
        name,
        initialValue,
        purchasePrice,
        startingDate: startingDate,
        day: dayOfMonth,
        month: monthOfYear,
        minimumDenomination: minimumDenomination,
      );
    } else {
      bond = Bond(
        name,
        providerType,
        initialValue,
        taxRate,
        startingDate,
        frequency,
        dayOfMonth,
        purchasePrice,
        interestType,
        monthOfYear: monthOfYear,
        provider: provider,
        duration: duration,
        minimumDenomination: minimumDenomination,
        couponSchedule: couponSchedule,
      );
    }
    await widget.database.saveAccountBond(account, bond);
  }

  /// Read-only summary of every field a chosen [BondModel] already
  /// defines: once picked, these can't be changed for the resulting
  /// bond (see [Bond.fromModel]).
  Widget _buildModelSummary(BondModel model) {
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
          Text('Durata: ${model.duration}'),
          Text('Frequenza pagamento interessi: ${model.payoutFrequency.name}'),
          Text('Tipo di tasso: ${model.interestType.name}'),
          if (model.interestType == BondType.fixed && model.interests.isNotEmpty)
            Text('Tasso di interesse annuo: ${model.interests.first.interestRate}%'),
          if (model.interestType == BondType.step)
            ...model.interests.map((step) => Text('Step ${step.position + 1}: ${step.duration} al ${step.interestRate}%')),
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
    BondModel? selectedModel;

    /* fields edited only when building the bond from scratch,
    since choosing a model locks all of them (see class-level NOTE) */
    FinancialInstrumentProvider providerType = FinancialInstrumentProvider.financialInstitution;
    FinancialInstitute? provider;
    LongDuration duration = const LongDuration();
    DurationType frequency = DurationType.monthly;
    BondType interestType = BondType.fixed;
    List<StepInterest> interests = [];

    /* fields always needed, model or not */
    DateTime startingDate = DateTime.now();

    return ActionOperationPage(
      title: 'Sottoscrivi una nuova obbligazione',
      formKey: formKey,
      inputBuilder: (context) => StatefulBuilder(
        builder: (context, setLocalState) {
          return Form(
            key: formKey,
            child: Column(
              children: [
                // --- ACCOUNT SELECTION (the bond is subscribed on a single savings account) ---
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
                    FutureBuilder<List<BondModel>>(
                      future: _loadModels(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(child: CircularProgressIndicator(color: Colors.teal));
                        }

                        final models = snapshot.data ?? [];
                        return DropdownButtonFormField<BondModel>(
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

                    // --- INTEREST TYPE (fixed uses a single rate, step needs its own schedule, variable needs none) ---
                    DropdownButtonFormField<BondType>(
                      value: interestType,
                      decoration: const InputDecoration(labelText: 'Tipo di tasso'),
                      items: BondType.values.map((value) => DropdownMenuItem(value: value, child: Text(value.name))).toList(),
                      onChanged: (value) => setLocalState(() => interestType = value ?? interestType),
                    ),
                    const SizedBox(height: 16),
                    if (interestType == BondType.fixed) ...[
                      InterestAmountField(controller: fixedRateController, label: 'Tasso di interesse annuo', isRequired: true),
                      const SizedBox(height: 16),
                    ] else if (interestType == BondType.step) ...[
                      StepInterestEditor(
                        initialInterests: interests,
                        onChanged: (value) => interests = value,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                  const SizedBox(height: 16),

                  // --- INSTANCE-SPECIFIC DATA (always editable, model or not) ---
                  UniqueNameField(
                    controller: nameController,
                    label: 'Nome obbligazione',
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
                    validator: _validateInitialValue,
                  ),
                  const SizedBox(height: 16),

                  InterestAmountField(controller: purchasePriceController, label: 'Prezzo di acquisto (% del valore nominale)', isRequired: true),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: minimumDenominationController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+[.,]?\d{0,2}'))],
                    decoration: const InputDecoration(
                      labelText: 'Taglio minimo',
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
        if (!useModel && interestType == BondType.step && interests.isEmpty) return;

        final name = nameController.text.trim();
        if (!await _isNameAvailable(name)) {
          if (context.mounted) {
            AppToast.show(context, 'Esiste già un’obbligazione con questo nome.', ToastType.error);
          }
          return;
        }

        if (useModel &&
            selectedModel!.providerType == FinancialInstrumentProvider.financialInstitution &&
            selectedModel!.provider == null) {
              AppToast.show(context, 'Il modello selezionato non ha un istituto finanziario associato.', ToastType.error);
              return;
        }

        final DurationType effectiveFrequency = useModel ? (selectedModel?.payoutFrequency ?? DurationType.monthly) : frequency;
        final int effectiveDayOfMonth = startingDate.day;
        final int? effectiveMonthOfYear = effectiveFrequency.index >= DurationType.annual.index ? startingDate.month : null;

        /* a fixed-rate bond only needs a single step covering the whole
        duration, exactly like FinancialInstrumentModelManagementPage does */
        final List<StepInterest> finalInterests = useModel
          ? []
          : interestType == BondType.fixed
            ? [StepInterest(0, duration, double.tryParse(fixedRateController.text) ?? 0.0)]
            : interests;

        try {
          await _saveBond(
            context,
            selectedAccount!,
            useModel ? selectedModel : null,
            name,
            double.parse(initialValueController.text.trim().replaceAll(',', '.')),
            double.tryParse(purchasePriceController.text) ?? 100.0,
            double.tryParse(minimumDenominationController.text.replaceAll(',', '.')) ?? 1000.0,
            providerType,
            provider,
            double.tryParse(taxRateController.text) ?? 0.0,
            interestType,
            finalInterests,
            duration,
            frequency,
            startingDate,
            effectiveDayOfMonth,
            effectiveMonthOfYear,
          );
        } catch (error) {
          if (context.mounted) {
            AppToast.show(context, 'Errore durante il salvataggio dell’obbligazione: $error', ToastType.fatal);
          }
          return;
        }

        if (context.mounted) {
          Navigator.pop(context);
        }
      },
    );
  }
}