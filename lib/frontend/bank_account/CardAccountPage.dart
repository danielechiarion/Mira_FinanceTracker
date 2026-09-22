import 'package:flutter/material.dart';

import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';

import 'package:mira_finance_tracker/frontend/navbar/AppRoutes.dart';
import 'package:mira_finance_tracker/frontend/templates/AccountTypePage.dart';

import 'package:mira_finance_tracker/classes/bank_account/Card.dart' as card_account;

/// Card account page starting from AccountTypePage template
class CardAccountPage extends StatefulWidget {
  final UserDatabaseWrapper _database; // use database as an attribute

  const CardAccountPage({super.key, required this._database});

  @override
  State<CardAccountPage> createState() => _CardAccountPageState();
}

class _CardAccountPageState extends State<CardAccountPage> {
  @override
  Widget build(BuildContext context) {
    return AccountTypePage<card_account.Card>(
      currentRoute: AppRoutes.currentAccounts,
      title: 'Conti correnti',
      icon: Icons.credit_card,
      color: Colors.purple,

      loadAccounts: () async => await widget._database.getCompleteCardAccounts(),

      // A checking account only has one meaningful balance, so the
      // secondary ("saldo disponibile") slot is left unset.
      primaryBalanceOf: (account) => account.availableBalance,
      primaryBalanceLabel: 'Saldo',

      loadTransactionsPage: (account, page, pageSize) async {
        return await widget._database.getAccountTransactionSlot(account, pageSize, page * pageSize);
      },

      hasSpecificSection: false,
      database: widget._database
    );
  }
}