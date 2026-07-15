import 'package:mira_finance_tracker/classes/periodic_transactions/PeriodicTransaction.dart';
import 'package:mira_finance_tracker/classes/time_management/PeriodicAccountDuration.dart';
import 'package:mira_finance_tracker/classes/transaction/BankTransaction.dart';
import 'package:mira_finance_tracker/classes/transaction/Outcome.dart';
import 'package:mira_finance_tracker/classes/subjects/CounterParty.dart';

/// Class to manage a domiciliation coming from 
/// a specific counterparty which is not the bank, 
/// because the cashback has already been defined in another class
class Domiciliation extends PeriodicTransaction{
  /* attributes definition */
  double _fee;

  /// Constructor method of a domiciliation
  /// inside a bank account, with all the parameters needed
  /// * [name] name of the billing (unique)
  /// * [amount] amount of money of the billing
  /// * [cadence] temporal cadence of the billing
  /// * [description] optional description of the billing
  /// * [id] ID of the building (if negative it hasn't been set yet)
  /// * [counterParty] counterParty of the periodic transaction
  /// * [_fee] possible fee applied to the domiciliation
  Domiciliation(String name, double amount, PeriodicAccountDuration cadence, CounterParty counterParty, {String? description, int id = -1, this._fee = 0.0}) :
    super(name, amount, cadence, counterParty, description: description, id: id);

  /* *** GETTER METHODS *** */
  double get fee => _fee;

  /* *** SETTER METHODS *** */
  set fee(double fee){
    if(fee<0){
      throw Exception("In a domiciliation fee can't be less than 0");
    }
  }

  /// Method to check if the domiciliation has to be done
  /// and create the necessary transactions for the bank account
  @override
  List<BankTransaction> checkAndExecute(){
    List<Outcome> transactionList = []; // create the list

    /* use cycle because this operation could be 
    without a regular cadence, having even more
    transactions of the same type to do */
    while(super.cadence.isTime()){
      /* if the control has passed, add to the list the 
      various transactions to do */
      transactionList.add(
        Outcome(OutcomeCategory.domiciliation, "Periodic domiciliation coming from ${super.counterParty.name}: ${super.name}", super.amount, DateTime.now())
      );

      /* verify if the fee has to be applied, 
      and add it as a transaction */
      transactionList.add(
        Outcome(OutcomeCategory.bank_fee, "Bank fee applied to domiciliation coming from ${super.counterParty.name}: ${super.name}", super.amount, DateTime.now())
      );

      /* update the cadence counter */
      super.cadence.acknowledgeSignal(); 
      }

    return transactionList; // return the transaction
  }

  /// Function to convert a domiciliation into
  /// a map used for database manipulation
  @override
  Map<String, dynamic> toMap(){
    return {
      ...super.toMap(),
      'fee': _fee
    };
  }

  /// Method to transform the map of the dabatabase
  /// into a new object
  /// * [map] map object from the database
  /// * [counterParty] correspondent counterparty of the periodic income already converted
  factory Domiciliation.fromMap(Map<String, dynamic> map, CounterParty counterParty){
    /* first get the various parameters */
    int id = map.remove('id');
    String name = map.remove('name');
    double amount = map.remove('amount');
    double fee = map.remove('fee');
    String description = map.remove('description');
    PeriodicAccountDuration cadence = PeriodicAccountDuration.fromMap(map);

    /* return the object of the cashback class
    with the attributes provided */
    return Domiciliation(name, amount, cadence, counterParty, id: id, description: description, fee: fee);
  }

  /// Method to get a deep clone of the instance
  @override
  Domiciliation clone(){
    return Domiciliation(super.name, super.amount, super.cadence.clone(), super.counterParty.clone(),
            description: super.description, id: super.id, fee: _fee);
  }
}