import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';

import 'package:mira_finance_tracker/frontend/navbar/AppRoutes.dart';
import 'package:mira_finance_tracker/frontend/templates/AccountTypePage.dart';
import 'package:mira_finance_tracker/frontend/single_elements/EntityListSection.dart';
import 'package:mira_finance_tracker/frontend/single_elements/Toast.dart';

import 'package:mira_finance_tracker/classes/bank_account/SavingsAccount.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/service/FinancialInstrument.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/service/TimeDeposit.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/service/Bond.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/model/BondModel.dart'; // for BondType, used to spot variable-rate bonds
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
/// Unlike CurrentAccountPage, this account type shows both the
/// "saldo contabile" and "saldo disponibile" on the balance card, and
/// every product supports a "riscossione" (cash-in / redemption) action
/// where it's actually meaningful: cashable, still-ongoing time deposits
/// (bonds don't expose this action for now). Stocks instead get their own
/// dedicated buy/sell/dividend operations (see [_buildStockOperationsList]),
/// since a stock position changes gradually rather than being redeemed
/// all at once. Because deletion and cash-in are both irreversible,
/// they're always confirmed through an overlay popup before being
/// executed, to protect against accidental taps or typing mistakes.
class SavingsAccountPage extends StatefulWidget {
  final UserDatabaseWrapper _database; // use database as an attribute

  const SavingsAccountPage({super.key, required this._database});

  @override
  State<SavingsAccountPage> createState() => _SavingsAccountPageState();
}

class _SavingsAccountPageState extends State<SavingsAccountPage> {
  int _pageRefreshToken = 0;

