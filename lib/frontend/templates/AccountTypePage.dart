import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:mira_finance_tracker/frontend/navbar/ResponsiveScaffold.dart';
import 'package:mira_finance_tracker/frontend/single_elements/FlippableBalanceCard.dart';
import 'package:mira_finance_tracker/frontend/single_elements/EntityListSection.dart';
import 'package:mira_finance_tracker/frontend/single_elements/PaginatedTransactionsSection.dart';
import 'package:mira_finance_tracker/frontend/single_elements/PlaceholderFormPage.dart';
import 'package:mira_finance_tracker/frontend/single_elements/TransactionOperationOutput.dart';
import 'package:mira_finance_tracker/classes/bank_account/BankAccount.dart';
import 'package:mira_finance_tracker/classes/periodic_transactions/BankFee.dart';
import 'package:mira_finance_tracker/classes/periodic_transactions/Cashback.dart';
import 'package:mira_finance_tracker/classes/transaction/BankTransaction.dart';
import 'package:mira_finance_tracker/classes/transaction/Income.dart';
import 'package:mira_finance_tracker/classes/transaction/Outcome.dart';

/// Generic template for a "type of account" page (checking accounts,
/// deposit accounts, cards, ...). It shows the app navbar, one section per
/// account of that type owned by the user (labelled with the account
/// name), a flippable balance card, a "movimenti comuni" section for
/// fees/cashback, an optional free-form section for operations specific
/// to that account type, and a paginated list of the account's
/// transactions.
///
/// Concrete pages are built by instantiating this widget with the right
/// callbacks/flags - see CheckingAccountPage.dart for an example.
class AccountTypePage<T extends BankAccount> extends StatefulWidget {
  /// Route of this page, used by ResponsiveScaffold to highlight the right
  /// navbar entry.
  final String currentRoute;

  /// Page/app-bar title (e.g. "Conti correnti").
  final String title;

  final IconData icon;
  final Color color;

  /// Loads the accounts of this type owned by the current user.
  final Future<List<T>> Function() loadAccounts;

  /// "Saldo contabile": always shown, front and center on the card.
  final double Function(T account) primaryBalanceOf;
  final String primaryBalanceLabel;

  /// "Saldo disponibile": only meaningful for some account types (e.g.
  /// deposit accounts, where part of the accounted balance may not be
  /// immediately withdrawable). Leave null to hide it.
  final double Function(T account)? secondaryBalanceOf;
  final String secondaryBalanceLabel;

  /// Free section for operations specific to this account type (e.g.
  /// direct debits and periodic credits for checking accounts). Shown only
  /// when [hasSpecificSection] is true.
  final bool hasSpecificSection;
  final String specificSectionTitle;
  final Widget Function(BuildContext context, T account)? buildSpecificSection;

  /// Loads one page of transactions for [account]; should ideally query
  /// the backend directly for that page instead of loading the whole history and
  /// slicing it in memory.
  final Future<List<BankTransaction>> Function(T account, int page, int pageSize) loadTransactionsPage;

  const AccountTypePage({
    super.key,
    required this.currentRoute,
    required this.title,
    required this.icon,
    required this.color,
    required this.loadAccounts,
    required this.primaryBalanceOf,
    this.primaryBalanceLabel = 'Saldo contabile',
    this.secondaryBalanceOf,
    this.secondaryBalanceLabel = 'Saldo disponibile',
    this.hasSpecificSection = false,
    this.specificSectionTitle = 'Operazioni specifiche',
    this.buildSpecificSection,
    required this.loadTransactionsPage,
  });

  @override
  State<AccountTypePage<T>> createState() => _AccountTypePageState<T>();
}

class _AccountTypePageState<T extends BankAccount> extends State<AccountTypePage<T>> {
  late Future<List<T>> _accountsFuture;

  @override
  void initState() {
    super.initState();
    _accountsFuture = widget.loadAccounts();
  }

  Future<void> _reload() async {
    final future = widget.loadAccounts();
    setState(() => _accountsFuture = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      currentRoute: widget.currentRoute,
      title: widget.title,
      body: FutureBuilder<List<T>>(
        future: _accountsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: Colors.teal));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Errore nel caricamento dei dati: ${snapshot.error}'));
          }

