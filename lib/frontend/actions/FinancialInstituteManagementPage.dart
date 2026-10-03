import 'package:flutter/material.dart';

import 'package:mira_finance_tracker/classes/subjects/FinancialInstitute.dart';
import 'package:mira_finance_tracker/frontend/templates/EntityManagementPage.dart';
import 'package:mira_finance_tracker/frontend/templates/ActionOperationPage.dart';
import 'package:mira_finance_tracker/frontend/single_elements/UniqueNameField.dart';
import 'package:mira_finance_tracker/frontend/single_elements/Toast.dart';

import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';

class FinancialInstituteManagementPage extends StatelessWidget {
  final UserDatabaseWrapper database;

  const FinancialInstituteManagementPage({super.key, required this.database});

  Future<List<FinancialInstitute>> _loadInstitutes() async {
    return database.getFinancialInstitutes();
  }

  Future<bool> _isNameAvailable(String name) async {
    return database.checkFinancialInstituteAvailability(name);
  }

  Widget _buildForm(BuildContext context, {FinancialInstitute? existing}) {
    return _FinancialInstituteForm(
      database: database,
      existing: existing,
      isNameAvailable: _isNameAvailable,
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
      matchesQuery: (item, query) =>
          item.name.toLowerCase().contains(query.toLowerCase()),
      titleOf: (item) => item.name,
      subtitleOf: (item) =>
          item.phoneNumber.isNotEmpty ? item.phoneNumber : item.email,
      buildAddPage: (context) => _buildForm(context),
      buildEditPage: (context, item) => _buildForm(context, existing: item),
      deleteItem: (item) async {
        if (!(await database.checkFinancialInstituteDeletion(item))) {
          AppToast.show(context,
              "Eliminazione non riuscita. Elemento collegato ad altre entità",
              ToastType.warning);
          return;
        }
        await database.deleteFinancialInstitute(item);
      },
    );
  }
}

class _FinancialInstituteForm extends StatefulWidget {
  final UserDatabaseWrapper database;
  final FinancialInstitute? existing;
  final Future<bool> Function(String) isNameAvailable;

  const _FinancialInstituteForm({
    required this.database,
    required this.isNameAvailable,
    this.existing,
  });

  @override
  State<_FinancialInstituteForm> createState() =>
      _FinancialInstituteFormState();
}

class _FinancialInstituteFormState extends State<_FinancialInstituteForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _siteController;
  late bool _nameAvailable;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.existing?.name ?? '');
    _emailController =
        TextEditingController(text: widget.existing?.email ?? '');
    _phoneController =
        TextEditingController(text: widget.existing?.phoneNumber ?? '');
    _siteController =
        TextEditingController(text: widget.existing?.site ?? '');
    _nameAvailable = widget.existing != null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _siteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ActionOperationPage(
      title: widget.existing == null
          ? 'Nuovo istituto finanziario'
          : 'Modifica istituto finanziario',
      formKey: _formKey,
      inputBuilder: (context) => Form(
        key: _formKey,
        child: Column(
          children: [
            widget.existing == null
                ? UniqueNameField(
                    controller: _nameController,
                    label: 'Nome',
                    checkAvailability: widget.isNameAvailable,
                    onAvailabilityChanged: (available) =>
                        _nameAvailable = available,
                  )
                : TextFormField(
                    controller: _nameController,
                    enabled: false,
                    decoration: const InputDecoration(
                        labelText: 'Nome (non modificabile)'),
                  ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Telefono'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _siteController,
              decoration: const InputDecoration(labelText: 'Indirizzo'),
            ),
          ],
        ),
      ),
      onConfirm: (context) async {
        FinancialInstitute? newInstitute;
        if (widget.existing == null) {
          if (!_nameAvailable) return;
          newInstitute = FinancialInstitute(
            _nameController.text.trim(),
            email: _emailController.text.trim(),
            phoneNumber: _phoneController.text.trim(),
            site: _siteController.text.trim(),
          );
          await widget.database.saveFinancialInstitute(newInstitute);
        } else {
          widget.existing!.email = _emailController.text.trim();
          widget.existing!.phoneNumber = _phoneController.text.trim();
          widget.existing!.site = _siteController.text.trim();
          await widget.database.updateFinancialInstitute(widget.existing!);
        }

        if (context.mounted) {
          Navigator.pop(context, newInstitute);
        }
      },
    );
  }
}