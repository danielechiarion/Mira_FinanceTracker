import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:mira_finance_tracker/frontend/navbar/ResponsiveScaffold.dart';
import 'package:mira_finance_tracker/frontend/single_elements/FlippableBalanceCard.dart';
import 'package:mira_finance_tracker/frontend/single_elements/EntityListSection.dart';
import 'package:mira_finance_tracker/frontend/single_elements/PaginatedTransactionsSection.dart';
import 'package:mira_finance_tracker/frontend/single_elements/TransactionOperationOutput.dart';
import 'package:mira_finance_tracker/classes/bank_account/BankAccount.dart';
import 'package:mira_finance_tracker/classes/bank_account/SavingsAccount.dart';
import 'package:mira_finance_tracker/classes/periodic_transactions/BankFee.dart';
import 'package:mira_finance_tracker/classes/periodic_transactions/Cashback.dart';
import 'package:mira_finance_tracker/classes/transaction/BankTransaction.dart';
import 'package:mira_finance_tracker/classes/transaction/Income.dart';
import 'package:mira_finance_tracker/classes/transaction/Outcome.dart';

import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';
import 'package:mira_finance_tracker/frontend/actions/NewPeriodicAccountBillingPage.dart';
import 'package:mira_finance_tracker/frontend/updates/EditPeriodicBillingPage.dart';

/// Generic template for a "type of account" page (checking accounts,
/// deposit accounts, cards, ...). Rebuilt to use a Tabbed layout so multiple
/// accounts of the same type are displayed in separated, clickable tabs.
///
/// It shows a flippable balance card, a "movimenti comuni" section for
/// fees/cashback, an optional free-form section for operations specific
/// to that account type, and a paginated list of the account's transactions.
/// It also supports editing and deleting the account.
class AccountTypePage<T extends BankAccount> extends StatefulWidget {
  final String currentRoute;
  final String title;
  final IconData icon;
  final Color color;
  final Future<List<T>> Function() loadAccounts;
  final double Function(T account) primaryBalanceOf;
  final String primaryBalanceLabel;
  final double Function(T account)? secondaryBalanceOf;
  final String secondaryBalanceLabel;
  final bool hasSpecificSection;
  final String specificSectionTitle;
  final Widget Function(BuildContext context, T account)? buildSpecificSection;
  final Future<List<BankTransaction>> Function(T account, int page, int pageSize) loadTransactionsPage;
  final UserDatabaseWrapper database;

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
    required this.database,
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
    setState(() {
      _accountsFuture = future;
    });
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
          if (accounts.isEmpty) {
            return _buildEmptyState();
          }

