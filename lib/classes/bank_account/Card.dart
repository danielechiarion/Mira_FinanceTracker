import 'package:mira_finance_tracker/classes/subjects/FinancialInstitute.dart';
import 'package:mira_finance_tracker/classes/periodic_transactions/BankFee.dart';
import 'package:mira_finance_tracker/classes/periodic_transactions/Cashback.dart';
import 'package:mira_finance_tracker/classes/time_management/PeriodicAccountDuration.dart';
import 'package:mira_finance_tracker/classes/time_management/DurationType.dart';
import 'package:mira_finance_tracker/classes/transaction/BankTransaction.dart';
import 'package:mira_finance_tracker/classes/transaction/Outcome.dart';
import 'package:mira_finance_tracker/classes/bank_account/BankAccount.dart';

/// Enumerator to classify different
/// types of card
enum CardType{
  credit,
  debit,
  prepaid
}

/// Class to manage specific single card management,
/// used on its own and not belonging to a specific bank account.
/// Override of the class [BankAccount]
class Card extends BankAccount{
  /* attributes definition */
  CardType _cardType;
  late PeriodicAccountDuration? _creditTime;

  /// Constructor method to build a card account
  /// with all its necessary data
  /// * [name] unique name given by the user to the bank account
  /// * [bank] bank institute where the bank account belongs
  /// * [subscriptionDate] date of the subscription of the bank account
  /// * [id] ID of the account from the database (it will be -1 right after the instantiation)
  /// * [availableBalance] it indicates how much money are available for the user
  /// * [IBAN] IBAN code of the bank account (optional)
  /// * [interest] possible interest applied to the availble balance of the bank account
  /// * [active] flag to understand if the user wants this bank account active or just archived
  /// * [endingDate] possible ending date of use of the bank account
  /// * [fees] list of fees of the bank account
  /// * [cashbacks] list of cashbacks of the bank account
  /// * [transactions] list of transactions of the bank account (not necessarily all of them)
  /// * [_cardType] type of card used
  Card(String name, FinancialInstitute bank, DateTime subscriptionDate, this._cardType,
    {int id=-1, double availableBalance = 0.0, String? IBAN, double interest = 0, bool active = true, DateTime? endingDate, PeriodicAccountDuration? interestTime,
    List<BankFee>? fees, List<Cashback>? cashbacks, List<BankTransaction>? transactions, int? dayOfMonthCredit, DateTime? lastDateActivityCredit}) : 
    super(name, bank, subscriptionDate, id: id, availableBalance: availableBalance, IBAN: IBAN, interest: interest,
    active: active, endingDate: endingDate, interestTime: interestTime,
    fees: fees, cashbacks: cashbacks, transactions: transactions){
    /* control attributes validity */
    if(_cardType == CardType.credit && dayOfMonthCredit == null){
      throw Exception("Can't set a credit card without the day of month attribute given");
    }

    if(_cardType == CardType.credit && dayOfMonthCredit != null){
      _creditTime = PeriodicAccountDuration(super.subscriptionDate, DurationType.monthly, dayOfMonthCredit, lastDateActivity: lastDateActivityCredit);
    }
  }

  /* *** GETTER METHODS *** */
  CardType get cardType => _cardType;
  PeriodicAccountDuration? get creditTime => _creditTime?.clone();

  /* *** SETTER METHODS *** */
  set creditTime(PeriodicAccountDuration creditTime){
    if(_cardType != CardType.credit){
      throw Exception("Cannot set the credit time if the card is not of type credit");
    }
  }

  /* function to understand if the transaction 
  can receive the credit from the card */
  bool _hasCredit(BankTransaction transaction){
    return transaction is Outcome && _cardType == CardType.credit && 
            transaction.category == OutcomeCategory.general_outcome &&
            (_creditTime!.lastDateActivity == null || transaction.executionDate.isAfter(_creditTime!.lastDateActivity!));
  }

  /// Function to add the transaction
  /// checking if the card has credit
  /// and postpone the payment. 
  /// Override of the superclass method of [BankAccount].
  /// * [transaction] transaction to save
  @override
  void addTransaction(BankTransaction transaction){
    /* first understand if the card is a credit
    one and the payment is after the last 
    activity date */
    if(_hasCredit(transaction)){
      transaction.accountingDate = _creditTime!.returnNextSignalDate();
      /* add the sum that will be subtracted
      after for the credit given by the credit card */
      super.availableBalance += transaction.amount;
    }

    addTransaction(transaction); // save the transaction
  }

