import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:mira_finance_tracker/frontend/navbar/AppRoutes.dart';
import 'package:mira_finance_tracker/frontend/navbar/ResponsiveScaffold.dart';
import 'package:mira_finance_tracker/frontend/bank_account/CurrentAccountPage.dart';
import 'package:mira_finance_tracker/frontend/bank_account/SavingsAccountPage.dart';
import 'package:mira_finance_tracker/frontend/bank_account/CardAccountPage.dart';
import 'package:mira_finance_tracker/frontend/single_elements/SummaryCard.dart';
import 'package:mira_finance_tracker/frontend/single_elements/TransactionOperationOutput.dart';
import 'package:mira_finance_tracker/frontend/charts/MonthlyTrendChart.dart';
import 'package:mira_finance_tracker/frontend/charts/PatrimonyPieChart.dart';
import 'package:mira_finance_tracker/backend/operation/chart/HomePageData.dart';
import 'package:mira_finance_tracker/backend/service/session/CurrentSession.dart';
import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';
import 'package:mira_finance_tracker/backend/service/UserDatabaseHandler.dart';
import 'package:mira_finance_tracker/classes/transaction/Income.dart';
import 'package:mira_finance_tracker/classes/transaction/Outgoing.dart';

import 'package:mira_finance_tracker/backend/cloud/operation/CloudFileImport.dart';
import 'package:mira_finance_tracker/frontend/error_pages/ErrorManager.dart';

/// REVIEW page from the functional analysis: summary of income, expenses,
/// and charts (asset distribution pie chart + monthly trend).
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

/// Identifies which account-type card was tapped in the accounts overview
/// section, so navigation can be routed accordingly once the target pages
/// exist.
enum _AccountSection { checking, deposit, cards }

class _HomePageState extends State<HomePage> {
  static String? _cloudImportSessionIdentity;
  static Future<void>? _cloudImportFuture;

  late Future<HomePageData> _summaryFuture;
  UserDatabaseWrapper? _database;
  String _loadingMessage = 'Caricamento dei dati...';

  @override
  void initState() {
    super.initState();
    _summaryFuture = _loadSession();
  }

  @override
  void dispose() {
    super.dispose();
  }

  /* function to load session data in order to display
  them inside the home page */
  Future<HomePageData> _loadSession({bool refreshCloud = false}) async {
    final session = await CurrentSession.getFromMemory();
    if (session == null) {
      throw StateError('Nessuna sessione attiva.');
    }

    if (mounted) {
      setState(() {
        _loadingMessage = 'Caricamento dei dati...';
      });
    }

    /* initialize the database once; loading the home page can be repeated */
    await _initializeDatabase(session);

    await _downloadCloudDataOnce(session, force: refreshCloud);

    if (mounted) {
      setState(() => _loadingMessage = 'Preparazione del riepilogo...');
    }
    final data = HomePageData(session.user);
    await data.init();

    return data;
  }

  Future<void> _initializeDatabase(CurrentSession session) async {
    await UserDatabaseHandler.openDatabase(session.user);
    final database = UserDatabaseHandler.database;
    if (database == null || !database.isDatabaseOpen) {
      throw StateError('Connessione al database utente non disponibile.');
    }
    _database = database;
  }

  Future<void> _downloadCloudDataOnce(
    CurrentSession session, {
    bool force = false,
  }) async {
    final user = session.user;
    final sessionIdentity =
        '${user.username}\u0000${user.email}\u0000${session.toMap()['accessTime']}';

    if (_cloudImportSessionIdentity != sessionIdentity) {
      _cloudImportSessionIdentity = sessionIdentity;
      _cloudImportFuture = null;
    }

    if (!user.isUserConnected) return;

    final currentImport = _cloudImportFuture;
    if (!force && currentImport != null) {
      await currentImport;
      return;
    }

    if (mounted) {
      setState(() {
        _loadingMessage = 'Importazione dei dati da Google Drive in corso...';
      });
    }

    final import = _downloadCloudData(session);
    _cloudImportFuture = import;
    try {
      await import;
    } catch (_) {
      if (identical(_cloudImportFuture, import)) {
        _cloudImportFuture = null;
      }
      rethrow;
    }
  }

  /* function to download data from cloud and 
  update the database or return possible errors from 
  the execution */
  Future<void> _downloadCloudData(CurrentSession session) async {
    /* call the class to manage all
    file import operation */
    final operation = CloudFileImport(
      session,
      showErrorFunction: ErrorManager.redirectToErrorPageImport,
    );
    try {
      await operation.init();
      await operation.execute();
    } finally {
      await operation.dispose();
    }
  }

