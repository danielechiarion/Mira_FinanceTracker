import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'package:mira_finance_tracker/backend/service/CurrentSession.dart';
import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';
import 'package:mira_finance_tracker/classes/bank_account/BankAccount.dart';
import 'package:mira_finance_tracker/classes/transaction/BankTransaction.dart';
import 'package:mira_finance_tracker/classes/transaction/Income.dart';
import 'package:mira_finance_tracker/classes/transaction/Outcome.dart';
import 'package:mira_finance_tracker/frontend/navbar/AppRoutes.dart';
import 'package:mira_finance_tracker/frontend/navbar/ResponsiveScaffold.dart';
import 'package:mira_finance_tracker/frontend/single_elements/SummaryCard.dart';
import 'package:mira_finance_tracker/frontend/single_elements/TransactionOperationOutput.dart';

enum _ComparisonMode { sameDuration, lastYear }

class CustomCheckPage extends StatefulWidget {
  const CustomCheckPage({super.key});

  @override
  State<CustomCheckPage> createState() => _CustomCheckPageState();
}

class _CustomCheckPageState extends State<CustomCheckPage> {
  final _formatter = NumberFormat.currency(locale: 'it_IT', symbol: '€');
  final _searchController = TextEditingController();
  late DateTime _startDate;
  late DateTime _endDate;
  _ComparisonMode _comparisonMode = _ComparisonMode.sameDuration;
  final Set<String> _selectedAccounts = {};
  final Set<String> _selectedServices = {};
  int _page = 0;
  late final Future<List<TransactionOperatioOutput>> _operationsFuture;
  List<TransactionOperatioOutput> _operations = [];

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(DateTime.now());
    _endDate = today;
    _startDate = today.subtract(const Duration(days: 30));
    _operationsFuture = _loadOperations();
    _searchController.addListener(_resetPage);
  }

  Future<List<TransactionOperatioOutput>> _loadOperations() async {
    final session = await CurrentSession.getFromMemory();
    if (session == null) {
      throw StateError('Nessuna sessione attiva.');
    }

    final database = UserDatabaseWrapper(session.user);
    await database.init();
    try {
      final accounts = await database.getBankAccounts();
      final outputs = <TransactionOperatioOutput>[];
      for (final account in accounts) {
        final transactions = await database.getTransactionsOfAccount(account);
        outputs.addAll(
          transactions.map((transaction) => _toOutput(account, transaction)),
        );
      }
      _operations = outputs;
      return outputs;
    } finally {
      await database.closeDatabase();
    }
  }

  TransactionOperatioOutput _toOutput(
    BankAccount account,
    BankTransaction transaction,
  ) {
    final isIncome = transaction is Income;
    final category = isIncome
        ? transaction.category.name
        : (transaction as Outcome).category.name;
    return TransactionOperatioOutput(
      reference: transaction.reference,
      accountName: account.name,
      counterParty: transaction.counterParty?.name,
      amount: transaction.amount,
      isIncome: isIncome,
      category: category,
      executionDate: transaction.executionDate,
      accountingDate: transaction.accountingDate,
    );
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_resetPage)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width > 850;

    return ResponsiveScaffold(
      currentRoute: AppRoutes.check,
      title: 'Verifica conti',
      body: FutureBuilder<List<TransactionOperatioOutput>>(
        future: _operationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.teal),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Errore nel caricamento dei movimenti: ${snapshot.error}',
              ),
            );
          }
          final operations = _filteredOperations;
          final income = _sum(operations, true);
          final outcome = _sum(operations, false);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIntro(),
                    const SizedBox(height: 20),
                    _buildFilters(isWide),
                    const SizedBox(height: 20),
                    _buildPeriodSummary(income, outcome, isWide),
                    const SizedBox(height: 20),
                    _buildCharts(operations, isWide),
                    const SizedBox(height: 20),
                    _buildOperationsCard(operations),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIntro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Analisi personalizzata',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Confronta movimenti, entrate e uscite tra due periodi.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        Text(
          'Periodo di riferimento: ${_formatPeriod(_startDate, _endDate)}',
          style: const TextStyle(
            color: Colors.teal,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildFilters(bool isWide) {
    final dateFields = Row(
      children: [
        Expanded(child: _dateField('Da', _startDate, true)),
        const SizedBox(width: 12),
        Expanded(child: _dateField('A', _endDate, false)),
      ],
    );
    final accountChips = _buildChoiceChips(
      'Conti',
      _accountNames,
      _effectiveSelectedAccounts,
      Icons.account_balance_outlined,
      true,
    );
    final serviceChips = _serviceNames.isNotEmpty
        ? _buildChoiceChips(
            'Servizi finanziari',
            _serviceNames,
            _effectiveSelectedServices,
            Icons.auto_graph_outlined,
            false,
          )
        : const SizedBox.shrink();

    return _panel(
      title: 'Cosa vuoi cercare?',
      icon: Icons.tune_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isWide)
            Row(
              children: [
                Expanded(child: dateFields),
                const SizedBox(width: 20),
                Expanded(child: _buildSearchField()),
              ],
            )
          else ...[
            dateFields,
            const SizedBox(height: 14),
            _buildSearchField(),
          ],
          const SizedBox(height: 18),
          accountChips,
          if (_serviceNames.isNotEmpty) ...[
            const SizedBox(height: 14),
            serviceChips,
          ],
          const SizedBox(height: 18),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              Text(
                'Confronta con',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              ChoiceChip(
                label: const Text('Periodo attuale'),
                selected: _comparisonMode == _ComparisonMode.sameDuration,
                onSelected: (_) => setState(
                  () => _comparisonMode = _ComparisonMode.sameDuration,
                ),
              ),
              ChoiceChip(
                label: const Text('Stesso periodo dell’anno scorso'),
                selected: _comparisonMode == _ComparisonMode.lastYear,
                onSelected: (_) =>
                    setState(() => _comparisonMode = _ComparisonMode.lastYear),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateField(String label, DateTime value, bool isStart) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _pickDate(isStart),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(DateFormat('dd/MM/yyyy').format(value)),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: const InputDecoration(
        labelText: 'Nome del movimento',
        hintText: 'Cerca per somiglianza...',
        prefixIcon: Icon(Icons.search),
        suffixIcon: Icon(Icons.manage_search_outlined),
      ),
    );
  }

  Widget _buildChoiceChips(
    String label,
    List<String> choices,
    Set<String> selected,
    IconData icon,
    bool isAccount,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.teal),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: choices.map((choice) {
            return FilterChip(
              label: Text(choice),
              selected: selected.contains(choice),
              onSelected: (checked) => setState(() {
                final target = isAccount
                    ? _selectedAccounts
                    : _selectedServices;
                checked ? target.add(choice) : target.remove(choice);
                _page = 0;
              }),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPeriodSummary(double income, double outcome, bool isWide) {
    final cards = [
      SummaryCard(
        label: 'Entrate nel periodo',
        amount: income,
        icon: Icons.arrow_downward,
        color: Colors.green,
      ),
      SummaryCard(
        label: 'Uscite nel periodo',
        amount: outcome,
        icon: Icons.arrow_upward,
        color: Colors.red,
      ),
      SummaryCard(
        label: 'Saldo del periodo',
        amount: income - outcome,
        icon: Icons.account_balance_wallet_outlined,
        color: Colors.teal,
      ),
    ];
    return isWide
        ? Row(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                Expanded(child: cards[i]),
                if (i < cards.length - 1) const SizedBox(width: 12),
              ],
            ],
          )
        : Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                cards[i],
                if (i < cards.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
  }

  Widget _buildCharts(List<TransactionOperatioOutput> operations, bool isWide) {
    final trend = _buildTrendCard(operations);
    final distribution = _buildDistributionCard(operations);
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: trend),
          const SizedBox(width: 16),
          Expanded(child: distribution),
        ],
      );
    }
    return Column(children: [trend, const SizedBox(height: 16), distribution]);
  }

  Widget _buildTrendCard(List<TransactionOperatioOutput> operations) {
    final comparison = _comparisonOperations;
    final selectedIncome = _sum(operations, true);
    final selectedOutcome = _sum(operations, false);
    final comparisonIncome = _sum(comparison, true);
    final comparisonOutcome = _sum(comparison, false);
    final maxValue = [
      selectedIncome,
      selectedOutcome,
      comparisonIncome,
      comparisonOutcome,
    ].reduce((a, b) => a > b ? a : b);

    return _panel(
      title: 'Andamento del periodo',
      icon: Icons.show_chart_rounded,
      child: Column(
        children: [
          SizedBox(
            height: 230,
            child: BarChart(
              BarChartData(
                maxY: maxValue == 0 ? 100 : maxValue * 1.3,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(show: false),
                barGroups: [
                  _barGroup(0, selectedIncome, comparisonIncome),
                  _barGroup(1, selectedOutcome, comparisonOutcome),
                ],
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(Colors.teal, 'Periodo selezionato'),
              const SizedBox(width: 18),
              _legendDot(
                Colors.blueGrey.shade300,
                _comparisonMode == _ComparisonMode.sameDuration
                    ? 'Periodo attuale'
                    : 'Anno scorso',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _chartLabel(
                'Entrate',
                selectedIncome,
                comparisonIncome,
                Colors.green,
              ),
              _chartLabel(
                'Uscite',
                selectedOutcome,
                comparisonOutcome,
                Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionCard(List<TransactionOperatioOutput> operations) {
    final totals = <String, double>{};
    for (final operation in operations) {
      totals.update(
        operation.accountName,
        (value) => value + operation.amount,
        ifAbsent: () => operation.amount,
      );
    }
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (sum, entry) => sum + entry.value);
    return _panel(
      title: 'Distribuzione per conto',
      icon: Icons.pie_chart_outline_rounded,
      child: entries.isEmpty
          ? Text(
              'Nessun movimento da rappresentare.',
              style: TextStyle(color: Colors.grey.shade600),
            )
          : Column(
              children: [
                SizedBox(
                  height: 210,
                  child: PieChart(
                    PieChartData(
                      centerSpaceRadius: 42,
                      sectionsSpace: 2,
                      sections: [
                        for (var index = 0; index < entries.length; index++)
                          PieChartSectionData(
                            value: entries[index].value,
                            color: _distributionColor(index),
                            radius: 58,
                            title: total == 0
                                ? '0%'
                                : '${(entries[index].value / total * 100).toStringAsFixed(0)}%',
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...entries.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _distributionColor(entry.key),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${entry.key + 1}. ${entry.value.key}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatter.format(entry.value.value),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Color _distributionColor(int index) =>
      Colors.primaries[index % Colors.primaries.length];

  BarChartGroupData _barGroup(int x, double selected, double comparison) {
    return BarChartGroupData(
      x: x,
      barsSpace: 8,
      barRods: [
        BarChartRodData(
          toY: selected,
          color: Colors.teal,
          width: 26,
          borderRadius: BorderRadius.circular(5),
        ),
        BarChartRodData(
          toY: comparison,
          color: Colors.blueGrey.shade300,
          width: 26,
          borderRadius: BorderRadius.circular(5),
        ),
      ],
    );
  }

  Widget _chartLabel(
    String label,
    double selected,
    double comparison,
    Color color,
  ) {
    final delta = comparison == 0 && selected == 0
        ? 0
        : comparison == 0
        ? 100
        : ((selected - comparison) / comparison) * 100;
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          _formatter.format(selected),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
          '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}% vs confronto',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildOperationsCard(List<TransactionOperatioOutput> operations) {
    const pageSize = 5;
    final pageCount = operations.isEmpty
        ? 1
        : (operations.length / pageSize).ceil();
    final safePage = _page.clamp(0, pageCount - 1);
    final pageItems = operations
        .skip(safePage * pageSize)
        .take(pageSize)
        .toList();

    return _panel(
      title: 'Movimenti trovati (${operations.length})',
      icon: Icons.receipt_long_outlined,
      child: Column(
        children: [
          if (pageItems.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Nessun movimento corrisponde ai filtri.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            )
          else
            ...pageItems.map(_operationTile),
          if (pageCount > 1) ...[
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Pagina precedente',
                  onPressed: safePage > 0
                      ? () => setState(() => _page--)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('Pagina ${safePage + 1} di $pageCount'),
                IconButton(
                  tooltip: 'Pagina successiva',
                  onPressed: safePage < pageCount - 1
                      ? () => setState(() => _page++)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _operationTile(TransactionOperatioOutput operation) {
    final color = operation.isIncome ? Colors.green : Colors.red;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(
          operation.isIncome ? Icons.arrow_downward : Icons.arrow_upward,
          color: color,
          size: 18,
        ),
      ),
      title: Text(
        operation.reference,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${operation.accountName} • ${operation.category}\n'
        'Controparte: ${operation.counterParty ?? '-'}\n'
        'Esecuzione: ${DateFormat('dd/MM/yyyy').format(operation.executionDate)} • '
        'Contabile: ${DateFormat('dd/MM/yyyy').format(operation.accountingDate)}',
      ),
      isThreeLine: true,
      trailing: Text(
        '${operation.isIncome ? '+' : '-'}${_formatter.format(operation.amount)}',
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _panel({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
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
          Row(
            children: [
              Icon(icon, color: Colors.teal, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked.isAfter(_endDate) ? _endDate : picked;
      } else {
        _endDate = picked.isBefore(_startDate) ? _startDate : picked;
      }
      _page = 0;
    });
  }

  void _resetPage() {
    if (mounted) setState(() => _page = 0);
  }

  List<TransactionOperatioOutput> get _filteredOperations {
    final query = _searchController.text.trim().toLowerCase();
    return _operations.where((operation) {
      final inDateRange =
          !operation.executionDate.isBefore(_startDate) &&
          !operation.executionDate.isAfter(_endOfDay(_endDate));
      final accountMatches = _effectiveSelectedAccounts.contains(
        operation.accountName,
      );
      final serviceMatches =
          operation.financialService == null ||
          _effectiveSelectedServices.contains(operation.financialService);
      final nameMatches =
          query.isEmpty ||
          operation.reference.toLowerCase().contains(query) ||
          (operation.counterParty?.toLowerCase().contains(query) ?? false);
      return inDateRange && accountMatches && serviceMatches && nameMatches;
    }).toList()..sort((a, b) => b.executionDate.compareTo(a.executionDate));
  }

  List<TransactionOperatioOutput> get _comparisonOperations {
    final duration = _endDate.difference(_startDate).inDays + 1;
    final comparisonEnd = _comparisonMode == _ComparisonMode.sameDuration
        ? _endOfDay(DateTime.now())
        : _endOfDay(_endDate.subtract(const Duration(days: 365)));
    final comparisonStart = comparisonEnd.subtract(
      Duration(days: duration - 1),
    );
    final query = _searchController.text.trim().toLowerCase();
    return _operations.where((operation) {
      final inDateRange =
          !operation.executionDate.isBefore(comparisonStart) &&
          !operation.executionDate.isAfter(comparisonEnd);
      final accountMatches = _effectiveSelectedAccounts.contains(
        operation.accountName,
      );
      final serviceMatches =
          operation.financialService == null ||
          _effectiveSelectedServices.contains(operation.financialService);
      final nameMatches =
          query.isEmpty ||
          operation.reference.toLowerCase().contains(query) ||
          (operation.counterParty?.toLowerCase().contains(query) ?? false);
      return inDateRange && accountMatches && serviceMatches && nameMatches;
    }).toList();
  }

  double _sum(List<TransactionOperatioOutput> operations, bool income) =>
      operations
          .where((operation) => operation.isIncome == income)
          .fold(0, (total, operation) => total + operation.amount);

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  DateTime _endOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day, 23, 59, 59, 999);

  String _formatPeriod(DateTime start, DateTime end) {
    final formatter = DateFormat('dd/MM/yyyy');
    return '${formatter.format(start)} - ${formatter.format(end)}';
  }

  List<String> get _accountNames =>
      _operations.map((operation) => operation.accountName).toSet().toList();

  List<String> get _serviceNames => _operations
      .where((operation) => operation.financialService != null)
      .map((operation) => operation.financialService!)
      .toSet()
      .toList();

  Set<String> get _effectiveSelectedAccounts =>
      _selectedAccounts.isEmpty ? _accountNames.toSet() : _selectedAccounts;

  Set<String> get _effectiveSelectedServices =>
      _selectedServices.isEmpty ? _serviceNames.toSet() : _selectedServices;
}