          final accounts = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _reload,
            color: Colors.teal,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: accounts.isEmpty ? _buildEmptyState() : _buildAccountsList(accounts),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Icon(widget.icon, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('Nessun conto di questo tipo', style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountsList(List<T> accounts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < accounts.length; i++) ...[
          _buildAccountSection(accounts[i]),
          if (i != accounts.length - 1) ...[
            const SizedBox(height: 32),
            const Divider(height: 1, color: Color(0xFFE0E0E0)),
            const SizedBox(height: 32),
          ],
        ],
      ],
    );
  }

  /// Builds one full section (label + card + sub-sections) for a single
  /// account, labelled with the account name as requested. Keyed by
  /// account id so each account keeps its own paginated transactions state
  /// across rebuilds/reorders.
  Widget _buildAccountSection(T account) {
    return Column(
      key: ValueKey('account-${account.id}-${account.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(widget.icon, color: widget.color, size: 20),
            const SizedBox(width: 8),
            Text(account.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        _buildBalanceCard(account),
        const SizedBox(height: 16),
        _sectionCard('Movimenti comuni', _buildCommonOperations(account)),
        if (widget.hasSpecificSection && widget.buildSpecificSection != null) ...[
          const SizedBox(height: 16),
          _sectionCard(widget.specificSectionTitle, widget.buildSpecificSection!(context, account)),
        ],
        const SizedBox(height: 16),
        _sectionCard('Movimenti', _buildTransactionsSection(account)),
      ],
    );
  }

  Widget _buildBalanceCard(T account) {
    final formatter = NumberFormat.currency(locale: 'it_IT', symbol: '€');
    return FlippableBalanceCard(
      front: _balanceFront(account, formatter),
      back: _balanceBack(account),
    );
  }

  Widget _balanceFront(T account, NumberFormat formatter) {
    final secondary = widget.secondaryBalanceOf;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(widget.icon, color: widget.color),
            const SizedBox(width: 8),
            Text(widget.primaryBalanceLabel, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            const Spacer(),
            Icon(Icons.flip, size: 16, color: Colors.grey.shade400),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          formatter.format(widget.primaryBalanceOf(account)),
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        if (secondary != null) ...[
          const SizedBox(height: 16),
          Text(widget.secondaryBalanceLabel, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            formatter.format(secondary(account)),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
        ],
      ],
    );
  }

  Widget _balanceBack(T account) {
    final dateFormatter = DateFormat('dd/MM/yyyy');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Dettagli conto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            Icon(Icons.flip, size: 16, color: Colors.grey.shade400),
          ],
        ),
        const SizedBox(height: 12),
        // NOTE: assumes FinancialInstitute exposes a `name` getter.
        _detailRow('Istituto', account.bank.name),
        _detailRow('IBAN', account.IBAN ?? '-'),
        // NOTE: assumes interest is stored as a fraction (e.g. 0.015 = 1.5%).
        _detailRow('Tasso di interesse', '${(account.interest * 100).toStringAsFixed(2)}%'),
        _detailRow('Data di sottoscrizione', dateFormatter.format(account.subscriptionDate)),
        if (account.endingDate != null) _detailRow('Data di chiusura', dateFormatter.format(account.endingDate!)),
        _detailRow('Stato', account.isActive ? 'Attivo' : 'Archiviato'),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  /// "Movimenti comuni" section: fees and cashback management, embedded via
  /// two EntityListSection instances that reuse BankAccount's own
  /// fee/cashback CRUD methods (addFee/removeFee, addCashback/removeCashback).
  /// TODO: the add/edit pages are still placeholders - building the real
  /// forms needs PeriodicAccountDuration/DurationType's public API (to pick
  /// a cadence), which hasn't been shared yet.
  Widget _buildCommonOperations(T account) {
    final formatter = NumberFormat.currency(locale: 'it_IT', symbol: '€');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Commissioni bancarie', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        EntityListSection<BankFee>(
          searchHint: 'Cerca una commissione...',
          addLabel: 'Aggiungi',
          icon: Icons.request_quote_outlined,
          color: Colors.red,
          loadItems: () async => account.fees,
          matchesQuery: (fee, query) => _matchesBilling(fee.name, fee.description, query),
          titleOf: (fee) => fee.name,
          subtitleOf: (fee) => _billingSubtitle(formatter, fee.amount, fee.description),
          buildAddPage: (context) => const PlaceholderFormPage(title: 'Nuova commissione'),
          buildEditPage: (context, fee) => const PlaceholderFormPage(title: 'Modifica commissione'),
          deleteItem: (fee) async => account.removeFee(fee),
        ),
        const SizedBox(height: 24),
        const Text('Cashback', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        EntityListSection<Cashback>(
          searchHint: 'Cerca un cashback...',
          addLabel: 'Aggiungi',
          icon: Icons.savings_outlined,
          color: Colors.green,
          loadItems: () async => account.cashbacks,
          matchesQuery: (cashback, query) => _matchesBilling(cashback.name, cashback.description, query),
          titleOf: (cashback) => cashback.name,
          subtitleOf: (cashback) => _billingSubtitle(formatter, cashback.amount, cashback.description),
          buildAddPage: (context) => const PlaceholderFormPage(title: 'Nuovo cashback'),
          buildEditPage: (context, cashback) => const PlaceholderFormPage(title: 'Modifica cashback'),
          deleteItem: (cashback) async => account.removeCashback(cashback),
        ),
      ],
    );
  }

  /// Shared search predicate for the periodic-billing types (BankFee,
  /// Cashback): matches on name and, if present, description.
  bool _matchesBilling(String name, String? description, String query) {
    final q = query.toLowerCase();
    return name.toLowerCase().contains(q) || (description?.toLowerCase().contains(q) ?? false);
  }

  /// Shared subtitle for the periodic-billing types: formatted amount,
  /// plus the description when there is one.
  String _billingSubtitle(NumberFormat formatter, double amount, String? description) {
    final base = formatter.format(amount);
    if (description == null || description.isEmpty) return base;
    return '$base • $description';
  }

  /// Paginated transactions list (10 at a time by default), loaded
  /// gradually through [AccountTypePage.loadTransactionsPage] instead of
  /// materializing the whole history at once.
  Widget _buildTransactionsSection(T account) {
    return PaginatedTransactionsSection<BankTransaction>(
      loadPage: (page, pageSize) => widget.loadTransactionsPage(account, page, pageSize),
      itemBuilder: (transaction) => TransactionOperationOutput(
        reference: transaction.reference,
        accountName: account.name,
        amount: transaction.amount,
        isIncome: transaction is Income,
        category: transaction is Income ? transaction.category.name : (transaction as Outcome).category.name,
        executionDate: transaction.executionDate,
        accountingDate: transaction.accountingDate,
      ).build(),
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