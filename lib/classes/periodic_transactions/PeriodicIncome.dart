import 'package:mira_finance_tracker/classes/periodic_transactions/PeriodicTransaction.dart';
import 'package:mira_finance_tracker/classes/time_management/PeriodicAccountDuration.dart';
import 'package:mira_finance_tracker/classes/transaction/BankTransaction.dart';
import 'package:mira_finance_tracker/classes/transaction/Income.dart';
import 'package:mira_finance_tracker/classes/subjects/CounterParty.dart';

/// Class to manage a periodic income coming from 
/// a specific counterparty which is not the bank, 
/// because the cashback has already been defined in another class
class PeriodicIncome extends PeriodicTransaction{
  /// Constructor method of a periodic income 
  /// inside a bank account, with all the parameters needed
  /// * [name] name of the billing (unique)
  /// * [amount] amount of money of the billing
  /// * [cadence] temporal cadence of the billing
  /// * [description] optional description of the billing
  /// * [id] ID of the building (if negative it hasn't been set yet)
  /// * [counterParty] counterParty of the periodic transaction
  PeriodicIncome(String name, double amount, PeriodicAccountDuration cadence, CounterParty counterParty, {String? description, int id = -1}) :
    super(name, amount, cadence, counterParty, description: description, id: id);

  /// Method to check if the periodic income has to be done
  /// and create the necessary transactions for the bank account
  @override
  List<BankTransaction> checkAndExecute(){
    List<Income> transactionList = []; // create the list

    /* use cycle because this operation could be 
    without a regular cadence, having even more
    transactions of the same type to do */
    while(super.originalCadence.isTime()){
      /* if the control has passed, add to the list the 
      various transactions to do */
      transactionList.add(
        Income(IncomeCategory.periodic_income, "Periodic income coming from ${super.counterParty.name}: ${super.name}", super.amount, DateTime.now())
      );

      /* update the cadence counter */
      super.originalCadence.acknowledgeSignal(); 
    }

    return transactionList; // return the transaction
  }

  /// Method to transform the map of the dabatabase
  /// into a new object
  /// * [map] map object from the database
  /// * [counterParty] correspondent counterparty of the periodic income already converted
  factory PeriodicIncome.fromMap(Map<String, dynamic> map, CounterParty counterParty){
    /* first get the various parameters */
      final mutableMap = Map<String, dynamic>.from(map);
      int id = mutableMap.remove('id');
      String name = mutableMap.remove('name');
      double amount = (mutableMap.remove('amount') as num).toDouble();
      String? description = mutableMap.remove('description') as String?;
      PeriodicAccountDuration cadence = PeriodicAccountDuration.fromMap(mutableMap);

    /* return the object of the cashback class
    with the attributes provided */
    return PeriodicIncome(name, amount, cadence, counterParty, id: id, description: description);
  }

  /// Method to get a deep clone of the instance
  @override
  PeriodicIncome clone(){
    return PeriodicIncome(super.name, super.amount, super.cadence.clone(), super.counterParty.clone(),
            description: super.description, id: super.id);
  }
}