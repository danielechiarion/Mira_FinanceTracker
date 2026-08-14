import 'package:mira_finance_tracker/classes/transaction/BankTransaction.dart';
import 'package:mira_finance_tracker/classes/subjects/CounterParty.dart';

/// Enumerator used to classify
/// different categories of an outcome for the application
/// made by the user or by the automatic calculation of the software
enum OutcomeCategory{
  bank_fee,
  financial_tax,
  domiciliation,
  general_outcome,
  internal_transfer,
  internal_transfer_fee,
  stock_investment,
  stock_fee,
  stock_loss,
  other
}

class Outcome extends BankTransaction{
  /* attributes definition */
  OutcomeCategory _category;

  /// Constructor method of the outcome class
  /// * [reference] the reference of the outcome
  /// * [counterParty] the counterparty of the outcome
  /// * [amount] the amount of the outcome
  /// * [executionDate] the execution date of the outcome
  /// * [accountingDate] the accounting date of the outcome (if not set is the execution date)
  /// * [id] the ID of the outcome (firstly it will be -1, then it will be set by the database)
  /// * [_category] the category of the outcome
  Outcome(this._category, String reference, double amount, DateTime executionDate, {int id = -1, CounterParty? counterParty, DateTime? accountingDate})
      : super(reference, amount, executionDate, id: id, counterParty: counterParty, accountingDate: accountingDate) {
    if((_category == OutcomeCategory.domiciliation || _category == OutcomeCategory.general_outcome) && counterParty == null){
      throw Exception("Outcomes not related to the bank or owned bank accounts must have a specified counterparty");
    }
  }

  /* *** GETTER METHODS *** */
  OutcomeCategory get category => _category;

  /// Method to convert an outcome object into 
  /// a map one for database manipulation
  @override
  Map<String, dynamic> toMap(){
    return {
      'category': _category.index,
      'reference': super.reference,
      'amount': super.amount,
      'executionDate': super.executionDate,
      'counterParty': super.counterParty?.identifier,
      'accountingDate': super.accountingDate,
    };
  }

  /// Static method to convert a map object
  /// to an outcome one to use it inside the application
  /// * [map] map object coming from the database
  static Outcome fromMap(Map<String, dynamic> map, {CounterParty? counterParty}){
    return Outcome(
      OutcomeCategory.values[map['category']],
      map['reference'],
      map['amount'],
      map['executionDate'],
      id: map['id'],
      counterParty: counterParty,
      accountingDate: map['accountingDate']
    );
  }

  /// Method to get a deep clone of the instance
  @override
  Outcome clone(){
    return Outcome(_category, super.reference, super.amount, super.executionDate, 
            id: super.id, counterParty: super.counterParty, accountingDate: super.accountingDate);
  }
}