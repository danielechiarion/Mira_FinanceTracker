import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';

import 'package:mira_finance_tracker/frontend/navbar/AppRoutes.dart';
import 'package:mira_finance_tracker/frontend/templates/AccountTypePage.dart';
import 'package:mira_finance_tracker/frontend/single_elements/EntityListSection.dart';

import 'package:mira_finance_tracker/classes/bank_account/SavingsAccount.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/service/FinancialInstrument.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/service/TimeDeposit.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/service/Bond.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/service/Stock.dart';
import 'package:mira_finance_tracker/classes/transaction/BankTransaction.dart';

import 'package:mira_finance_tracker/frontend/actions/NewTimeDepositPage.dart';
import 'package:mira_finance_tracker/frontend/actions/NewBondPage.dart';
import 'package:mira_finance_tracker/frontend/actions/NewStockPage.dart';
import 'package:mira_finance_tracker/frontend/updates/EditTimeDepositPage.dart';
import 'package:mira_finance_tracker/frontend/updates/EditBondPage.dart';
import 'package:mira_finance_tracker/frontend/updates/EditStockPage.dart';

/// Deposit-accounts page ("Conti deposito"), built on top of the generic
/// AccountTypePage template. Adds the section specific to deposit
/// accounts: the financial products held on it (time deposits, bonds and
/// stocks), backed by the TimeDeposit, Bond and Stock classes.
///
/// Unlike CurrentAccountPage, every product here also supports a
/// "riscossione" (cash-in / redemption) action, but only when it's
/// actually meaningful: cashable, still-ongoing time deposits and stocks
/// with shares still held (bonds don't expose this action for now).
/// Because deletion and cash-in are both irreversible, they're always
/// confirmed through an overlay popup before being executed, to protect
/// against accidental taps or typing mistakes.
class SavingsAccountPage extends StatefulWidget {
  final UserDatabaseWrapper _database; // use database as an attribute

  const SavingsAccountPage({super.key, required this._database});

  @override
  State<SavingsAccountPage> createState() => _SavingsAccountPageState();
}

class _SavingsAccountPageState extends State<SavingsAccountPage> {
  @override
  Widget build(BuildContext context) {
    return AccountTypePage<SavingsAccount>(
      currentRoute: AppRoutes.savingsAccounts,
      title: 'Conti deposito',
      icon: Icons.savings,
      color: Colors.orange,

      loadAccounts: () async => await widget._database.getCompleteSavingsAccounts(),

      // A deposit account only has one meaningful balance, so the
      // secondary ("saldo disponibile") slot is left unset.
      primaryBalanceOf: (account) => account.availableBalance,
      primaryBalanceLabel: 'Saldo',

      loadTransactionsPage: (account, page, pageSize) async {
        return await widget._database.getAccountTransactionSlot(account, pageSize, page * pageSize);
      },

      hasSpecificSection: true,
      specificSectionTitle: 'Prodotti finanziari',
      buildSpecificSection: (context, account) => _buildFinancialProductsSection(account),
      database: widget._database
    );
  }

  Widget _buildFinancialProductsSection(SavingsAccount account) {
    final formatter = NumberFormat.currency(locale: 'it_IT', symbol: '€');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Depositi a tempo', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        EntityListSection<TimeDeposit>(
          searchHint: 'Cerca un deposito a tempo...',
          addLabel: 'Aggiungi',
          icon: Icons.lock_clock,
          color: Colors.indigo,
          loadItems: () async => account.timeDeposits,
          matchesQuery: (deposit, query) => _matchesInstrument(deposit.name, deposit.provider?.name, query),
          titleOf: (deposit) => deposit.name,
          subtitleOf: (deposit) => _instrumentSubtitle(formatter, deposit.currentValue, deposit.status, extra: deposit.isCashable ? 'svincolabile' : null),
          buildAddPage: (context) => NewTimeDepositPage(database: widget._database),
          buildEditPage: (context, deposit) => EditTimeDepositPage(title: 'Modifica deposito a tempo', item: deposit, database: widget._database),
          deleteItem: (deposit) async {
            // Deleting a financial product is irreversible, so it's
            // always confirmed with a popup before proceeding.
            final bool confirmed = await _confirmDestructiveAction(
              title: 'Elimina deposito a tempo',
              message: 'Sei sicuro di voler eliminare "${deposit.name}"? Questa azione è irreversibile.',
              confirmLabel: 'Elimina',
            );
            if (!confirmed) return;

            account.removeService(deposit);
            await widget._database.deleteSavingsAccountTimeDeposit(deposit);
          },
          addItem: (deposit) async {
            setState(() {
              account.addService(deposit);
            });
          },
          updateItem: (deposit) async {
            setState(() {
              account.replaceService(deposit);
            });
          },
        ),
        const SizedBox(height: 8),
        // Cash-in ("riscossione") only makes sense for time deposits that
        // allow early withdrawal and are still ongoing, so they're listed
        // separately with a dedicated confirmation-guarded action.
        _buildRedeemableList<TimeDeposit>(
          title: 'Prodotti riscuotibili',
          items: account.timeDeposits.where((deposit) => deposit.isCashable && deposit.status == FinancialInstrumentStatus.ongoing).toList(),
          labelOf: (deposit) => deposit.name,
          valueOf: (deposit) => deposit.currentValue,
          formatter: formatter,
          onRedeem: (deposit) => _redeemTimeDeposit(account, deposit),
        ),