  Future<void> _reload() async {
    final future = _loadSession(refreshCloud: true);
    setState(() {
      _summaryFuture = future;
      _loadingMessage = 'Aggiornamento dei dati...';
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      currentRoute: AppRoutes.home,
      title: 'Riepilogo',
      body: FutureBuilder<HomePageData>(
        future: _summaryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.teal),
                  const SizedBox(height: 16),
                  Text(
                    _loadingMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black87),
                  ),
                ],
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Errore nel caricamento dei dati: ${snapshot.error}'),
            );
          }

          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _reload,
            color: Colors.teal,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTotalBalance(data),
                          const SizedBox(height: 24),
                          _buildIncomeOutcomeCards(data, isWide),
                          const SizedBox(height: 32),
                          _buildCharts(data, isWide),
                          const SizedBox(height: 32),
                          _buildAccountsOverview(data, isWide),
                          const SizedBox(height: 32),
                          _sectionCard(
                            'Ultimi movimenti',
                            _buildRecentOperations(data),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTotalBalance(HomePageData data) {
    final formatter = NumberFormat.currency(locale: 'it_IT', symbol: '€');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Patrimonio totale',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          formatter.format(data.totalBalance),
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildIncomeOutcomeCards(HomePageData data, bool isWide) {
    final income = SummaryCard(
      label: 'Entrate (mese)',
      amount: data.periodIncome,
      currency: data.currency,
      icon: Icons.arrow_downward,
      color: Colors.green,
    );
    final outcome = SummaryCard(
      label: 'Uscite (mese)',
      amount: data.periodOutcome,
      currency: data.currency,
      icon: Icons.arrow_upward,
      color: Colors.red,
    );

    if (isWide) {
      return Row(
        children: [
          Expanded(child: income),
          const SizedBox(width: 16),
          Expanded(child: outcome),
        ],
      );
    }
    return Column(children: [income, const SizedBox(height: 12), outcome]);
  }

  Widget _buildCharts(HomePageData data, bool isWide) {
    final pie = _sectionCard(
      'Disposizione del patrimonio',
      PatrimonyPieChart(distribution: data.patrimonyDistribution),
    );
    final trend = _sectionCard(
      'Andamento entrate / uscite',
      MonthlyTrendChart(data: data.monthlyTrend),
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: pie),
          const SizedBox(width: 16),
          Expanded(child: trend),
        ],
      );
    }
    return Column(children: [pie, const SizedBox(height: 16), trend]);
  }

  /// Accounts overview section: one card per account type (checking,
  /// deposit, cards), each showing the total available balance for that
  /// type. Row layout on wide screens, column on narrow/mobile screens.
  Widget _buildAccountsOverview(HomePageData data, bool isWide) {
    final checkingCard = _accountTypeCard(
      label: 'Conti correnti',
      amount: data.currentAccountsBalance,
      currency: data.currency,
      icon: Icons.account_balance,
      color: Colors.blue,
      onTap: () => _openAccountsOfType(_AccountSection.checking),
    );
    final depositCard = _accountTypeCard(
      label: 'Conti deposito',
      amount: data.savingsAccountsBalance,
      currency: data.currency,
      icon: Icons.savings,
      color: Colors.orange,
      onTap: () => _openAccountsOfType(_AccountSection.deposit),
    );
    final cardsCard = _accountTypeCard(
      label: 'Carte',
      amount: data.cardAccountsBalance,
      currency: data.currency,
      icon: Icons.credit_card,
      color: Colors.purple,
      onTap: () => _openAccountsOfType(_AccountSection.cards),
    );

    final cardsRow = isWide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: checkingCard),
              const SizedBox(width: 16),
              Expanded(child: depositCard),
              const SizedBox(width: 16),
              Expanded(child: cardsCard),
            ],
          )
        : Column(
            children: [
              checkingCard,
              const SizedBox(height: 12),
              depositCard,
              const SizedBox(height: 12),
              cardsCard,
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'I tuoi conti',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        cardsRow,
      ],
    );
  }

  /// Single tappable account-type card. Reuses SummaryCard to stay
  /// consistent with the income/outgoing cards, wrapped in an InkWell so it
  /// can navigate to the dedicated account-type page.
  Widget _accountTypeCard({
    required String label,
    required double amount,
    required String currency,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SummaryCard(
        label: label,
        amount: amount,
        currency: currency,
        icon: icon,
        color: color,
      ),
    );
  }

  /// Navigates to the dedicated page for the tapped account type.
  Future<void> _openAccountsOfType(_AccountSection section) async {
    final session = await CurrentSession.getFromMemory();
    if (session == null) {
      throw StateError('Nessuna sessione attiva.');
    }

    await _initializeDatabase(session);
    if (!mounted) return;
    final database = _database!;

    switch (section) {
      case _AccountSection.checking:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CurrentAccountPage(database: database),
          ),
        );
        break;
      case _AccountSection.deposit:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SavingsAccountPage(database: database),
          ),
        );
        break;
      case _AccountSection.cards:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CardAccountPage(database: database),
          ),
        );
        break;
    }
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
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildRecentOperations(HomePageData data) {
    if (data.recentOperations.isEmpty) {
      return const Text('Nessun movimento recente');
    }

    return Column(
      children: data.recentOperations.map((op) {
        return TransactionOperationOutput(
          reference: op.reference,
          accountName: '',
          amount: op.amount,
          isIncome: op is Income,
          category: op is Income
              ? op.category.name
              : (op as Outgoing).category.name,
          executionDate: op.executionDate,
          accountingDate: op.accountingDate,
        ).build();
      }).toList(),
    );
  }
}
