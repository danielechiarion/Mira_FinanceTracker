import 'package:flutter/material.dart';

import 'package:mira_finance_tracker/classes/financial_instruments/model/FinancialInstrumentModel.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/model/TimeDepositModel.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/model/BondModel.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/elements/StepInterest.dart';
import 'package:mira_finance_tracker/classes/subjects/FinancialInstitute.dart';
import 'package:mira_finance_tracker/classes/time_management/LongDuration.dart';
import 'package:mira_finance_tracker/classes/time_management/DurationType.dart';

import 'package:mira_finance_tracker/frontend/templates/ActionOperationPage.dart';
import 'package:mira_finance_tracker/frontend/single_elements/UniqueNameField.dart';
import 'package:mira_finance_tracker/frontend/single_elements/Toast.dart';
import 'package:mira_finance_tracker/frontend/single_elements/LongDurationField.dart';
import 'package:mira_finance_tracker/frontend/single_elements/DollarAmountField.dart';
import 'package:mira_finance_tracker/frontend/actions/StepInterestEditor.dart';

import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';

/// Management page for financial instrument models: time deposits and
/// bonds are shown as two separate, independently manageable previews,
/// each with its own add / edit / delete flow, following the same
/// graphics and structure used by [FinancialInstituteManagementPage].
///
/// NOTE: just like [FinancialInstitute.name], [FinancialInstrumentModel.name]
/// and [FinancialInstrumentModel.providerType] / [FinancialInstrumentModel.provider]
/// have no setters on the base model (they identify the instrument and
/// can't change after creation). Because of this, the edit forms only
/// allow duration, payout frequency, description, tax rate and the
/// type-specific fields (interest rate / cashability for time deposits,
/// interest type / step interests for bonds) to be modified.
///
/// ASSUMPTIONS MADE WHILE BUILDING THIS PAGE (please double-check them
/// against the real project before wiring it up):
/// * [DurationType] is assumed to expose a custom `name` field with an
///   Italian display label, following the same pattern already used by
///   [BondType] and [FinancialInstrumentProvider].
/// * every call into [UserDatabaseWrapper] for time deposits and bonds
///   (get / save / update / delete / name availability) is a guess at
///   the actual method name; each one is marked with a "TODO" comment
///   so they are easy to find and align with the real wrapper API.
class FinancialInstrumentModelManagementPage extends StatefulWidget {
  final UserDatabaseWrapper database;

  const FinancialInstrumentModelManagementPage({super.key, required this.database});

  @override
  State<FinancialInstrumentModelManagementPage> createState() => _FinancialInstrumentModelManagementPageState();
}