        const SizedBox(height: 24),
        const Text('Obbligazioni', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        EntityListSection<Bond>(
          searchHint: 'Cerca un\'obbligazione...',
          addLabel: 'Aggiungi',
          icon: Icons.receipt_long,
          color: Colors.teal,
          loadItems: () async => account.bonds,
          matchesQuery: (bond, query) => _matchesInstrument(bond.name, bond.provider?.name, query),
          titleOf: (bond) => bond.name,
          subtitleOf: (bond) => _instrumentSubtitle(formatter, bond.currentValue, bond.status),
          buildAddPage: (context) => NewBondPage(database: widget._database),
          buildEditPage: (context, bond) => EditBondPage(title: 'Modifica obbligazione', item: bond, database: widget._database),
          deleteItem: (bond) async {
            final bool confirmed = await _confirmDestructiveAction(
              title: 'Elimina obbligazione',
              message: 'Sei sicuro di voler eliminare "${bond.name}"? Questa azione è irreversibile.',
              confirmLabel: 'Elimina',
            );
            if (!confirmed) return;

            account.removeService(bond);
            await widget._database.deleteSavingsAccountBond(bond);
          },
          addItem: (bond) async {
            setState(() {
              account.addService(bond);
            });
          },
          updateItem: (bond) async {
            setState(() {
              account.replaceService(bond);
            });
          },
        ),
        // Note: unlike time deposits and stocks, bonds don't expose a
        // "riscossione" action on this page (only add/edit/delete).

        const SizedBox(height: 24),
        const Text('Azioni', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        EntityListSection<Stock>(
          searchHint: 'Cerca un\'azione...',
          addLabel: 'Aggiungi',
          icon: Icons.show_chart,
          color: Colors.deepPurple,
          loadItems: () async => account.stocks,
          matchesQuery: (stock, query) => _matchesInstrument(stock.name, stock.ticker, query),
          titleOf: (stock) => stock.name,
          subtitleOf: (stock) => _stockSubtitle(formatter, stock),
          buildAddPage: (context) => NewStockPage(database: widget._database),
          buildEditPage: (context, stock) => EditStockPage(title: 'Modifica azione', item: stock, database: widget._database),
          deleteItem: (stock) async {
            final bool confirmed = await _confirmDestructiveAction(
              title: 'Elimina azione',
              message: 'Sei sicuro di voler eliminare "${stock.name}"? Questa azione è irreversibile.',
              confirmLabel: 'Elimina',
            );
            if (!confirmed) return;

            account.removeService(stock);
            await widget._database.deleteSavingsAccountStock(stock);
          },
          addItem: (stock) async {
            setState(() {
              account.addService(stock);
            });
          },
          updateItem: (stock) async {
            setState(() {
              account.replaceService(stock);
            });
          },
        ),
        const SizedBox(height: 8),
        // Cash-in ("riscossione") for a stock liquidates the whole position
        // at once (see Stock.end()), so it's offered only while shares are
        // still held and the position is ongoing.
        _buildRedeemableList<Stock>(
          title: 'Prodotti riscuotibili',
          items: account.stocks.where((stock) => stock.totalShares > 0 && stock.status == FinancialInstrumentStatus.ongoing).toList(),
          labelOf: (stock) => stock.name,
          valueOf: (stock) => stock.currentValue,
          formatter: formatter,
          onRedeem: (stock) => _redeemStock(account, stock),
        ),
      ],
    );
  }

  /// Cash in ("riscuoti") a time deposit before its natural maturity.
  /// Confirmed with a popup because the operation is irreversible.
  Future<void> _redeemTimeDeposit(SavingsAccount account, TimeDeposit deposit) async {
    final bool confirmed = await _confirmDestructiveAction(
      title: 'Riscuoti deposito a tempo',
      message: 'Confermi di voler riscuotere anticipatamente "${deposit.name}"? Il deposito verrà chiuso e l\'operazione non potrà essere annullata.',
      confirmLabel: 'Riscuoti',
    );
    if (!confirmed) return;

    // 1. Run the early-withdrawal logic locally to get the resulting transactions
    final List<BankTransaction> transactions = deposit.stop();

    // 2. Update the local UI state (the deposit is now "stopped")
    setState(() {
      account.replaceService(deposit);
      account.addTransactions(transactions);
    });

    // 3. BACKEND DATABASE CALL:
    // Persist the updated status/currentValue of the time deposit and register
    // the resulting transactions (capital plus any early-withdrawal interest)
    await widget._database.updateSavingsAccountTimeDeposit(deposit);
    await widget._database.saveTransactions(account, transactions);
  }

  /// Cash in ("riscuoti") a stock by liquidating the whole position.
  /// Confirmed with a popup because the operation is irreversible.
  Future<void> _redeemStock(SavingsAccount account, Stock stock) async {
    final bool confirmed = await _confirmDestructiveAction(
      title: 'Riscuoti azione',
      message: 'Confermi di voler vendere tutte le azioni di "${stock.name}"? L\'operazione non potrà essere annullata.',
      confirmLabel: 'Riscuoti',
    );
    if (!confirmed) return;

    // 1. Liquidate the whole position to get the resulting transactions
    final List<BankTransaction> transactions = stock.end();

    // 2. Update the local UI state (all shares have now been sold)
    setState(() {
      account.replaceService(stock);
      account.addTransactions(transactions);
    });

    // 3. BACKEND DATABASE CALL:
    // Persist the updated status/shares of the stock and register the
    // resulting transactions (sale, profit/loss, taxes...) against the
    await widget._database.updateSavingsAccountStock(stock);
    await widget._database.saveTransactions(account, transactions);
  }

  /// Generic overlay confirmation popup, used before any destructive or
  /// irreversible operation on a financial product (deletion or cash-in)
  /// to protect against accidental taps or typing mistakes.
  Future<bool> _confirmDestructiveAction({required String title, required String message, required String confirmLabel}) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmLabel, style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    return confirm ?? false;
  }

  /// Compact list of the products of type [T] eligible for cash-in: shown
  /// under the corresponding EntityListSection, only when at least one
  /// item qualifies (see the filters used when calling this method).
  Widget _buildRedeemableList<T>({
    required String title,
    required List<T> items,
    required String Function(T item) labelOf,
    required double Function(T item) valueOf,
    required NumberFormat formatter,
    required void Function(T item) onRedeem,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
        ...items.map((item) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(labelOf(item)),
            subtitle: Text(formatter.format(valueOf(item))),
            trailing: TextButton.icon(
              icon: const Icon(Icons.attach_money, size: 18),
              label: const Text('Riscuoti'),
              onPressed: () => onRedeem(item),
            ),
          );
        }),
      ],
    );
  }

  /// Shared search predicate for TimeDeposit/Bond/Stock: matches on name
  /// and, when available, a secondary field (provider name or ticker).
  bool _matchesInstrument(String name, String? secondaryField, String query) {
    final q = query.toLowerCase();
    return name.toLowerCase().contains(q) || (secondaryField?.toLowerCase().contains(q) ?? false);
  }

  /// Shared subtitle for TimeDeposit/Bond: current value, status and an
  /// optional extra tag (e.g. "svincolabile" for cashable time deposits).
  String _instrumentSubtitle(NumberFormat formatter, double currentValue, FinancialInstrumentStatus status, {String? extra}) {
    final buffer = StringBuffer('${formatter.format(currentValue)} • ${_statusLabel(status)}');
    if (extra != null && extra.isNotEmpty) {
      buffer.write(' • $extra');
    }
    return buffer.toString();
  }

  /// Subtitle for Stock: current value, status and number of shares held.
  String _stockSubtitle(NumberFormat formatter, Stock stock) {
    return '${formatter.format(stock.currentValue)} • ${_statusLabel(stock.status)} • ${stock.totalShares.toStringAsFixed(2)} az.';
  }

  /// Converts the financial instrument status into the label shown in the UI.
  String _statusLabel(FinancialInstrumentStatus status) {
    switch (status) {
      case FinancialInstrumentStatus.ongoing:
        return 'In corso';
      case FinancialInstrumentStatus.stopped:
        return 'Riscosso';
      case FinancialInstrumentStatus.ended:
        return 'Scaduto';
      default:
        return status.name;
    }
  }
}