import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mira_finance_tracker/classes/periodic_transactions/BankFee.dart';
import 'package:mira_finance_tracker/classes/periodic_transactions/Cashback.dart';

import 'package:mira_finance_tracker/backend/service/CurrentSession.dart';
import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';

import 'package:mira_finance_tracker/frontend/navbar/AppRoutes.dart';
import 'package:mira_finance_tracker/frontend/navbar/ResponsiveScaffold.dart';
import 'package:mira_finance_tracker/frontend/templates/ActionOperationPage.dart';

import 'package:mira_finance_tracker/frontend/actions/CounterPartyManagementPage.dart';
import 'package:mira_finance_tracker/frontend/actions/FinancialInstituteManagementPage.dart';
import 'package:mira_finance_tracker/frontend/actions/NewCurrentAccountPage.dart';
import 'package:mira_finance_tracker/frontend/actions/NewSavingsAccountPage.dart';
import 'package:mira_finance_tracker/frontend/actions/NewCardAccountPage.dart';
import 'package:mira_finance_tracker/frontend/actions/NewPeriodicAccountBillingPage.dart';

/// ACTION PAGES from the functional analysis: entry point to add bank
/// accounts, financial institutes, operations and financial instruments,
/// grouped by category and displayed as a two-column grid on wide screens.
class ActionsPage extends StatefulWidget {
  const ActionsPage({super.key});

  @override
  State<ActionsPage> createState() => _ActionsPageState();
}

class _ActionsPageState extends State<ActionsPage> {
  late final Future<UserDatabaseWrapper> _databaseFuture;
  UserDatabaseWrapper? _database;

  @override
  void initState() {
    super.initState();
    _databaseFuture = _initializeDatabase();
  }

  @override
  void dispose(){
    final database = _database;
    if (database != null) {
      unawaited(database.closeDatabase());
    }
    super.dispose();
  }

  Future<UserDatabaseWrapper> _initializeDatabase() async {
    final session = await CurrentSession.getFromMemory();

    if (session == null) {
      throw StateError('Nessuna sessione attiva.');
    }

    final database = UserDatabaseWrapper(session.user);
    await database.init();
    _database = database;

    return database;
  }

  // Placeholder category/action list: replace with the real one.
  static final List<_ActionCategory> _categories = [
    _ActionCategory(
      title: 'Conti e operazioni',
      color: Colors.teal,
      actions: [
        _ActionItem(
          label: 'Nuovo conto corrente',
          icon: Icons.account_balance,
          pageBuilder: (context, database) => NewCurrentAccountPage(database: database)
        ),
        _ActionItem(
          label: 'Nuovo conto deposito',
          icon: Icons.account_balance,
          pageBuilder: (context, database) => NewSavingsAccountPage(database: database)
        ),
        _ActionItem(
          label: 'Nuova carta',
          icon: Icons.card_membership,
          pageBuilder: (context, database) => NewCardAccountPage(database: database)
        ),
        _ActionItem(
          label: 'Nuovo cashback conto',
          icon: Icons.monetization_on,
          pageBuilder: (context, database) => PeriodicBillingFormPage(title: 'Aggiungi cashback', nameLabel: 'Cashback', database: database, classRequested: Cashback)
        ),
        _ActionItem(
          label: 'Nuova commissione conto',
          icon: Icons.money_off,
          pageBuilder: (context, database) => PeriodicBillingFormPage(title: 'Aggiungi commissione', nameLabel: 'Commissione', database: database, classRequested: BankFee)
        ),
      ],
    ),
    _ActionCategory(
      title: 'Movimenti',
      color: Colors.indigo,
      actions: [
        _ActionItem(
          label: 'Nuova entrata',
          icon: Icons.arrow_downward,
          pageBuilder: (context, database) => ActionOperationPage(
            title: 'Nuova entrata',
            inputBuilder: (context) => const TextField(
              decoration: InputDecoration(labelText: 'Importo'),
            ),
            onConfirm: (context) async {
              // TODO: call the save/processing function for this action
              Navigator.pop(context);
            },
          ),
        ),
        _ActionItem(
          label: 'Nuova uscita',
          icon: Icons.arrow_upward,
          pageBuilder: (context, database) => ActionOperationPage(
            title: 'Nuova uscita',
            inputBuilder: (context) => const TextField(
              decoration: InputDecoration(labelText: 'Importo'),
            ),
            onConfirm: (context) async {
              // TODO: call the save/processing function for this action
              Navigator.pop(context);
            },
          ),
        ),
      ],
    ),
    _ActionCategory(
      title: 'Rubrica',
      color: Colors.orangeAccent,
      actions: [
        _ActionItem(
          label: 'Gestisci contatti',
          icon: Icons.person_outline,
          pageBuilder: (context, database) => CounterpartyManagementPage(database: database),
        ),
        _ActionItem(
          label: 'Gestisci istituti finanziari',
          icon: Icons.business,
          pageBuilder: (context, database) => FinancialInstituteManagementPage(database: database),
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      currentRoute: AppRoutes.actions,
      title: 'Azioni',
      body: FutureBuilder<UserDatabaseWrapper>(
        future: _databaseFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Errore nel caricamento: ${snapshot.error}'));
          }

          return _buildActionsContent(context, snapshot.data!);
        },
      ),
    );
  }

  Widget _buildActionsContent(BuildContext context, UserDatabaseWrapper database) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final category in _categories) ...[
                    _sectionCard(category.title, _buildActionGrid(context, category, isWide, database)),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionGrid(
    BuildContext context,
    _ActionCategory category,
    bool isWide,
    UserDatabaseWrapper database,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: category.actions.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isWide ? 2 : 1,
        mainAxisSpacing: 8,
        crossAxisSpacing: 16,
        mainAxisExtent: 64,
      ),
      itemBuilder: (context, index) => _buildActionTile(context, category, category.actions[index], database),
    );
  }

  Widget _buildActionTile(
    BuildContext context,
    _ActionCategory category,
    _ActionItem action,
    UserDatabaseWrapper database,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => action.pageBuilder(context, database)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: CircleAvatar(
          backgroundColor: category.color.withOpacity(0.12),
          child: Icon(action.icon, color: category.color, size: 18),
        ),
        title: Text(action.label, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
      ),
    );
  }

  Widget _sectionCard(String title, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ActionCategory {
  final String title;
  final Color color;
  final List<_ActionItem> actions;

  const _ActionCategory({required this.title, required this.color, required this.actions});
}

class _ActionItem {
  final String label;
  final IconData icon;
  final Widget Function(BuildContext, UserDatabaseWrapper) pageBuilder;

  const _ActionItem({required this.label, required this.icon, required this.pageBuilder});
}