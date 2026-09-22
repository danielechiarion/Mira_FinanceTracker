import 'package:mira_finance_tracker/classes/transaction/BankTransaction.dart';
import 'package:mira_finance_tracker/classes/subjects/CounterParty.dart';

import 'package:mira_finance_tracker/backend/service/notification/NotificationData.dart';

/// Enumerator used to classify
/// different categories of an outcome for the application
/// made by the user or by the automatic calculation of the software
enum OutcomeCategory{
  bank_fee("Commissione conto", false),
  financial_tax("Tassa d'investimento", false),
  domiciliation("Domiciliazione", true),
  general_outcome("Addebito generico", true),
  internal_transfer("Addebito da girofondo", false),
  internal_transfer_fee("Commissione da girofondo", false),
  financial_investment("Investimento", false),
  stock_fee("Tassazione azioni", false),
  stock_loss("Perdita azioni", false),
  other("Altro", false);

  /* define attributes */
  final String name;
  final bool counterPartyRequired;

  /* define constructor allowing names 
  to define the outcome operation */
  const OutcomeCategory(this.name, this.counterPartyRequired);

  /// Get the different outcome operations types
  /// for the current account
  static List<OutcomeCategory> getCurrentAccountOperations(){
    return [
      bank_fee,
      domiciliation,
      general_outcome,
      internal_transfer,
      internal_transfer_fee,
      other
    ];
  }

  /// Get the different outcome operations types
  /// for the savings account
  static List<OutcomeCategory> getSavingsAccountOperations(){
    return [
      bank_fee,
      financial_tax,
      financial_investment,
      stock_fee,
      stock_loss,
      general_outcome,
      internal_transfer,
      internal_transfer_fee,
      other
    ];
  }

  /// Get the different outcome operations types
  /// for the card account
  static List<OutcomeCategory> getCardOperations(){
    return [
      bank_fee,
      general_outcome,
      internal_transfer,
      internal_transfer_fee,
      other
    ];
  }
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
      if(super.id >= 0) 'id': super.id,
      'category': _category.index,
      'reference': super.reference,
      'amount': super.amount,
      'executionDate': super.executionDate.toIso8601String(),
      'counterParty': super.counterParty?.identifier,
      'accountingDate': super.accountingDate.toIso8601String(),
    };
  }

  /// Static method to convert a map object
  /// to an outcome one to use it inside the application
  /// * [map] map object coming from the database
  static Outcome fromMap(Map<String, dynamic> map, {CounterParty? counterParty}){
    final categoryIndex = map['category'] as int? ?? OutcomeCategory.general_outcome.index;

    return Outcome(
      OutcomeCategory.values[categoryIndex],
      map['reference'],
      map['amount'],
      DateTime.parse(map['executionDate']),
      id: map['id'],
      counterParty: counterParty,
      accountingDate: DateTime.parse(map['accountingDate'])
    );
  }

  /// Method to get a deep clone of the instance
  @override
  Outcome clone(){
    return Outcome(_category, super.reference, super.amount, super.executionDate, 
            id: super.id, counterParty: super.counterParty, accountingDate: super.accountingDate);
  }

  /// Override method to convert Outcome to notification
  /// from [BankTransaction] class
  @override
  NotificationData toNotification() {
    String title = ""; // define title to be changed

    if(_category == OutcomeCategory.bank_fee){
      title = "Commissione conto";
    } else if(_category == OutcomeCategory.financial_tax){
      title = "Tassa d'investimento";
    } else if(_category == OutcomeCategory.domiciliation){
      title = "Domiciliazione";
    } else if(_category == OutcomeCategory.general_outcome){
      title = "Addebito generico";
    } else if(_category == OutcomeCategory.internal_transfer){
      title = "Addebito da girofondo";
    } else if(_category == OutcomeCategory.internal_transfer_fee){
      title = "Commissione da girofondo";
    } else if(_category == OutcomeCategory.financial_investment){
      title = "Investimento";
    } else if(_category == OutcomeCategory.stock_fee){
      title = "Tassazione azioni";
    } else if(_category == OutcomeCategory.stock_loss){
      title = "Perdita azioni";
    } else {
      title = "Altro addebito";
    }

    title += ": ${super.amount}€"; // then add the amount paid

    return NotificationData(
      title,
      super.reference
    );
  }
}