class _FinancialInstrumentModelManagementPageState extends State<FinancialInstrumentModelManagementPage> {
  late Future<List<TimeDepositModel>> _timeDepositsFuture;
  late Future<List<BondModel>> _bondsFuture;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _timeDepositsFuture = _loadTimeDeposits();
    _bondsFuture = _loadBonds();
  }

  /* *** DATA LOADING *** */

  Future<List<TimeDepositModel>> _loadTimeDeposits() async {
    return widget.database.getTimeDepositModels();
  }

  Future<List<BondModel>> _loadBonds() async {
    return widget.database.getBondModels();
  }

  Future<void> _reloadTimeDeposits() async {
    final future = _loadTimeDeposits();
    if (!mounted) return;
    setState(() => _timeDepositsFuture = future);
    await future;
  }

  Future<void> _reloadBonds() async {
    final future = _loadBonds();
    if (!mounted) return;
    setState(() => _bondsFuture = future);
    await future;
  }

  /// Checks, among the time deposits already saved, whether [name] is
  /// still available (uniqueness only applies within the same model
  /// type, see [FinancialInstrumentModel.operator==]).
  Future<bool> _isTimeDepositNameAvailable(String name) async {
    return widget.database.checkTimeDepositModelNameAvailability(name);
  }

  /// Checks, among the bonds already saved, whether [name] is still
  /// available.
  Future<bool> _isBondNameAvailable(String name) async {
    return widget.database.checkBondModelNameAvailability(name);
  }

  /* *** TIME DEPOSIT ACTIONS *** */

  Future<void> _openAddTimeDepositPage() async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => _buildTimeDepositForm(context)));
    await _reloadTimeDeposits();
  }

  Future<void> _openEditTimeDepositPage(TimeDepositModel item) async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => _buildTimeDepositForm(context, existing: item)));
    await _reloadTimeDeposits();
  }

  Future<void> _confirmDeleteTimeDeposit(TimeDepositModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Conferma eliminazione', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Vuoi eliminare "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ANNULLA', style: TextStyle(color: Colors.teal)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ELIMINA'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!(await widget.database.checkTimeDepositModelDeletion(item))) {
      if (context.mounted) {
        AppToast.show(context, "Eliminazione non riuscita. Elemento collegato ad altre entità", ToastType.warning);
      }
      return;
    }

    await widget.database.deleteTimeDepositModel(item);
    await _reloadTimeDeposits();
  }

  /* *** BOND ACTIONS *** */

  Future<void> _openAddBondPage() async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => _buildBondForm(context)));
    await _reloadBonds();
  }

  Future<void> _openEditBondPage(BondModel item) async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => _buildBondForm(context, existing: item)));
    await _reloadBonds();
  }

  Future<void> _confirmDeleteBond(BondModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Conferma eliminazione', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Vuoi eliminare "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ANNULLA', style: TextStyle(color: Colors.teal)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ELIMINA'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!(await widget.database.checkBondModelDeletion(item))) {
      if (context.mounted) {
        AppToast.show(context, "Eliminazione non riuscita. Elemento collegato ad altre entità", ToastType.warning);
      }
      return;
    }

    await widget.database.deleteBondModel(item);
    await _reloadBonds();
  }

  /* *** SHARED FORM HELPERS *** */

  /// Read-only representation of provider type / provider, shown when
  /// editing an existing instrument (see class-level NOTE above).
  Widget _buildReadOnlyProviderField(FinancialInstrumentProvider providerType, FinancialInstitute? provider) {
    final String text = provider != null ? '${providerType.name} (${provider.name})' : providerType.name;
    return TextFormField(
      initialValue: text,
      enabled: false,
      decoration: const InputDecoration(labelText: 'Fornitore (non modificabile)'),
    );
  }

  /* *** TIME DEPOSIT FORM *** */

  Widget _buildTimeDepositForm(BuildContext context, {TimeDepositModel? existing}) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final descriptionController = TextEditingController(text: existing?.description ?? '');
    final taxRateController = TextEditingController(text: existing != null ? existing.taxRate.toString() : '0');
    final interestRateController = TextEditingController(text: existing?.interestRate.toString() ?? '');
    final earlyWithdrawalController = TextEditingController(text: existing?.earlyWithdrawalInterestRate.toString() ?? '0');
    final formKey = GlobalKey<FormState>();

    bool nameAvailable = existing != null;
    FinancialInstrumentProvider providerType = existing?.providerType ?? FinancialInstrumentProvider.financialInstitution;
    FinancialInstitute? provider = existing?.provider;
    LongDuration duration = existing?.duration ?? const LongDuration();
    DurationType payoutFrequency = existing?.payoutFrequency ?? DurationType.values.first;
    bool isCashable = existing?.isCashable ?? true;

    return ActionOperationPage(
      title: existing == null ? 'Nuovo deposito a tempo' : 'Modifica deposito a tempo',
      formKey: formKey,
      inputBuilder: (context) => Form(
        key: formKey,
        child: Column(
          children: [
            existing == null
                ? UniqueNameField(
                    controller: nameController,
                    label: 'Nome',
                    checkAvailability: _isTimeDepositNameAvailable,
                    onAvailabilityChanged: (available) => nameAvailable = available,
                  )
                : TextFormField(
                    controller: nameController,
                    enabled: false,
                    decoration: const InputDecoration(labelText: 'Nome (non modificabile)'),
                  ),
            const SizedBox(height: 16),
            existing == null
                ? _ProviderSection(
                    database: widget.database,
                    initialProviderType: providerType,
                    initialProvider: provider,
                    onChanged: (newType, newProvider) {
                      providerType = newType;
                      provider = newProvider;
                    },
                  )
                : _buildReadOnlyProviderField(providerType, provider),
            const SizedBox(height: 16),
            LongDurationField(
              label: 'Durata',
              initialValue: duration,
              onChanged: (value) => duration = value,
            ),
            const SizedBox(height: 16),
            _DurationTypeDropdown(
              label: 'Frequenza pagamento interessi',
              initialValue: payoutFrequency,
              onChanged: (value) => payoutFrequency = value,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Descrizione'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            DollarAmountField(controller: taxRateController, label: 'Aliquota fiscale'),
            const SizedBox(height: 16),
            DollarAmountField(controller: interestRateController, label: 'Tasso di interesse annuo', isRequired: true),
            const SizedBox(height: 16),
            _CashableSection(
              initialIsCashable: isCashable,
              earlyWithdrawalController: earlyWithdrawalController,
              onCashableChanged: (value) => isCashable = value,
            ),
          ],
        ),
      ),
      onConfirm: (context) async {
        if (existing == null && !nameAvailable) return;

        final double taxRate = double.tryParse(taxRateController.text) ?? 0.0;
        final double interestRate = double.tryParse(interestRateController.text) ?? 0.0;
        final double earlyWithdrawalRate = double.tryParse(earlyWithdrawalController.text) ?? 0.0;

        if (existing == null) {
          final newTimeDeposit = TimeDepositModel(
            nameController.text.trim(),
            providerType,
            duration,
            payoutFrequency,
            interestRate,
            description: descriptionController.text.trim(),
            provider: provider,
            taxRate: taxRate,
            isCashable: isCashable,
            earlyWithdrawalInterestRate: earlyWithdrawalRate,
          );

          await widget.database.saveTimeDepositModel(newTimeDeposit);
        } else {
          existing.description = descriptionController.text.trim();
          existing.taxRate = taxRate;
          existing.interestRate = interestRate;
          existing.isCashable = isCashable;
          existing.earlyWithdrawalInterestRate = earlyWithdrawalRate;
          existing.duration = duration;
          existing.payoutFrequency = payoutFrequency;

          await widget.database.updateTimeDepositModel(existing);
        }

        if (context.mounted) {
          Navigator.pop(context);
        }
      },
    );
  }

  /* *** BOND FORM *** */

  Widget _buildBondForm(BuildContext context, {BondModel? existing}) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final descriptionController = TextEditingController(text: existing?.description ?? '');
    final taxRateController = TextEditingController(text: existing != null ? existing.taxRate.toString() : '0');
    final formKey = GlobalKey<FormState>();

    bool nameAvailable = existing != null;
    FinancialInstrumentProvider providerType = existing?.providerType ?? FinancialInstrumentProvider.financialInstitution;
    FinancialInstitute? provider = existing?.provider;
    LongDuration duration = existing?.duration ?? const LongDuration();
    DurationType payoutFrequency = existing?.payoutFrequency ?? DurationType.values.first;
    BondType interestType = existing?.interestType ?? BondType.fixed;
    List<StepInterest> interests = existing?.interests ?? [];

    return ActionOperationPage(
      title: existing == null ? 'Nuova obbligazione' : 'Modifica obbligazione',
      formKey: formKey,
      inputBuilder: (context) => Form(
        key: formKey,
        child: Column(
          children: [
            existing == null
                ? UniqueNameField(
                    controller: nameController,
                    label: 'Nome',
                    checkAvailability: _isBondNameAvailable,
                    onAvailabilityChanged: (available) => nameAvailable = available,
                  )
                : TextFormField(
                    controller: nameController,
                    enabled: false,
                    decoration: const InputDecoration(labelText: 'Nome (non modificabile)'),
                  ),
            const SizedBox(height: 16),
            existing == null
                ? _ProviderSection(
                    database: widget.database,
                    initialProviderType: providerType,
                    initialProvider: provider,
                    onChanged: (newType, newProvider) {
                      providerType = newType;
                      provider = newProvider;
                    },
                  )
                : _buildReadOnlyProviderField(providerType, provider),
            const SizedBox(height: 16),
            LongDurationField(
              label: 'Durata',
              initialValue: duration,
              onChanged: (value) => duration = value,
            ),
            const SizedBox(height: 16),
            _DurationTypeDropdown(
              label: 'Frequenza pagamento interessi',
              initialValue: payoutFrequency,
              onChanged: (value) => payoutFrequency = value,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Descrizione'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            DollarAmountField(controller: taxRateController, label: 'Aliquota fiscale'),
            const SizedBox(height: 16),
            _InterestTypeSection(
              initialInterestType: interestType,
              initialInterests: interests,
              onChanged: (newType, newInterests) {
                interestType = newType;
                interests = newInterests;
              },
            ),
          ],
        ),
      ),
      onConfirm: (context) async {
        if (existing == null && !nameAvailable) return;

        final double taxRate = double.tryParse(taxRateController.text) ?? 0.0;

        if (existing == null) {
          final newBond = BondModel(
            nameController.text.trim(),
            providerType,
            duration,
            payoutFrequency,
            interestType,
            description: descriptionController.text.trim(),
            provider: provider,
            taxRate: taxRate,
            interests: interests.toSet(),
          );

          await widget.database.saveBondModel(newBond);
        } else {
          existing.description = descriptionController.text.trim();
          existing.taxRate = taxRate;
          existing.duration = duration;
          existing.payoutFrequency = payoutFrequency;
          existing.interestType = interestType;
          existing.interests = interests;

          await widget.database.updateBondModel(existing);
        }

        if (context.mounted) {
          Navigator.pop(context);
        }
      },
    );
  }

  /* *** PAGE LAYOUT *** */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Strumenti finanziari', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchField(),
                  const SizedBox(height: 24),
                  _buildSectionHeader(
                    title: 'Depositi a tempo',
                    addLabel: 'Nuovo deposito',
                    onAdd: _openAddTimeDepositPage,
                  ),
                  const SizedBox(height: 12),
                  _buildTimeDepositList(),
                  const SizedBox(height: 32),
                  _buildSectionHeader(
                    title: 'Obbligazioni',
                    addLabel: 'Nuova obbligazione',
                    onAdd: _openAddBondPage,
                  ),
                  const SizedBox(height: 12),
                  _buildBondList(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Cerca per nome',
        prefixIcon: const Icon(Icons.search, color: Colors.teal),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
      ),
      onChanged: (value) => setState(() => _query = value),
    );
  }

  Widget _buildSectionHeader({required String title, required String addLabel, required VoidCallback onAdd}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ElevatedButton.icon(
          onPressed: onAdd,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.add),
          label: Text(addLabel),
        ),
      ],
    );
  }

  Widget _buildTimeDepositList() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: FutureBuilder<List<TimeDepositModel>>(
        future: _timeDepositsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(color: Colors.teal)),
            );
          }
          if (snapshot.hasError) {
            return Text('Errore nel caricamento: ${snapshot.error}');
          }

          final items = snapshot.data!.where((item) => item.name.toLowerCase().contains(_query.toLowerCase())).toList();
          if (items.isEmpty) {
            return const Text('Nessun deposito trovato');
          }

          return Column(children: items.map(_buildTimeDepositTile).toList());
        },
      ),
    );
  }

  Widget _buildTimeDepositTile(TimeDepositModel item) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Colors.teal.withOpacity(0.12),
        child: const Icon(Icons.savings_outlined, color: Colors.teal, size: 18),
      ),
      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('Tasso: \$${item.interestRate} • Durata: ${item.duration}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.teal),
            onPressed: () => _openEditTimeDepositPage(item),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _confirmDeleteTimeDeposit(item),
          ),
        ],
      ),
    );
  }

  Widget _buildBondList() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: FutureBuilder<List<BondModel>>(
        future: _bondsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(color: Colors.teal)),
            );
          }
          if (snapshot.hasError) {
            return Text('Errore nel caricamento: ${snapshot.error}');
          }

          final items = snapshot.data!.where((item) => item.name.toLowerCase().contains(_query.toLowerCase())).toList();
          if (items.isEmpty) {
            return const Text('Nessuna obbligazione trovata');
          }

          return Column(children: items.map(_buildBondTile).toList());
        },
      ),
    );
  }

  Widget _buildBondTile(BondModel item) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Colors.indigo.withOpacity(0.12),
        child: const Icon(Icons.receipt_long_outlined, color: Colors.indigo, size: 18),
      ),
      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${item.interestType.name} • Durata: ${item.duration}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.teal),
            onPressed: () => _openEditBondPage(item),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _confirmDeleteBond(item),
          ),
        ],
      ),
    );
  }
}

