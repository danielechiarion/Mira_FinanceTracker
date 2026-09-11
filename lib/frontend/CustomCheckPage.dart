import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'package:mira_finance_tracker/frontend/navbar/AppRoutes.dart';
import 'package:mira_finance_tracker/frontend/navbar/ResponsiveScaffold.dart';
import 'package:mira_finance_tracker/frontend/single_elements/SummaryCard.dart';

/// Reusable presentation model for a movement returned by a custom check.
/// It can later be mapped directly from BankTransaction, Income, and Outcome.
class CustomCheckOperation {
  final String name;
  final String accountName;
  final String? financialService;
  final DateTime date;
  final double amount;
  final bool isIncome;
  final String category;
  final String details;

  const CustomCheckOperation({
    required this.name,
    required this.accountName,
    this.financialService,
    required this.date,
    required this.amount,
    required this.isIncome,
    required this.category,
    required this.details,
  });
}

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
  final Set<String> _selectedAccounts = {'Conto principale', 'Risparmio'};
  final Set<String> _selectedServices = {};
  int _page = 0;

  final List<String> _accounts = const [
    'Conto principale',
    'Risparmio',
    'Carta quotidiana',
  ];
  final List<String> _services = const [
    'Obbligazioni',
    'Azioni',
    'Deposito vincolato',
  ];
  late final List<CustomCheckOperation> _demoOperations;

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(DateTime.now());
    _endDate = today;
    _startDate = today.subtract(const Duration(days: 30));
    _demoOperations = _buildDemoOperations(today);
    _searchController.addListener(_resetPage);
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
    final operations = _filteredOperations;
    final isWide = MediaQuery.sizeOf(context).width > 850;
    final income = _sum(operations, true);
    final outcome = _sum(operations, false);

    return ResponsiveScaffold(
      currentRoute: AppRoutes.check,
      title: 'Verifica conti',
      body: SingleChildScrollView(
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
                _buildTrendCard(operations),
                const SizedBox(height: 20),
                _buildOperationsCard(operations),
              ],
            ),
          ),
        ),
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
      _accounts,
      _selectedAccounts,
      Icons.account_balance_outlined,
    );
    final serviceChips = _selectedAccounts.contains('Risparmio')
        ? _buildChoiceChips(
            'Servizi finanziari',
            _services,
            _selectedServices,
            Icons.auto_graph_outlined,
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
          if (_selectedAccounts.contains('Risparmio')) ...[
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
                checked ? selected.add(choice) : selected.remove(choice);
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

  Widget _buildTrendCard(List<CustomCheckOperation> operations) {
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
    final delta = comparison == 0
        ? 0
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

  Widget _buildOperationsCard(List<CustomCheckOperation> operations) {
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

  Widget _operationTile(CustomCheckOperation operation) {
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
        operation.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${operation.accountName} • ${operation.category} • ${DateFormat('dd/MM/yyyy').format(operation.date)}\n${operation.details}',
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

  List<CustomCheckOperation> get _filteredOperations {
    final query = _searchController.text.trim().toLowerCase();
    return _demoOperations.where((operation) {
      final inDateRange =
          !operation.date.isBefore(_startDate) &&
          !operation.date.isAfter(_endDate);
      final accountMatches = _selectedAccounts.contains(operation.accountName);
      final serviceMatches =
          operation.financialService == null ||
          _selectedServices.isEmpty ||
          _selectedServices.contains(operation.financialService);
      final nameMatches =
          query.isEmpty ||
          operation.name.toLowerCase().contains(query) ||
          operation.details.toLowerCase().contains(query);
      return inDateRange && accountMatches && serviceMatches && nameMatches;
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  List<CustomCheckOperation> get _comparisonOperations {
    final duration = _endDate.difference(_startDate).inDays + 1;
    final comparisonEnd = _comparisonMode == _ComparisonMode.sameDuration
        ? _dateOnly(DateTime.now())
        : _endDate.subtract(const Duration(days: 365));
    final comparisonStart = comparisonEnd.subtract(
      Duration(days: duration - 1),
    );
    final query = _searchController.text.trim().toLowerCase();
    return _demoOperations.where((operation) {
      final inDateRange =
          !operation.date.isBefore(comparisonStart) &&
          !operation.date.isAfter(comparisonEnd);
      final accountMatches = _selectedAccounts.contains(operation.accountName);
      final serviceMatches =
          operation.financialService == null ||
          _selectedServices.isEmpty ||
          _selectedServices.contains(operation.financialService);
      final nameMatches =
          query.isEmpty ||
          operation.name.toLowerCase().contains(query) ||
          operation.details.toLowerCase().contains(query);
      return inDateRange && accountMatches && serviceMatches && nameMatches;
    }).toList();
  }

  double _sum(List<CustomCheckOperation> operations, bool income) => operations
      .where((operation) => operation.isIncome == income)
      .fold(0, (total, operation) => total + operation.amount);

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  List<CustomCheckOperation> _buildDemoOperations(DateTime today) {
    // Replace this demo source with the backend query once the data contract is available.
    // The query should apply the selected dates, accounts, services, and name similarity server-side.
    return [
      CustomCheckOperation(
        name: 'Stipendio',
        accountName: 'Conto principale',
        date: today.subtract(const Duration(days: 2)),
        amount: 1850,
        isIncome: true,
        category: 'Entrata',
        details: 'Accredito mensile',
      ),
      CustomCheckOperation(
        name: 'Spesa supermercato',
        accountName: 'Carta quotidiana',
        date: today.subtract(const Duration(days: 4)),
        amount: 74.50,
        isIncome: false,
        category: 'Alimentari',
        details: 'Pagamento con carta',
      ),
      CustomCheckOperation(
        name: 'Cedola obbligazionaria',
        accountName: 'Risparmio',
        financialService: 'Obbligazioni',
        date: today.subtract(const Duration(days: 8)),
        amount: 126.80,
        isIncome: true,
        category: 'Investimenti',
        details: 'Cedola trimestrale',
      ),
      CustomCheckOperation(
        name: 'Affitto',
        accountName: 'Conto principale',
        date: today.subtract(const Duration(days: 12)),
        amount: 720,
        isIncome: false,
        category: 'Casa',
        details: 'Addebito automatico',
      ),
      CustomCheckOperation(
        name: 'Interessi deposito',
        accountName: 'Risparmio',
        financialService: 'Deposito vincolato',
        date: today.subtract(const Duration(days: 17)),
        amount: 42.30,
        isIncome: true,
        category: 'Investimenti',
        details: 'Interessi maturati',
      ),
      CustomCheckOperation(
        name: 'Trasporti',
        accountName: 'Conto principale',
        date: today.subtract(const Duration(days: 21)),
        amount: 58.20,
        isIncome: false,
        category: 'Mobilità',
        details: 'Abbonamento mensile',
      ),
      CustomCheckOperation(
        name: 'Rimborso acquisto',
        accountName: 'Carta quotidiana',
        date: today.subtract(const Duration(days: 25)),
        amount: 36,
        isIncome: true,
        category: 'Rimborso',
        details: 'Riaccredito esercente',
      ),
      CustomCheckOperation(
        name: 'Commissione banca',
        accountName: 'Risparmio',
        date: today.subtract(const Duration(days: 29)),
        amount: 3.50,
        isIncome: false,
        category: 'Commissioni',
        details: 'Canone servizio',
      ),
    ];
  }
}
