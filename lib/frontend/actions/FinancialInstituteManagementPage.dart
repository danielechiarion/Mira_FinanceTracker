import 'package:flutter/material.dart';

import 'package:mira_finance_tracker/classes/subjects/FinancialInstitute.dart';
import 'package:mira_finance_tracker/frontend/templates/EntityManagementPage.dart';
import 'package:mira_finance_tracker/frontend/templates/ActionOperationPage.dart';
import 'package:mira_finance_tracker/frontend/single_elements/UniqueNameField.dart';

import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';

/// Management page for financial institutes: search, add, edit and
/// delete existing entries.
///
/// NOTE: [FinancialInstitute] has no setter for [name] (it is treated as
/// the immutable identity of the object). Because of this, the
/// edit form only allows address and phone number to be changed, and
/// the website can only be set when creating a new institute.
class FinancialInstituteManagementPage extends StatelessWidget {
  /* define attributes */
  final UserDatabaseWrapper database;

  const FinancialInstituteManagementPage({super.key, required this.database});

  Future<List<FinancialInstitute>> _loadInstitutes() async {
    return database.getFinancialInstitutes();
  }

  Future<bool> _isNameAvailable(String name) async {
    return database.checkFinancialInstituteAvailability(name);
  }

  Widget _buildForm(BuildContext context, {FinancialInstitute? existing}) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final emailController = TextEditingController(text: existing?.email ?? '');
    final phoneController = TextEditingController(text: existing?.phoneNumber ?? '');
    final siteController = TextEditingController(text: existing?.site ?? '');
    final formKey = GlobalKey<FormState>();
    bool nameAvailable = existing != null;

    return ActionOperationPage(
      title: existing == null ? 'Nuovo istituto finanziario' : 'Modifica istituto finanziario',
      formKey: formKey,
      inputBuilder: (context) => Form(
        key: formKey,
        child: Column(
          children: [
            existing == null
                ? UniqueNameField(
                    controller: nameController,
                    label: 'Nome',
                    checkAvailability: _isNameAvailable,
                    onAvailabilityChanged: (available) => nameAvailable = available,
                  )
                : TextFormField(
                    controller: nameController,
                    enabled: false,
                    decoration: const InputDecoration(labelText: 'Nome (non modificabile)'),
                  ),
            const SizedBox(height: 16),
            TextFormField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Telefono'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: siteController,
              decoration: const InputDecoration(labelText: 'Indirizzo'),
            ),
          ],
        ),
      ),
      onConfirm: (context) async {
        if (existing == null) {
          if (!nameAvailable) return;
          final newInstitute = FinancialInstitute(
            nameController.text.trim(),
            email: emailController.text.trim(),
            phoneNumber: phoneController.text.trim(),
            site: siteController.text.trim(),
          );
          await database.saveFinancialInstitute(newInstitute);
        } else {
          existing.email = emailController.text.trim();
          existing.phoneNumber = phoneController.text.trim();
          existing.site = siteController.text.trim();
          await database.updateFinancialInstitute(existing);
        }

        if (context.mounted) {
          Navigator.pop(context);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return EntityManagementPage<FinancialInstitute>(
      title: 'Istituti finanziari',
      searchHint: 'Cerca per nome',
      addLabel: 'Nuovo istituto',
      icon: Icons.account_balance_outlined,
      color: Colors.indigo,
      loadItems: _loadInstitutes,
      matchesQuery: (item, query) => item.name.toLowerCase().contains(query.toLowerCase()),
      titleOf: (item) => item.name,
      subtitleOf: (item) => item.phoneNumber.isNotEmpty ? item.phoneNumber : item.email,
      buildAddPage: (context) => _buildForm(context),
      buildEditPage: (context, item) => _buildForm(context, existing: item),
      deleteItem: (item) async {
        await database.deleteFinancialInstitute(item);
      },
    );
  }
}