          // Use DefaultTabController to separate accounts into individual clickable tabs
          return DefaultTabController(
            length: accounts.length,
            child: Column(
              children: [
                Container(
                  color: Colors.white,
                  child: TabBar(
                    isScrollable: true,
                    indicatorColor: widget.color,
                    labelColor: widget.color,
                    unselectedLabelColor: Colors.grey.shade600,
                    tabs: accounts.map((account) => Tab(text: account.name)).toList(),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: accounts.map((account) => _buildTabContent(account)).toList(),
                  ),
                ),
              ],
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

  Widget _buildTabContent(T account) {
    return RefreshIndicator(
      onRefresh: _reload,
      color: Colors.teal,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: _buildAccountSection(account),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountSection(T account) {
    return Column(
      key: ValueKey('account-${account.id}-${account.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Action Header (Name, Toggle Active Status, Edit, Delete)
        Row(
          children: [
            Icon(widget.icon, color: widget.color, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(account.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            // Switch to toggle the active/archived state of the account
            Tooltip(
              message: account.isActive ? 'Disattiva conto' : 'Attiva conto',
              child: Switch(
                value: account.isActive,
                activeColor: widget.color,
                onChanged: (bool value) async {
                  // If deactivating the account, show a confirmation dialog first
                  if (!value) {
                    final bool? confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text('Disattiva conto'),
                          content: const Text(
                            'Attenzione: a conto disattivato non sarà più possibile registrare alcune operazioni su di esso. Confermi di voler procedere?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Annulla'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800),
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Disattiva', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        );
                      },
                    );

                    // If user cancelled the action or dismissed the dialog, abort the switch toggle
                    if (confirm != true) return;
                  }

                  // 1. Update the local UI state
                  setState(() {
                    account.isActive = value;
                  });

                  // 2. BACKEND DATABASE CALL:
                  // Persist the updated status on the database
                  await widget.database.updateAccountInformation(account);
                },
              ),
            ),
            IconButton(
              tooltip: 'Modifica conto',
              icon: Icon(Icons.edit_outlined, color: widget.color),
              onPressed: () => _showEditAccountDialog(account),
            ),
            IconButton(
              tooltip: 'Elimina conto',
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _confirmDeleteAccount(account),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildBalanceCard(account),
        if(account.isActive) ... [
          const SizedBox(height: 16),
          _sectionCard('Movimenti comuni', _buildCommonOperations(account)),
          if (widget.hasSpecificSection && widget.buildSpecificSection != null) ...[
            const SizedBox(height: 16),
            _sectionCard(widget.specificSectionTitle, widget.buildSpecificSection!(context, account)),
          ],
        ],
        const SizedBox(height: 16),
        _sectionCard('Movimenti', _buildTransactionsSection(account)),
      ],
    );
  }

  Future<void> _showEditAccountDialog(T account) async {
    // Note: Adjust the fields logic as necessary depending on your BankAccount class setters
    final ibanController = TextEditingController(text: account.IBAN ?? '');
    final interestController = TextEditingController(text: (account.interest * 100).toStringAsFixed(2));
    final balanceController = TextEditingController(text: widget.primaryBalanceOf(account).toString());
    final double? initialSecondaryBalance = account is SavingsAccount 
        ? (account as SavingsAccount).ledgerBalance
        : widget.secondaryBalanceOf?.call(account);

    final ledgerController = TextEditingController(
      text: initialSecondaryBalance?.toString() ?? '',
    );

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Modifica conto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'I campi "Nome conto" e "Banca" non sono modificabili.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: TextEditingController(text: account.name),
                  readOnly: true, // Prevents editing the account name
                  decoration: const InputDecoration(
                    labelText: 'Nome conto',
                    filled: true,
                    fillColor: Color(0xFFF5F5F5),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: TextEditingController(text: account.bank.name),
                  readOnly: true, // Prevents editing the bank name
                  decoration: const InputDecoration(
                    labelText: 'Banca',
                    filled: true,
                    fillColor: Color(0xFFF5F5F5),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: balanceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: widget.primaryBalanceLabel),
                ),
                /* display ledger balance to change
                only if we're talking about a savings account */
                if(account is SavingsAccount) ... [
                  const SizedBox(height: 12),
                  TextField(
                    controller: ledgerController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: widget.secondaryBalanceLabel),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: ibanController,
                  decoration: const InputDecoration(labelText: 'IBAN'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: interestController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Tasso di interesse (%)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () async {
                setState(() {
                  account.IBAN = ibanController.text.trim();
                  account.interest = (double.tryParse(interestController.text) ?? 0) / 100;
                  account.availableBalance = double.tryParse(balanceController.text) ?? account.availableBalance;
                  if(account is SavingsAccount) (account as SavingsAccount).ledgerBalance = double.tryParse(ledgerController.text) ?? account.ledgerBalance;
                }); // Refresh local UI

                await widget.database.updateAccountInformation(account); // then update information on database
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Salva'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteAccount(T account) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Elimina conto'),
          content: const Text(
            'Sei sicuro di voler cancellare questo account e tutti i servizi correlati? Questa azione è irreversibile.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await widget.database.deleteBankAccount(account);
                
                if (context.mounted) Navigator.pop(context);
                await _reload(); // Reload the whole list to show the updated tabs
              },
              child: const Text('Elimina', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
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
        _detailRow('Istituto', account.bank.name),
        _detailRow('IBAN', account.IBAN ?? '-'),
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
          buildAddPage: (context) => PeriodicBillingFormPage(title: 'Aggiungi commissione', nameLabel: 'Commissione', database: widget.database, classRequested: BankFee),
          buildEditPage: (context, fee) => EditPeriodicBillingPage(title: 'Modifica commissione', item: fee, classRequested: BankFee, database: widget.database),
          deleteItem: (fee) async {
            account.removeFee(fee);
            await widget.database.deleteAccountFee(fee);
          },
          addItem: (fee) async {
            setState(() {
              account.addFee(fee);
            });
          },
          updateItem: (fee) async {
            setState(() {
              account.replaceFee(fee);
            });
          },
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
          buildAddPage: (context) => PeriodicBillingFormPage(title: 'Aggiungi cashback', nameLabel: 'Cashback', database: widget.database, classRequested: Cashback),
          buildEditPage: (context, cashback) => EditPeriodicBillingPage(title: 'Modifica cashback', item: cashback, classRequested: Cashback, database: widget.database),
          deleteItem: (cashback) async {
            account.removeCashback(cashback);
            await widget.database.deleteAccountCashback(cashback);
          },
          addItem: (cashback) async {
            setState(() {
              account.addCashback(cashback);
            });
          },
          updateItem: (cashback) async {
            setState(() {
              account.replaceCashback(cashback);
            });
          },
        ),
      ],
    );
  }

  bool _matchesBilling(String name, String? description, String query) {
    final q = query.toLowerCase();
    return name.toLowerCase().contains(q) || (description?.toLowerCase().contains(q) ?? false);
  }

  String _billingSubtitle(NumberFormat formatter, double amount, String? description) {
    final base = formatter.format(amount);
    if (description == null || description.isEmpty) return base;
    return '$base • $description';
  }

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