/// Section letting the user pick, at creation time only, which type of
/// provider offers the financial instrument and — when it's a private
/// institution — which specific [FinancialInstitute] provides it.
///
/// NOTE: [FinancialInstrumentModel] doesn't expose a setter for either
/// providerType or provider, so this section is only used while
/// creating a new instrument; existing ones show this information as
/// read-only (see [_FinancialInstrumentManagementPageState._buildReadOnlyProviderField]).
class _ProviderSection extends StatefulWidget {
  final UserDatabaseWrapper database;
  final FinancialInstrumentProvider initialProviderType;
  final FinancialInstitute? initialProvider;
  final void Function(FinancialInstrumentProvider providerType, FinancialInstitute? provider) onChanged;

  const _ProviderSection({
    required this.database,
    required this.onChanged,
    this.initialProviderType = FinancialInstrumentProvider.financialInstitution,
    this.initialProvider,
  });

  @override
  State<_ProviderSection> createState() => _ProviderSectionState();
}

class _ProviderSectionState extends State<_ProviderSection> {
  late FinancialInstrumentProvider _providerType;
  FinancialInstitute? _provider;
  late Future<List<FinancialInstitute>> _institutesFuture;

  @override
  void initState() {
    super.initState();
    _providerType = widget.initialProviderType;
    _provider = widget.initialProvider;
    // this call already exists on UserDatabaseWrapper, see FinancialInstituteManagementPage
    _institutesFuture = widget.database.getFinancialInstitutes();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<FinancialInstrumentProvider>(
          value: _providerType,
          decoration: const InputDecoration(labelText: 'Tipo di fornitore'),
          items: FinancialInstrumentProvider.values
              .map((value) => DropdownMenuItem(value: value, child: Text(value.name)))
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _providerType = value;
              if (value != FinancialInstrumentProvider.financialInstitution) {
                _provider = null;
              }
            });
            widget.onChanged(_providerType, _provider);
          },
        ),
        if (_providerType == FinancialInstrumentProvider.financialInstitution) ...[
          const SizedBox(height: 16),
          FutureBuilder<List<FinancialInstitute>>(
            future: _institutesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: Colors.teal));
              }

              final institutes = snapshot.data ?? [];

              // match by name since FinancialInstitute treats it as its identity
              FinancialInstitute? selectedValue;
              if (_provider != null) {
                final matches = institutes.where((i) => i.name == _provider!.name);
                selectedValue = matches.isNotEmpty ? matches.first : null;
              }

              return DropdownButtonFormField<FinancialInstitute>(
                value: selectedValue,
                decoration: const InputDecoration(labelText: 'Istituto finanziario'),
                items: institutes.map((institute) => DropdownMenuItem(value: institute, child: Text(institute.name))).toList(),
                onChanged: (value) {
                  setState(() => _provider = value);
                  widget.onChanged(_providerType, _provider);
                },
              );
            },
          ),
        ],
      ],
    );
  }
}

