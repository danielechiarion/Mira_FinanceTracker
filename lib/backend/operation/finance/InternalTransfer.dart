import 'package:mira_finance_tracker/classes/bank_account/BankAccount.dart';
import 'package:mira_finance_tracker/classes/transaction/BankTransaction.dart';
import 'package:mira_finance_tracker/classes/transaction/Income.dart';
import 'package:mira_finance_tracker/classes/transaction/Outcome.dart';
import 'package:mira_finance_tracker/classes/account/User.dart';

import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';

/// Class use to manage internal transfer bewteen 
/// to registered bank accounts belonging to the same user
class InternalTransfer{
  /* define attributes */
  BankAccount _startingAccount;
  BankAccount _endingAccount;
  double _amount;
  double _fee;
  DateTime _executionDate;
  DateTime _accountingDate;
  User _user;

  /// Constructor of the internal transfer with all the necessary parameters
  /// * [_user] owner of the two bank accounts
  /// * [_startingAccount] bank account where to start the operation
  /// * [_endingAccount] bank account where to end the operation
  /// * [_amount] amount of money of the transfer
  /// * [_fee] fee applied for the transfer to the starting account
  /// * [_executionDate] date of execution of the transfer
  /// * [_accountingDate] date when the transfer has been accounted
  InternalTransfer(this._user, this._startingAccount, this._endingAccount, this._amount,
    {DateTime? executionDate, DateTime? accountingDate, this._fee = 0.0}):
    _executionDate = executionDate ?? DateTime.now(), _accountingDate = accountingDate ?? executionDate ?? DateTime.now(){
      /* control attributes validity */
      if(_amount < 0){
        throw Exception("Cannot give an amount less than 0 in an internal transfer");
      }
      if(_fee < 0){
        throw Exception("In an internal transfer the fee can't be less than 0");
      }
      if(_executionDate.isAfter(_accountingDate)){
        throw Exception("In an internal transfer the execution date can't be after the accounting date");
      }

      /* then control also if it's possible
      to make the operation */
      if(_amount+_fee > _startingAccount.availableBalance){
        throw Exception("Can't make a transfer when the amount and fee applied to the starting account are higher than the available balance");
      }
    }

  Future<bool> execute() async {
    /* first create the list of transactions
    for each bank account */
    List<BankTransaction> startingTransactions = [];
    startingTransactions.add(Outcome(OutcomeCategory.internal_transfer, "Trasferimento interno a conto: ${_endingAccount.name}", _amount, _executionDate, accountingDate: _accountingDate));
    if(_fee > 0){
      startingTransactions.add(Outcome(OutcomeCategory.internal_transfer_fee, "Tassa applicata a trasferimento interno a conto: ${_endingAccount.name}", _fee, _executionDate, accountingDate: _accountingDate));
    }

    List<BankTransaction> endingTransactions = [];
    endingTransactions.add(Income(IncomeCategory.internal_transfer, "Trasferimento interno da conto ${_startingAccount.name}", _amount, _executionDate, accountingDate: _accountingDate));

    /* add these transactions to the 
    connected bank accounts */
    _startingAccount.addTransactions(startingTransactions);
    _endingAccount.addTransactions(endingTransactions);

    /* then save them into the database */
    UserDatabaseWrapper database = UserDatabaseWrapper(_user);
    await database.saveTransactions(_startingAccount.clone(), startingTransactions);
    await database.saveTransactions(_endingAccount.clone(), endingTransactions, close: true);

    return true;
  }
}