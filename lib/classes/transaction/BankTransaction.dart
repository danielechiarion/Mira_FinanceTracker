import 'package:mira_finance_tracker/classes/subjects/CounterParty.dart';
import 'package:mira_finance_tracker/backend/service/notification/NotificationData.dart';

/// Abstract class to define a simple bank
/// transaction inside whatever bank account created
abstract class BankTransaction implements Comparable<BankTransaction>{
  /* attributes definition */
  int _id;
  String _reference;
  CounterParty? _counterParty;
  double _amount;
  DateTime _executionDate;
  late DateTime? _accountingDate;

  /// Constructor method of the bank transaction class
  /// * [reference] the reference of the transaction
  /// * [counterParty] the counterparty of the transaction
  /// * [amount] the amount of the transaction
  /// * [executionDate] the execution date of the transaction
  /// * [accountingDate] the accounting date of the transaction (if not set is the execution date)
  /// * [id] the ID of the transaction (firstly it will be -1, then it will be set by the database)
  BankTransaction(this._reference, this._amount, this._executionDate, {this._id = -1, this._counterParty, DateTime ?accountingDate}){
    /* first check if the amount is positive,
    otherwise it's not possible to proceed */
    if(_amount <= 0){
      throw Exception('amount must be positive');
    }
    if(accountingDate!=null && accountingDate.isBefore(_executionDate)){
      throw Exception("accounting date can't be before the execution date");
    }

    this._accountingDate = accountingDate ?? _executionDate;
    this._amount = double.parse(_amount.toStringAsFixed(2)); // round the amount to 2 decimal
  }

  /* *** GETTER METHODS *** */
  int get id => _id;
  String get reference => _reference;
  CounterParty? get counterParty => _counterParty?.clone();
  double get amount => _amount;
  DateTime get executionDate => _executionDate;
  DateTime? get accountingDate => _accountingDate;

  /* *** SETTER METHODS *** */
  set reference (String reference) => _reference = reference;
  set counterParty (CounterParty? counterParty) => _counterParty = counterParty;
  set amount (double amount) => _amount = amount;
  set executionDate (DateTime executionDate){
    /* control if the execution date remains before 
    the accounting date, otherwise it's not possible to proceed */
    if(_accountingDate != null && executionDate.isAfter(_accountingDate!)){
      throw Exception("The execution date can't be after the accounting date");
    }
    _executionDate = executionDate;
  }
  set accountingDate (DateTime? accountingDate){
    /* control if the accounting date remains after 
    the execution date, otherwise it's not possible to proceed */
    if(accountingDate != null && accountingDate.isBefore(_executionDate)){
      throw Exception("The accounting date can't be before the execution date");
    }
    _accountingDate = accountingDate;
  }
  set id (int id) => _id = id;

  /// Method to compare two bank transaction object by the ID,
  /// that is unique for each instance. 
  /// This operation can be return a real value only if the ID has been set by the database
  /// * [other] the other bank transaction object to compare with
  @override
  bool operator ==(Object other){
    return other is BankTransaction && other.runtimeType == runtimeType && _id != -1 && other._id == _id;
  }

  /// Method to generate the hashcode of the instance
  @override
  int get hashCode => _id.hashCode;

  /// Method to compare the bank transaction objects to
  /// put them in order, 
  /// first by the execution date and then by the accounting date, 
  /// both in desceding order
  /// * [other] the other bank transaction object to compare with
  @override
  int compareTo(BankTransaction other){
    /* compare the execution dates with 
    desceding order*/
    int firstComparison = other._executionDate.compareTo(_executionDate);

    /* if the result is equal, compare the accountig dates,
    also with descending order */
    if (firstComparison == 0) {
      return other._accountingDate?.compareTo(_accountingDate!) ?? 0;
    }
    return firstComparison;
  }

  /* *** METHODS TO BE IMPLEMENTED *** */
  /* methods for converting the object to and from a map
  for databse management */
  Map<String, dynamic> toMap();

  /// Method to get a deep clone of the instance
  BankTransaction clone();

  /// Method to convert a transaction to notification
  NotificationData toNotification();
}