/// Simple dropdown to pick a [DurationType] value, showing its
/// display name.
class _DurationTypeDropdown extends StatefulWidget {
  final String label;
  final DurationType initialValue;
  final ValueChanged<DurationType> onChanged;

  const _DurationTypeDropdown({
    required this.label,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<_DurationTypeDropdown> createState() => _DurationTypeDropdownState();
}

class _DurationTypeDropdownState extends State<_DurationTypeDropdown> {
  late DurationType _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<DurationType>(
      value: _value,
      decoration: InputDecoration(labelText: widget.label),
      items: DurationType.values.map((value) => DropdownMenuItem(value: value, child: Text(value.name))).toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() => _value = value);
        widget.onChanged(value);
      },
    );
  }
}

/// Section handling the "cashable" switch of a time deposit and,
/// when active, the early withdrawal interest rate field associated
/// with it.
class _CashableSection extends StatefulWidget {
  final bool initialIsCashable;
  final TextEditingController earlyWithdrawalController;
  final ValueChanged<bool> onCashableChanged;

  const _CashableSection({
    required this.initialIsCashable,
    required this.earlyWithdrawalController,
    required this.onCashableChanged,
  });

  @override
  State<_CashableSection> createState() => _CashableSectionState();
}

class _CashableSectionState extends State<_CashableSection> {
  late bool _isCashable;

