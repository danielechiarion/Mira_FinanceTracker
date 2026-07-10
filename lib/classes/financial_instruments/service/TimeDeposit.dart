import 'package:mira_finance_tracker/classes/subjects/FinancialInstitute.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/service/FinancialInstrument.dart';

/// Class to specify a particular type of financial instrument. 
/// Time deposits usually have a stable interest rate and a specified duration, 
/// with a payout frequency decided at the beginning. 
/// This services is one of the safest one to subscribe, manage and ensure interests that are low but secure. 
class TimeDeposit extends FinancialInstrument {
  /* attributes definition */
  double _interestRate; 
  bool _isCashable; // bool to understand if the 
  double _earlyWithdrawalInterestRate; // interest rate stopping the time deposit before the expiration date
}