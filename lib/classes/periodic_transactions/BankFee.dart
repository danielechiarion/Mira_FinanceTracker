import 'package:mira_finance_tracker/classes/periodic_transactions/PeriodicAccountBillings.dart';
import 'package:mira_finance_tracker/classes/time_management/PeriodicAccountDuration.dart';
import 'package:mira_finance_tracker/classes/transaction/BankTransaction.dart';
import 'package:mira_finance_tracker/classes/transaction/Outcome.dart';

/// Class made to manage the periodic Bank fees inside a bank accounts,
/// registering the outcomes provided 
class BankFee extends PeriodiAccountBillings{
  
  /// Constructor method of the Bank fee
  /// inside a bank account, with all the parameters needed
  /// * [name] name of the billing (unique)
  /// * [amount] amount of money of the billing
  /// * [cadence] temporal cadence of the billing
  /// * [description] optional description of the billing
  /// * [id] ID of the building (if negative it hasn't been set yet)
  /// * [_fee] possible fee applied to the Bank fee
  BankFee(String name, double amount, PeriodicAccountDuration cadence, {String? description, int id = -1}) :
    super(name, amount, cadence, description: description, id: id);

  /// Function to check and execute billings and return
  /// a list of bank transactions for the account selected
  @override
  List<BankTransaction> checkAndExecute(){
    List<Outcome> transactionList = []; // create the list

    /* first check if it's time for the billing,
    otherwise return an empty list */
    if(!super.cadence.isTime()){
      return transactionList;
    }

    /* if the control has passed, add to the list the 
    various transactions to do */
    transactionList.add(
      Outcome(OutcomeCategory.bank_fee, "Bank fee: ${super.name}", super.amount, DateTime.now())
    );

    /* update the cadence counter */
    super.cadence.acknowledgeSignal();

    return transactionList; // return the transaction
  }

  /// Method to build the bank fee instance from
  /// a map of the database
  /// * [map] map of the database
  factory BankFee.fromMap(Map<String, dynamic> map){
    /* first get the various parameters */
    int id = map.remove('id');
    String name = map.remove('name');
    double amount = map.remove('amount');
    String description = map.remove('description');
    PeriodicAccountDuration cadence = PeriodicAccountDuration.fromMap(map);

    /* return the object of the cashback class
    with the attributes provided */
    return BankFee(name, amount, cadence, id: id, description: description);
  }
}