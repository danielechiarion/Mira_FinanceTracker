import 'package:mira_finance_tracker/classes/periodic_transactions/PeriodicAccountBillings.dart';
import 'package:mira_finance_tracker/classes/time_management/PeriodicAccountDuration.dart';
import 'package:mira_finance_tracker/classes/transaction/BankTransaction.dart';
import 'package:mira_finance_tracker/classes/transaction/Income.dart';

/// Class made to manage the periodic cashback inside a bank accounts,
/// registering the incomes provided 
class Cashback extends PeriodicAccountBillings{
  /// Constructor method of the cashback 
  /// inside a bank account, with all the parameters needed
  /// * [name] name of the billing (unique)
  /// * [amount] amount of money of the billing
  /// * [cadence] temporal cadence of the billing
  /// * [description] optional description of the billing
  /// * [id] ID of the building (if negative it hasn't been set yet)
  Cashback(String name, double amount, PeriodicAccountDuration cadence, {String? description, int id = -1}) :
    super(name, amount, cadence, description: description, id: id);

  /// Function to check and execute billings and return
  /// a list of bank transactions for the account selected
  @override
  List<BankTransaction> checkAndExecute(){
    List<Income> transactionList = []; // create the list

    /* use cycle because this operation could be 
    without a regular cadence, having even more
    transactions of the same type to do */
    while(super.cadence.isTime()){
      /* if the control has passed, add to the list the 
      various transactions to do */
      transactionList.add(
        Income(IncomeCategory.bank_cashback, "Cashback: ${super.name}", super.amount, DateTime.now())
      );

      /* update the cadence counter */
      super.cadence.acknowledgeSignal(); 
    }

    return transactionList; // return the transaction
  }

  /// Method to build the cashback instance from
  /// a map of the database
  /// * [inputMap] map of the database
  factory Cashback.fromMap(Map<String, dynamic> inputMap){
    Map<String, dynamic> map = Map<String, dynamic>.from(inputMap);
    
    /* first get the various parameters */
    int id = map.remove('id');
    String name = map.remove('name');
    double amount = map.remove('amount');
    String description = map.remove('description');
    PeriodicAccountDuration cadence = PeriodicAccountDuration.fromMap(map);

    /* return the object of the cashback class
    with the attributes provided */
    return Cashback(name, amount, cadence, id: id, description: description);
  }

  /// Method to get a deep clone of the instance
  @override
  Cashback clone(){
    return Cashback(super.name, super.amount, super.cadence.clone(),
                    description: super.description, id: super.id);
  }
}