  void _refreshAccountPage() {
    if (!mounted) return;
    setState(() {
      _pageRefreshToken++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AccountTypePage<SavingsAccount>(
      key: ValueKey(_pageRefreshToken),
      currentRoute: AppRoutes.savingsAccounts,
      title: 'Conti deposito',
      icon: Icons.savings,
      color: Colors.orange,

      loadAccounts: () async => await widget._database.getCompleteSavingsAccounts(),

      // Unlike CurrentAccountPage, a deposit account shows both balances:
      // the "contabile" one (all registered movements) and the
      // "disponibile" one (net of anything not yet settled).
      primaryBalanceOf: (account) => account.availableBalance,
      primaryBalanceLabel: 'Saldo disponibile',
      secondaryBalanceOf: (account) => account.ledgerBalance,
      secondaryBalanceLabel: 'Saldo contabile',

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
          subtitleOf: (deposit) => _instrumentSubtitle(
            formatter,
            deposit.currentValue,
            deposit.status,
            extra: deposit.isCashable && deposit.status == FinancialInstrumentStatus.ongoing ? 'svincolabile' : null,
          ),
          buildAddPage: (context) => NewTimeDepositPage(database: widget._database, functionName: "Object-return",),
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
            _refreshAccountPage();
          },
          addItem: (deposit) async {
            List<BankTransaction> transactions = [];
            setState(() {
              transactions = account.addService(deposit);
            });
            await widget._database.saveTransactions(account, transactions);
            await widget._database.updateBankAccountBalance(account);
            _refreshAccountPage();
          },
          updateItem: (deposit) async {
            setState(() {
              account.replaceService(deposit);
            });
            _refreshAccountPage();
          },
        ),
        const SizedBox(height: 8),
        // Cash-in ("riscossione") only makes sense for time deposits that
        // allow early withdrawal and are still ongoing, so they're listed
        // separately with a dedicated confirmation-guarded action.
        _buildRedeemableList<TimeDeposit>(
          title: 'Prodotti riscuotibili',
          items: account.timeDeposits.where((deposit) => deposit.isCashable && deposit.isActive && deposit.status == FinancialInstrumentStatus.ongoing).toList(),
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
          buildAddPage: (context) => NewBondPage(database: widget._database, functionName: "Object-return"),
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
            _refreshAccountPage();
          },
          addItem: (bond) async {
            List<BankTransaction> transactions = [];
            setState(() {
              transactions = account.addService(bond);
            });
            await widget._database.saveTransactions(account, transactions);
            await widget._database.updateBankAccountBalance(account);
            _refreshAccountPage();
          },
          updateItem: (bond) async {
            setState(() {
              account.replaceService(bond);
            });
            _refreshAccountPage();
          },
        ),
        // Note: unlike time deposits and stocks, bonds don't expose a
        // "riscossione" action on this page (only add/edit/delete).
        const SizedBox(height: 8),
        // Variable-rate bonds need their coupon rate refreshed at every
        // due date (see Bond.currentVariableRate), so ongoing ones with
        // BondType.variable get a quick action for that, similar in
        // spirit to the redeemable list above for time deposits.
        _buildVariableRateBondsList(account),

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
          buildAddPage: (context) => NewStockPage(database: widget._database, functionName: "Object-return"),
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
            _refreshAccountPage();
          },
          addItem: (stock) async {
            List<BankTransaction> transactions = [];
            setState(() {
              transactions = account.addService(stock);
            });
            await widget._database.saveTransactions(account, transactions);
            await widget._database.updateBankAccountBalance(account);
            _refreshAccountPage();
          },
          updateItem: (stock) async {
            setState(() {
              account.replaceService(stock);
            });
            _refreshAccountPage();
          },
        ),
        const SizedBox(height: 8),
        // Buy/sell/dividend operations for each ongoing stock: kept
        // separate from the EntityListSection above because these aren't
        // just edits to the entity, but proper transactions that also
        // produce BankTransaction records to register on the account.
        _buildStockOperationsList(account),
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
    await widget._database.updateBankAccountBalance(account);
    _refreshAccountPage();
  }

  /// Update the current coupon rate of a variable-rate [bond], through a
  /// small pop-up: needed at every due date since a variable-rate bond
  /// has no fixed coupon schedule (see [Bond.currentVariableRate] and the
  /// setter used below). Unlike cash-in or deletion, this isn't a
  /// destructive/irreversible action, so it doesn't go through
  /// [_confirmDestructiveAction], just its own small form dialog.
  Future<void> _updateBondVariableRate(SavingsAccount account, Bond bond) async {
    final formKey = GlobalKey<FormState>();
    final rateController = TextEditingController(text: bond.currentVariableRate?.toString() ?? '');

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Aggiorna tasso di "${bond.name}"', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: rateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+[.,]?\d{0,2}'))],
            decoration: const InputDecoration(
              labelText: 'Nuovo tasso di interesse annuo',
              suffixIcon: Icon(Icons.percent, color: Colors.teal),
            ),
            validator: _validateRate,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ANNULLA', style: TextStyle(color: Colors.teal)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('AGGIORNA'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final double newRate = double.parse(rateController.text.trim().replaceAll(',', '.'));

    try {
      // 1. Run the update locally on the bond instance
      bond.addVariableInterest(newRate);
    } catch (e) {
      if (context.mounted) {
        AppToast.show(context, "$e", ToastType.error);
      }
      return;
    }

    // 2. Update the local UI state with the new rate
    setState(() {
      account.replaceService(bond);
    });

    // 3. BACKEND DATABASE CALL:
    // Persist the updated variable rate on the bond record
    await widget._database.updateSavingsAccountBondComplete(bond);
    _refreshAccountPage();
  }

  /// Sell some (or all) of the shares held for [stock], at the average
  /// sale price entered by the user. Unlike the old "Riscuoti" action
  /// (which used to default to the average purchase price, so the gain
  /// was always zero), this lets [Stock.sellShares] compute the actual
  /// gain or loss realized on the sale.
  Future<void> _sellStock(SavingsAccount account, Stock stock) async {
    final input = await _showShareOperationDialog(
      title: 'Vendi azioni di "${stock.name}"',
      confirmLabel: 'VENDI',
      confirmColor: Colors.red,
      quantityLabel: 'Numero di azioni da vendere',
      priceLabel: 'Prezzo medio di vendita',
      maxQuantity: stock.totalShares,
    );
    if (input == null) return;

    List<BankTransaction> transactions;
    try {
      // 1. Run the sale locally to get the resulting transactions
      // (proceeds, gain/loss and, if applicable, taxes)
      transactions = stock.sellShares(input.quantity, input.pricePerShare);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
      return;
    }

    // 2. Update the local UI state (fewer shares, new average price)
    setState(() {
      account.replaceService(stock);
      account.addTransactions(transactions);
    });

    // 3. BACKEND DATABASE CALL:
    // Persist the updated stock (new share count/average price) and register
    // the resulting transactions (sale, gain/loss, taxes...) against the
    // account
    await widget._database.updateSavingsAccountStock(stock);
    await widget._database.saveTransactions(account, transactions);
    await widget._database.updateBankAccountBalance(account);
    _refreshAccountPage();
  }

  /// Buy more shares of [stock], at the average purchase price entered
  /// by the user; updates the stock's average purchase price accordingly
  /// (see [Stock.buyShares]).
  Future<void> _buyStock(SavingsAccount account, Stock stock) async {
    final input = await _showShareOperationDialog(
      title: 'Acquista azioni di "${stock.name}"',
      confirmLabel: 'ACQUISTA',
      confirmColor: Colors.indigo,
      quantityLabel: 'Numero di azioni da acquistare',
      priceLabel: 'Prezzo medio di acquisto',
    );
    if (input == null) return;

    List<BankTransaction> transactions;
    try {
      // 1. Run the purchase locally to get the resulting transaction (cost)
      transactions = stock.buyShares(input.quantity, input.pricePerShare, accountBalance: account.availableBalance);
    } catch (e) {
      AppToast.show(context, "$e", ToastType.error);
      return;
    }

    // 2. Update the local UI state (more shares, new average price)
    setState(() {
      account.replaceService(stock);
      account.addTransactions(transactions);
    });

    // 3. BACKEND DATABASE CALL:
    // Persist the updated stock (new share count/average price) and register
    // the resulting transaction (purchase cost) against the account
    await widget._database.updateSavingsAccountStock(stock);
    await widget._database.saveTransactions(account, transactions);
    await widget._database.updateBankAccountBalance(account);
    _refreshAccountPage();
  }

  /// Register a dividend payout for [stock].
  Future<void> _addDividend(SavingsAccount account, Stock stock) async {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Aggiungi dividendo per "${stock.name}"', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+[.,]?\d{0,2}'))],
            decoration: const InputDecoration(
              labelText: 'Importo netto',
              prefixIcon: Icon(Icons.euro, color: Colors.teal),
            ),
            validator: _validateAmount,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ANNULLA', style: TextStyle(color: Colors.teal)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('AGGIUNGI'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final double netAmount = double.parse(amountController.text.trim().replaceAll(',', '.'));

    List<BankTransaction> transactions;
    try {
      // 1. Run the dividend registration locally to get the resulting transaction
      transactions = stock.addDividend(netAmount);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
      return;
    }

    // 2. Update the local UI state (new total dividends)
    setState(() {
      account.replaceService(stock);
      account.addTransactions(transactions);
    });

    // 3. BACKEND DATABASE CALL:
    // Persist the updated stock (new total dividends) and register the
    // resulting dividend transaction against the account
    await widget._database.updateSavingsAccountStock(stock);
    await widget._database.saveTransactions(account, transactions);
    await widget._database.updateBankAccountBalance(account);
    _refreshAccountPage();
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

  /// Shared numeric-input dialog for buying/selling shares: both need a
  /// share count and a per-share price, only the labels, the optional
  /// maximum quantity (only relevant when selling) and the resulting
  /// action differ.
  Future<_ShareOperationInput?> _showShareOperationDialog({
    required String title,
    required String confirmLabel,
    required Color confirmColor,
    required String quantityLabel,
    required String priceLabel,
    double? maxQuantity,
  }) async {
    final formKey = GlobalKey<FormState>();
    final quantityController = TextEditingController();
    final priceController = TextEditingController();

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: quantityController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+[.,]?\d{0,4}'))],
                decoration: InputDecoration(
                  labelText: quantityLabel,
                  helperText: maxQuantity != null ? 'Massimo disponibile: ${maxQuantity.toStringAsFixed(4)}' : null,
                ),
                validator: (value) => _validateQuantity(value, max: maxQuantity),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+[.,]?\d{0,2}'))],
                decoration: InputDecoration(
                  labelText: priceLabel,
                  prefixIcon: const Icon(Icons.euro, color: Colors.teal),
                ),
                validator: _validateAmount,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ANNULLA', style: TextStyle(color: Colors.teal)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor, foregroundColor: Colors.white),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    if (result != true) return null;

    return _ShareOperationInput(
      quantity: double.parse(quantityController.text.trim().replaceAll(',', '.')),
      pricePerShare: double.parse(priceController.text.trim().replaceAll(',', '.')),
    );
  }

  /// Compact list of quick operations available on each ongoing stock:
  /// buying more shares, selling some (or all) of the shares already
  /// held, and registering a dividend payout. "Vendi" is only shown
  /// while there are shares left to sell.
  Widget _buildStockOperationsList(SavingsAccount account) {
    final ongoingStocks = account.stocks.where((stock) => stock.status == FinancialInstrumentStatus.ongoing).toList();
    if (ongoingStocks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Operazioni sulle azioni', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
        ...ongoingStocks.map((stock) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(stock.name),
            subtitle: Text('${stock.totalShares.toStringAsFixed(2)} azioni possedute'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (stock.totalShares > 0)
                  IconButton(
                    tooltip: 'Vendi',
                    icon: const Icon(Icons.sell_outlined, color: Colors.red, size: 20),
                    onPressed: () => _sellStock(account, stock),
                  ),
                IconButton(
                  tooltip: 'Acquista',
                  icon: const Icon(Icons.add_shopping_cart, color: Colors.indigo, size: 20),
                  onPressed: () => _buyStock(account, stock),
                ),
                IconButton(
                  tooltip: 'Aggiungi dividendo',
                  icon: const Icon(Icons.attach_money, color: Colors.teal, size: 20),
                  onPressed: () => _addDividend(account, stock),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  /// Compact list of ongoing bonds with a variable interest rate, each
  /// with a quick action to refresh the coupon rate currently applied
  /// (see [Bond.currentVariableRate]): needed at every due date, since a
  /// variable-rate bond has no fixed coupon schedule to compute the
  /// interest from.
  Widget _buildVariableRateBondsList(SavingsAccount account) {
    final variableRateBonds = account.bonds
        .where((bond) => bond.interestType == BondType.variable && bond.status == FinancialInstrumentStatus.ongoing)
        .toList();
    if (variableRateBonds.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tassi variabili da aggiornare', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
        ...variableRateBonds.map((bond) {
          final String rateLabel = bond.currentVariableRate != null
              ? 'Tasso attuale: ${bond.currentVariableRate!.toStringAsFixed(2)}%'
              : 'Tasso non ancora impostato';
          return ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(bond.name),
            subtitle: Text(rateLabel),
            trailing: TextButton.icon(
              icon: const Icon(Icons.percent, size: 18),
              label: const Text('Aggiorna tasso'),
              onPressed: () => _updateBondVariableRate(account, bond),
            ),
          );
        }),
      ],
    );
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

  /// Validates an interest rate expressed as a percentage: it must be a
  /// valid number and can't be negative (0% is allowed, unlike
  /// [_validateAmount] for monetary amounts).
  String? _validateRate(String? value) {
    if (value == null || value.isEmpty) return 'Il valore deve essere impostato';
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null || parsed < 0) return 'Inserisci un tasso valido';
    return null;
  }

  /// Validates a monetary amount: it must be a valid, strictly positive number.
  String? _validateAmount(String? value) {
    if (value == null || value.isEmpty) return 'Il valore deve essere impostato';
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) return 'Inserisci un importo valido';
    return null;
  }

  /// Validates a share quantity: it must be a valid, strictly positive
  /// number, and can't exceed [max] when provided (e.g. the shares
  /// actually held, when selling).
  String? _validateQuantity(String? value, {double? max}) {
    if (value == null || value.isEmpty) return 'Il valore deve essere impostato';
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) return 'Inserisci un numero di azioni valido';
    if (max != null && parsed > max) return 'Non puoi superare $max azioni';
    return null;
  }
}

/// Small value holder returned by [_SavingsAccountPageState._showShareOperationDialog].
class _ShareOperationInput {
  final double quantity;
  final double pricePerShare;

  const _ShareOperationInput({required this.quantity, required this.pricePerShare});
}