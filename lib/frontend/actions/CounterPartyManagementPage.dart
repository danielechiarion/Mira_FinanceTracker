import 'package:flutter/material.dart';

import 'package:mira_finance_tracker/classes/subjects/CounterParty.dart';
import 'package:mira_finance_tracker/frontend/templates/EntityManagementPage.dart';
import 'package:mira_finance_tracker/frontend/templates/ActionOperationPage.dart';
import 'package:mira_finance_tracker/frontend/single_elements/UniqueNameField.dart';

import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';

/// Management page for the contacts used in operations (bank transfers,
/// domiciliations, etc.): search, add, edit and delete existing entries.
class CounterpartyManagementPage extends StatelessWidget {
  /* define attributes */
  final UserDatabaseWrapper database;

  const CounterpartyManagementPage({super.key, required this.database});

  Future<List<CounterParty>> _loadContacts() async {
    return database.getCounterParties();
  }

  Future<bool> _isNameAvailable(String name) async {
    return database.checkCounterpartyAvailability(name);
  }

  Widget _buildForm(BuildContext context, {CounterParty? existing}) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final ibanController = TextEditingController(text: existing?.IBAN ?? '');
    final formKey = GlobalKey<FormState>();
    bool nameAvailable = existing != null;

    return ActionOperationPage(
      title: existing == null ? 'Nuovo contatto' : 'Modifica contatto',
      formKey: formKey,
      inputBuilder: (context) => Form(
        key: formKey,
        child: Column(
          children: [
            UniqueNameField(
              controller: nameController,
              label: 'Nome',
              initialName: existing?.name,
              checkAvailability: _isNameAvailable,
              onAvailabilityChanged: (available) => nameAvailable = available,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: ibanController,
              decoration: const InputDecoration(labelText: 'IBAN'),
              validator: (value) => (value == null || value.isEmpty) ? 'Il valore deve essere impostato' : null,
            ),
          ],
        ),
      ),
      onConfirm: (context) async {
        if (!nameAvailable) return;

        if (existing == null) {
          final newContact = CounterParty(nameController.text.trim(), IBAN: ibanController.text.trim());
          await database.saveCounterparty(newContact);
        } else {
          existing.name = nameController.text.trim();
          existing.IBAN = ibanController.text.trim();
          await database.updateConterparty(existing);
        }

        if (context.mounted) {
          Navigator.pop(context);
        }
      },
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
      matchesQuery: (item, query) => item.name.toLowerCase().contains(query.toLowerCase()) ||
          item.IBAN.toLowerCase().contains(query.toLowerCase()),
      titleOf: (item) => item.name,
      subtitleOf: (item) => item.IBAN,
      buildAddPage: (context) => _buildForm(context),
      buildEditPage: (context, item) => _buildForm(context, existing: item),
      deleteItem: (item) async {
        await database.deleteCounterparty(item);
      },
    );
  }
}