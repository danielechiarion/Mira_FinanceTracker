import 'package:mira_finance_tracker/classes/transaction/BankTransaction.dart';
import 'package:mira_finance_tracker/classes/subjects/CounterParty.dart';

/// Enumeration to define the different categories of
/// income used by the application to identify the different types
/// of income that can be registered by the user and the application
enum IncomeCategory{
  bank_interest,
  bank_cashback,
  financial_interest,
  financial_dividend,
  periodic_income,  
  general_income,
  internal_transfer,
  other
}

class Income extends BankTransaction{
  /* attributes definition */
  IncomeCategory _category;

  /// Constructor method of the income class
  /// * [reference] the reference of the income
  /// * [counterParty] the counterparty of the income
  /// * [amount] the amount of the income
  /// * [executionDate] the execution date of the income
  /// * [accountingDate] the accounting date of the income (if not set is the execution date)
  /// * [id] the ID of the income (firstly it will be -1, then it will be set by the database)
  /// * [_category] the category of the income
  Income(this._category, String reference, double amount, DateTime executionDate, {int id = -1, CounterParty? counterParty, DateTime? accountingDate})
      : super(reference, amount, executionDate, id: id, counterParty: counterParty, accountingDate: accountingDate) {
    if((_category == IncomeCategory.periodic_income || _category == IncomeCategory.general_income) && counterParty == null){
      throw Exception("Incomes not related to the bank or owned bank accounts must have a specified counterparty");
    }
  }

  /* *** GETTER METHODS *** */
  IncomeCategory get category => _category;

  /// Method to convert an Income object into 
  /// a map one for database manipulation
  @override
  Map<String, dynamic> toMap(){
    return {
      'category': _category.index,
      'reference': super.reference,
      'amount': super.amount,
      'executionDate': super.executionDate,
      'counterParty': super.counterParty,
      'accountingDate': super.accountingDate,
    };
  }

  /// Static method to convert a map object
  /// to an income one to use it inside the application
  /// * [map] map object coming from the database
  static Income fromMap(Map<String, dynamic> map){
    return Income(
      IncomeCategory.values[map['category']],
      map['reference'],
      map['amount'],
      map['executionDate'],
      id: map['id'],
      counterParty: map['counterParty'],
      accountingDate: map['accountingDate']
    );
  }

  /// Method to get a deep clone of the instance
  @override
  Income clone(){
    return Income(_category, super.reference, super.amount, super.executionDate, 
            id: super.id, counterParty: super.counterParty?.clone(), accountingDate: super.accountingDate);
  }
}