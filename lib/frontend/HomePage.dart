import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:mira_finance_tracker/frontend/navbar/AppRoutes.dart';
import 'package:mira_finance_tracker/frontend/navbar/ResponsiveScaffold.dart';
import 'package:mira_finance_tracker/frontend/single_elements/SummaryCard.dart';
import 'package:mira_finance_tracker/frontend/single_elements/TransactionOperationOutput.dart';
import 'package:mira_finance_tracker/frontend/charts/MonthlyTrendChart.dart';
import 'package:mira_finance_tracker/frontend/charts/PatrimonyPieChart.dart';
import 'package:mira_finance_tracker/backend/operation/chart/HomePageData.dart';
import 'package:mira_finance_tracker/backend/service/CurrentSession.dart';
import 'package:mira_finance_tracker/classes/transaction/Income.dart';
import 'package:mira_finance_tracker/classes/transaction/Outcome.dart';

/// REVIEW page from the functional analysis: summary of income, expenses,
/// and charts (asset distribution pie chart + monthly trend).
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<HomePageData> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _loadSession();
  }

  Future<HomePageData> _loadSession() async {
    final session = await CurrentSession.getFromMemory();
    if (session == null) {
      throw StateError('Nessuna sessione attiva.');
    }
    final data = HomePageData(session.user);
    await data.init();
    return data;
  }

  Future<void> _reload() async {
    final future = _loadSession();
    setState(() => _summaryFuture = future);
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
            return const Center(child: CircularProgressIndicator(color: Colors.teal));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Errore nel caricamento dei dati: ${snapshot.error}'));
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
                          _sectionCard('Ultimi movimenti', _buildRecentOperations(data)),
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
        Text('Patrimonio totale', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        const SizedBox(height: 4),
        Text(
          formatter.format(data.totalBalance),
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87),
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
    return Column(
      children: [income, const SizedBox(height: 12), outcome],
    );
  }

  Widget _buildCharts(HomePageData data, bool isWide) {
    final pie = _sectionCard('Disposizione del patrimonio', PatrimonyPieChart(distribution: data.patrimonyDistribution));
    final trend = _sectionCard('Andamento entrate / uscite', MonthlyTrendChart(data: data.monthlyTrend));

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
    return Column(
      children: [pie, const SizedBox(height: 16), trend],
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
          category: op is Income ? op.category.name : (op as Outcome).category.name, 
          executionDate: op.executionDate, 
          accountingDate: op.accountingDate
        ).build();
      }).toList(),
    );
  }
}