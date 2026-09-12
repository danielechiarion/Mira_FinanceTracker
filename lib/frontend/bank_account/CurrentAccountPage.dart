import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';

import 'package:mira_finance_tracker/frontend/navbar/AppRoutes.dart';
import 'package:mira_finance_tracker/frontend/templates/AccountTypePage.dart';
import 'package:mira_finance_tracker/frontend/single_elements/EntityListSection.dart';
import 'package:mira_finance_tracker/frontend/single_elements/PlaceholderFormPage.dart';

import 'package:mira_finance_tracker/classes/bank_account/CurrentAccount.dart';
import 'package:mira_finance_tracker/classes/periodic_transactions/Domiciliation.dart';
import 'package:mira_finance_tracker/classes/periodic_transactions/PeriodicIncome.dart';

import 'package:mira_finance_tracker/frontend/actions/NewPeriodicTransactionPage.dart';

/// Checking-accounts page ("Conti correnti"), built on top of the generic
/// AccountTypePage template. Adds the sections specific to checking
/// accounts: direct debits ("domiciliazioni") and periodic credits
/// ("accrediti periodici"), backed by the Domiciliation and PeriodicIncome
/// classes.
class CurrentAccountPage extends StatelessWidget {
  final UserDatabaseWrapper _database; // use database as an attribute

  const CurrentAccountPage({super.key, required this._database});

  @override
  Widget build(BuildContext context) {
    return AccountTypePage<CurrentAccount>(
      currentRoute: AppRoutes.currentAccounts,
      title: 'Conti correnti',
      icon: Icons.account_balance,
      color: Colors.blue,

      loadAccounts: () async => await _database.getCompleteCurrentAccounts(),

      // A checking account only has one meaningful balance, so the
      // secondary ("saldo disponibile") slot is left unset.
      primaryBalanceOf: (account) => account.availableBalance,
      primaryBalanceLabel: 'Saldo',

      loadTransactionsPage: (account, page, pageSize) async {
        return await _database.getAccountTransactionSlot(account, pageSize, page * pageSize);
      },

      hasSpecificSection: true,
      specificSectionTitle: 'Domiciliazioni e accrediti periodici',
      buildSpecificSection: (context, account) => _buildCheckingSpecificSection(account),
    );
  }

  /// TODO: the add/edit pages are still placeholders - building the real
  /// forms needs PeriodicAccountDuration/DurationType's public API (to
  /// pick a cadence) and a way to pick/create a CounterParty, neither of
  /// which has been shared yet.
  /// TODO: confirm the getter/method names on CheckingAccount
  /// (`domiciliations`/`addDomiciliation`/`removeDomiciliation` and
  /// `periodicIncomes`/`addPeriodicIncome`/`removePeriodicIncome`) - these
  /// are assumed to follow the same pattern as `fees`/`cashbacks` on
  /// BankAccount, since CheckingAccount wasn't shared yet either.
  Widget _buildCheckingSpecificSection(CurrentAccount account) {
    final formatter = NumberFormat.currency(locale: 'it_IT', symbol: '€');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Domiciliazioni', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        EntityListSection<Domiciliation>(
          searchHint: 'Cerca una domiciliazione...',
          addLabel: 'Aggiungi',
          icon: Icons.repeat,
          color: Colors.indigo,
          loadItems: () async => account.domiciliations,
          matchesQuery: (debit, query) => _matchesPeriodicTransaction(debit.name, debit.description, debit.counterParty.name, query),
          titleOf: (debit) => debit.name,
          subtitleOf: (debit) => _periodicTransactionSubtitle(formatter, debit.amount, debit.counterParty.name, debit.description, extraFee: debit.fee),
          buildAddPage: (context) => PeriodicTransactionFormPage(title: 'Aggiungi domiciliazione', nameLabel: 'Domiciliazione', database: _database, classRequested: Domiciliation),
          buildEditPage: (context, debit) => const PlaceholderFormPage(title: 'Modifica domiciliazione'),
          deleteItem: (debit) async => account.removeDomiciliation(debit),
        ),
        const SizedBox(height: 24),
        const Text('Accrediti periodici', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        EntityListSection<PeriodicIncome>(
          searchHint: 'Cerca un accredito...',
          addLabel: 'Aggiungi',
          icon: Icons.event_repeat,
          color: Colors.teal,
          loadItems: () async => account.periodicIncomes,
          matchesQuery: (credit, query) => _matchesPeriodicTransaction(credit.name, credit.description, credit.counterParty.name, query),
          titleOf: (credit) => credit.name,
          subtitleOf: (credit) => _periodicTransactionSubtitle(formatter, credit.amount, credit.counterParty.name, credit.description),
          buildAddPage: (context) => PeriodicTransactionFormPage(title: 'Aggiungi accredito periodico', nameLabel: 'Accredito periodico', database: _database, classRequested: PeriodicIncome),
          buildEditPage: (context, credit) => const PlaceholderFormPage(title: 'Modifica accredito periodico'),
          deleteItem: (credit) async => account.removePeriodicIncome(credit),
        ),
      ],
    );
  }

  /// Shared search predicate for Domiciliation/PeriodicIncome: matches on
  /// name, description and counterparty name.
  bool _matchesPeriodicTransaction(String name, String? description, String counterPartyName, String query) {
    final q = query.toLowerCase();
    return name.toLowerCase().contains(q) ||
        (description?.toLowerCase().contains(q) ?? false) ||
        counterPartyName.toLowerCase().contains(q);
  }

  /// Shared subtitle for Domiciliation/PeriodicIncome: formatted amount,
  /// counterparty name, optional description, and (for domiciliations)
  /// the extra bank fee applied on top, when greater than zero.
  String _periodicTransactionSubtitle(
    NumberFormat formatter,
    double amount,
    String counterPartyName,
    String? description, {
    double extraFee = 0,
  }) {
    final buffer = StringBuffer('${formatter.format(amount)} • $counterPartyName');
    if (description != null && description.isNotEmpty) {
      buffer.write(' • $description');
    }
    if (extraFee > 0) {
      buffer.write(' • commissione ${formatter.format(extraFee)}');
    }
    return buffer.toString();
  }
}