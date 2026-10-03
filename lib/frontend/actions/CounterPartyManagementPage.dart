import 'package:flutter/material.dart';

import 'package:mira_finance_tracker/classes/subjects/CounterParty.dart';
import 'package:mira_finance_tracker/frontend/templates/EntityManagementPage.dart';
import 'package:mira_finance_tracker/frontend/templates/ActionOperationPage.dart';
import 'package:mira_finance_tracker/frontend/single_elements/UniqueNameField.dart';
import 'package:mira_finance_tracker/frontend/single_elements/Toast.dart';

import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';

class CounterpartyManagementPage extends StatelessWidget {
  final UserDatabaseWrapper database;

  const CounterpartyManagementPage({super.key, required this.database});

  Future<List<CounterParty>> _loadContacts() async {
    return database.getCounterParties();
  }

  Future<bool> _isNameAvailable(String name) async {
    return database.checkCounterpartyAvailability(name);
  }

  Widget _buildForm(BuildContext context, {CounterParty? existing}) {
    return _CounterpartyForm(
      database: database,
      existing: existing,
      isNameAvailable: _isNameAvailable,
    );
  }

  @override
  Widget build(BuildContext context) {
    return EntityManagementPage<CounterParty>(
      title: 'Contatti per operazioni',
      searchHint: 'Cerca per nome o IBAN',
      addLabel: 'Nuovo contatto',
      icon: Icons.person_outline,
      color: Colors.teal,
      loadItems: _loadContacts,
      matchesQuery: (item, query) =>
          item.name.toLowerCase().contains(query.toLowerCase()) ||
          item.IBAN.toLowerCase().contains(query.toLowerCase()),
      titleOf: (item) => item.name,
      subtitleOf: (item) => item.IBAN,
      buildAddPage: (context) => _buildForm(context),
      buildEditPage: (context, item) => _buildForm(context, existing: item),
      deleteItem: (item) async {
        if (!(await database.checkCounterPartyDeletion(item))) {
          AppToast.show(context,
              "Eliminazione non riuscita. Elemento collegato ad altre entità",
              ToastType.warning);
          return;
        }
        await database.deleteCounterparty(item);
      },
    );
  }
}

class _CounterpartyForm extends StatefulWidget {
  final UserDatabaseWrapper database;
  final CounterParty? existing;
  final Future<bool> Function(String) isNameAvailable;

  const _CounterpartyForm({
    required this.database,
    required this.isNameAvailable,
    this.existing,
  });

  @override
  State<_CounterpartyForm> createState() => _CounterpartyFormState();
}

class _CounterpartyFormState extends State<_CounterpartyForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _ibanController;
  late bool _nameAvailable;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _ibanController = TextEditingController(text: widget.existing?.IBAN ?? '');
    _nameAvailable = widget.existing != null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ibanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ActionOperationPage(
      title: widget.existing == null ? 'Nuovo contatto' : 'Modifica contatto',
      formKey: _formKey,
      inputBuilder: (context) => Form(
        key: _formKey,
        child: Column(
          children: [
            UniqueNameField(
              controller: _nameController,
              label: 'Nome',
              initialName: widget.existing?.name,
              checkAvailability: widget.isNameAvailable,
              onAvailabilityChanged: (available) => _nameAvailable = available,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ibanController,
              decoration: const InputDecoration(labelText: 'IBAN'),
            ),
          ],
        ),
      ),
      onConfirm: (context) async {
        if (!_nameAvailable) return;

        CounterParty? newContact;
        if (widget.existing == null) {
          newContact = CounterParty(
            _nameController.text.trim(),
            IBAN: _ibanController.text.trim(),
          );
          await widget.database.saveCounterparty(newContact);
        } else {
          widget.existing!.name = _nameController.text.trim();
          widget.existing!.IBAN = _ibanController.text.trim();
          await widget.database.updateConterparty(widget.existing!);
        }

        if (context.mounted) {
          Navigator.pop(context, newContact);
        }
      },
    );
  }
}