  @override
  void initState() {
    super.initState();
    _isCashable = widget.initialIsCashable;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Riscattabile prima della scadenza'),
          value: _isCashable,
          activeColor: Colors.indigo,
          onChanged: (value) {
            setState(() => _isCashable = value);
            widget.onCashableChanged(value);
          },
        ),
        if (_isCashable) ...[
          const SizedBox(height: 8),
          DollarAmountField(
            controller: widget.earlyWithdrawalController,
            label: 'Tasso di interesse per riscatto anticipato',
          ),
        ],
      ],
    );
  }
}

/// Section handling the [BondType] dropdown and, for fixed and step
/// bonds, the list of [StepInterest] entries associated with them.
///
/// Variable-rate bonds don't have a predetermined interest, so the
/// step editor is hidden in that case.
class _InterestTypeSection extends StatefulWidget {
  final BondType initialInterestType;
  final List<StepInterest> initialInterests;
  final void Function(BondType interestType, List<StepInterest> interests) onChanged;

  const _InterestTypeSection({
    required this.initialInterestType,
    required this.onChanged,
    this.initialInterests = const [],
  });

  @override
  State<_InterestTypeSection> createState() => _InterestTypeSectionState();
}

class _InterestTypeSectionState extends State<_InterestTypeSection> {
  late BondType _interestType;
  late List<StepInterest> _interests;

  @override
  void initState() {
    super.initState();
    _interestType = widget.initialInterestType;
    _interests = widget.initialInterests;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<BondType>(
          value: _interestType,
          decoration: const InputDecoration(labelText: 'Tipo di tasso'),
          items: BondType.values.map((value) => DropdownMenuItem(value: value, child: Text(value.name))).toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _interestType = value);
            widget.onChanged(_interestType, _interests);
          },
        ),
        if (_interestType != BondType.variable) ...[
          const SizedBox(height: 16),
          StepInterestEditor(
            initialInterests: _interests,
            onChanged: (value) {
              _interests = value;
              widget.onChanged(_interestType, _interests);
            },
          ),
        ],
      ],
    );
  }
}