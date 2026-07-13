import 'package:mira_finance_tracker/classes/subjects/FinancialInstitute.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/service/FinancialInstrument.dart';
import 'package:mira_finance_tracker/classes/time_management/DurationType.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/model/TimeDepositModel.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/model/FinancialInstrumentModel.dart';

/// Class to specify a particular type of financial instrument. 
/// Time deposits usually have a stable interest rate and a specified duration, 
/// with a payout frequency decided at the beginning. 
/// This services is one of the safest one to subscribe, manage and ensure interests that are low but secure. 
class TimeDeposit extends FinancialInstrument {
  /* attributes definition */
  double _interestRate; 
  bool _isCashable; // bool to understand if the time deposit can be cashed before the real end
  double _earlyWithdrawalInterestRate; // interest rate stopping the time deposit before the expiration date
  DateTime _expirationDate;

  /// Constructor to define a time deposit with all the necessary parameters
  /// * [name] name of the financial instrument, which has to be unique
  /// * [providerType] type of provider of the service (main difference is between public and private institution)
  /// * [initialValue] initial value of the financial instrument
  /// * [taxRate] tax rate applied to the interests earned
  /// * [id] ID of the financial instrument mainly used by the database (if not set it's -1)
  /// * [provider] information about the provider of the service (mandatory if it's a private institution)
  /// * [currentValue] current value of the financial instrument with all the interest calculated so far
  /// * [status] status of the financial instrument (ended, ongoing, stopped etc.)
  /// * [_interestRate] interest received annually
  /// * [_isCashable] maeans if the time deposit should be reduced or stopped before the end provided
  /// * [_earlyWithdrawalInterestRate] possible interest rate when the time deposit has been cashed before
  TimeDeposit(String name, FinancialInstrumentProvider providerType, double initialValue, double taxRate, String instrumentUsed, 
    DurationType payoutFrequency, this._interestRate, this._expirationDate,
    {int id = -1, FinancialInstitute? provider, DateTime? subscriptionDate, double? currentValue, FinancialInstrumentStatus? status,
    this._isCashable = true, this._earlyWithdrawalInterestRate = 0.0}) :
    super(name, providerType, initialValue, taxRate, instrumentUsed, payoutFrequency, 
    id: id, provider: provider, subscriptionDate: subscriptionDate, currentValue: currentValue, financialInstrumentStatus: status);
}