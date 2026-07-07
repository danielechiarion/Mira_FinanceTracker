import 'package:mira_finance_tracker/classes/periodic_transactions/PeriodicAccountBillings.dart';
import 'package:mira_finance_tracker/classes/subjects/CounterParty.dart';
import 'package:mira_finance_tracker/classes/time_management/PeriodicAccountDuration.dart';

/// Class to manage general periodic transaction inside
/// a bank account which is not related to
/// the bank fees and cashback configured in the bank account,
/// but requires another counter party
abstract class PeriodicTransaction extends PeriodiAccountBillings{
  /* attributes definition */
  CounterParty _counterParty;

  /// Constructor method of a periodic transaction 
  /// inside a bank account, with all the parameters needed
  /// * [name] name of the billing (unique)
  /// * [amount] amount of money of the billing
  /// * [cadence] temporal cadence of the billing
  /// * [description] optional description of the billing
  /// * [id] ID of the building (if negative it hasn't been set yet)
  /// * [_counterParty] counterParty of the periodic transaction
  PeriodicTransaction(String name, double amount, PeriodicAccountDuration cadence, this._counterParty, {String? description, int id = -1}) :
    super(name, amount, cadence, description: description, id: id);

  /* *** GETTER METHODS *** */
  CounterParty get counterParty => _counterParty;

  /* *** SETTER METHODS *** */
  set counterParty(CounterParty counterParty) => _counterParty = counterParty;

  /// Function to convert a periodic transaction into
  /// a map used for database manipulation
  Map<String, dynamic> toMap(){
    return{
      ...super.toMap(),
      'counterParty': _counterParty.identifier
    };
  }
}