  /// Method to remove a transaction considering the 
  /// possibility to have a credit card. 
  /// Override of the superclass method of [BankAccount].
  /// * [transaction] transaction to save
  @override
  void removeTransaction(BankTransaction transaction){
    /* understand if the transaction belongs
    to a credit card which still has not registered it. 
    In that case the available balance should not change */
    BankTransaction? existingTransaction = super.removeTransaction(transaction);
    if(existingTransaction != null && _hasCredit(existingTransaction)){
      super.availableBalance -= existingTransaction.amount;
    }
  }

  /// Method to replace a transaction considering the 
  /// possibility to have a credit card. 
  /// Override of the superclass method of [BankAccount].
  /// * [transaction] transaction to save
  @override
  void replaceTransaction(BankTransaction transaction){
    BankTransaction? existingTransaction = super.replaceTransaction(transaction); // call the method and find the original transaction
    if(existingTransaction == null){
      return;
    }
    
    /* understand if both of them
    had credit and restore the available balance */
    if(_hasCredit(existingTransaction)){
      super.availableBalance -= existingTransaction.amount;
    }
    if(_hasCredit(transaction)){
      super.availableBalance += existingTransaction.amount;
    }
  }

  /// Function to check periodic operations to be done
  /// overriding the superclas method in [BankAccount]
  @override
  void check(){
    _checkCredit(); // check credit
    super.check();
  }

  /* function to check credit inside the card */
  void _checkCredit(){
    /* this function works only for credit card */
    if(cardType != CardType.credit){
      return;
    }

    /* then control if it's time to 
    reduce the available balance following the day of month
    selected by the credit card */
    if(!_creditTime!.isTime()){
      return;
    }

    /* use variables for the operations */
    DateTime nextSignalDate = _creditTime!.returnNextSignalDate();

    for(BankTransaction transaction in super.transactions){
      /* understand immediately by the list
      already sorted if the transaction is in time window.
      Otherwise, using a descending date order, this would mean 
      there is no need to check the following transactions */
      if(!transaction.accountingDate.isAfter(nextSignalDate)){
        break;
      }
      
      /* first check if we have credit */
      if(_hasCredit(transaction)){
        super.availableBalance -= transaction.amount;
      }
    }

    _creditTime!.acknowledgeSignal(); // acknowledge the date of operations of the credit card
  }

  /// Method to generate a deep clone of the card
  @override
  Card clone(){
    return Card(super.name, super.bank, super.subscriptionDate, _cardType, id: super.id, availableBalance: super.availableBalance,
                      IBAN: super.IBAN, interest: super.interest, active: super.isActive, endingDate: super.endingDate,
                      interestTime: super.interestTime, fees: super.fees, cashbacks: super.cashbacks, transactions: super.transactions,
                      dayOfMonthCredit: _creditTime?.dayOfMonth, lastDateActivityCredit: _creditTime?.lastDateActivity);
  }

  /// Function to convert an object into
  /// map for database manipulation
  @override
  Map<String, dynamic> toMap(){
    return {
      ...super.toMap(),
      'dayOfMonthCredit': _creditTime?.dayOfMonth,
      'lastDateActivityCredit': _creditTime?.lastDateActivity?.toIso8601String(),
      'cardType': _cardType.index
    };
  }

  /// Method to convert a map object into a 
  /// Card instance
  /// * [map] map object from database
  /// * [fees] list of fees
  /// * [cashbacks] list of cashbacks
  /// * [transactions] list of transactions
  /// 
  /// All the arguments except for the map comes from other tables,
  /// so they have to be already converted. 
  factory Card.fromMap(Map<String, dynamic> map, List<BankFee> fees, List<Cashback> cashbacks, List<BankTransaction> transactions, FinancialInstitute financialInstitute){
    return Card(
      map.remove('name'),
      financialInstitute,
      DateTime.parse(map.remove('subscriptionDate')),
      CardType.values[map['cardType']],
      id: map.remove('id'),
      availableBalance: map.remove('availableBalance'),
      IBAN: map.remove('IBAN'),
      interest: map.remove('interest'),
      active: map.remove('active'),
      endingDate: map.remove('endingDate'),
      interestTime: PeriodicAccountDuration.fromMap(map),
      fees: fees,
      cashbacks: cashbacks,
      transactions: transactions,
      dayOfMonthCredit: map['dayOfMonthCredit'],
      lastDateActivityCredit: DateTime.parse(map['lastDateActivityCredit'])
    );
  }
}