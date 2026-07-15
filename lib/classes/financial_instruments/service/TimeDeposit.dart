import 'package:mira_finance_tracker/classes/subjects/FinancialInstitute.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/service/FinancialInstrument.dart';
import 'package:mira_finance_tracker/classes/time_management/DurationType.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/model/TimeDepositModel.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/model/FinancialInstrumentModel.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/elements/CadenceCheck.dart';
import 'package:mira_finance_tracker/classes/time_management/LimitedAccountDuration.dart';
import 'package:mira_finance_tracker/classes/time_management/LongDuration.dart';
import 'package:mira_finance_tracker/classes/transaction/BankTransaction.dart';
import 'package:mira_finance_tracker/classes/transaction/Income.dart';
import 'package:mira_finance_tracker/classes/transaction/Outcome.dart';

/// Class to specify a particular type of financial instrument. 
/// Time deposits usually have a stable interest rate and a specified duration, 
/// with a payout frequency decided at the beginning. 
/// This services is one of the safest one to subscribe, manage and ensure interests that are low but secure. 
class TimeDeposit extends FinancialInstrument implements CadenceCheck{
  /* attributes definition */
  double _interestRate; 
  bool _isCashable; // bool to understand if the time deposit can be cashed before the real end
  double _earlyWithdrawalInterestRate; // interest rate stopping the time deposit before the expiration date
  late LimitedAccountDuration _timeInfo;

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
  /// 
  /// There also some other variables used to build the time information attribute, 
  /// which is an instance of the [LimitedAccountDuration] class helping on understanding whether it's time
  /// to calculate the interests and the fees.
  TimeDeposit(String name, FinancialInstrumentProvider providerType, double initialValue, double taxRate, String instrumentUsed, this._interestRate,
    DateTime startingDate, DurationType frequency, int dayOfMonth, 
    {int? monthOfYear, bool? includeStart, DateTime? lastDateActivity, bool? includeEnd, DateTime ?endingDate, LongDuration? duration,
    int id = -1, FinancialInstitute? provider, double? currentValue, FinancialInstrumentStatus? status, 
    this._isCashable = true, this._earlyWithdrawalInterestRate = 0.0}) :
    super(name, providerType, initialValue, taxRate, 
    id: id, provider: provider, instrumentUsed: instrumentUsed, currentValue: currentValue, financialInstrumentStatus: status) {
      /* control the validity of some attributes */
      if(_interestRate <= 0.0){
        throw Exception("In a time deposit interest rate can't be 0% or less");
      }
      if(_earlyWithdrawalInterestRate < 0.0){
        throw Exception("In a time deposit the early withdrawal interest rate can't be 0% or less");
      }
      
      /* initialize time info starting from the attributes given by the user */
      if(monthOfYear != null){
        _timeInfo = LimitedAccountDuration(startingDate, frequency, dayOfMonth,
                                          monthOfYear: monthOfYear, includeStart: includeStart ?? false, lastDateActivity: lastDateActivity,
                                          includeEnd: includeEnd ?? false, endingDate: endingDate, duration: duration);
      } else {
        _timeInfo = LimitedAccountDuration(startingDate, frequency, dayOfMonth,
                                          includeStart: includeStart ?? false, lastDateActivity: lastDateActivity,
                                          includeEnd: includeEnd ?? false, endingDate: endingDate, duration: duration);
      }
  }

  /// Add a second constructor that create a time deposit starting from a model, 
  /// so as to copy the information in the instrument used. 
  /// It safer not to have the reference of the model because it could change over time, 
  /// but the conditions for the single time deposit has to remain the same till the end. 
  factory TimeDeposit.fromModel(TimeDepositModel model, String name, double initialValue,
                                {DateTime? startingDate, int? id, int? day, int? month, bool includeStart = false, bool includeEnd = false, double? currentValue}){
    /* define missing attributes */
    DateTime firstDate = startingDate ?? DateTime.now();
    /* for day of month and month year, pickup the 
    one of the starting date */
    int dayOfMonth = day ?? firstDate.day;
    int? monthOfYear;
    if(model.payoutFrequency.index >= DurationType.annual.index){
      monthOfYear = month ?? firstDate.month;
    }

    /* create the object */
    return TimeDeposit(
      name,
      model.providerType,
      initialValue,
      model.taxRate,
      model.name,
      model.interestRate,
      firstDate,
      model.payoutFrequency,
      dayOfMonth,
      monthOfYear: monthOfYear,
      includeStart: includeStart,
      includeEnd: includeEnd,
      id: id ?? -1,
      currentValue: currentValue,
      duration: model.duration.clone(),
      provider: model.provider?.clone()
    );
  }

  /// Another version of the constructor with the duration expressed instead of the different parameters  
  TimeDeposit.withTimeInfo(String name, FinancialInstrumentProvider providerType, double initialValue, double taxRate, String instrumentUsed, this._interestRate,
    LimitedAccountDuration timeInfo,
    {int id = -1, FinancialInstitute? provider, double? currentValue, FinancialInstrumentStatus? status, 
    this._isCashable = true, this._earlyWithdrawalInterestRate = 0.0}) :
    super(name, providerType, initialValue, taxRate, 
    id: id, provider: provider, instrumentUsed: instrumentUsed, currentValue: currentValue, financialInstrumentStatus: status){
    /* control the validity of some attributes */
    if(_interestRate <= 0.0){
      throw Exception("In a time deposit interest rate can't be 0% or less");
    }
    if(_earlyWithdrawalInterestRate < 0.0){
      throw Exception("In a time deposit the early withdrawal interest rate can't be 0% or less");
    }

    /* attributes assignment */
    _timeInfo = timeInfo;
  }

  /* *** GETTER METHODS *** */
  double get interestRate => _interestRate;
  bool get isCashable => _isCashable;
  double get earlyWithdrawalInterestRate => _earlyWithdrawalInterestRate;
  @override
  LimitedAccountDuration get timeInfo => _timeInfo.clone();

  /* *** SETTER METHODS *** */
  set interestRate(double interestRate){
    if(interestRate <= 0.0){
      throw Exception("In a time deposit interest rate can't be 0% or less");
    }
    if(_timeInfo.operationAlreadyStarted()){
      throw Exception("Cannot change the interest rate now because some coupons have already been calculated");
    }

    _interestRate = interestRate;
  }
  set isCashable(bool isCashable){
    if(super.status != FinancialInstrumentStatus.ongoing){
      throw Exception("Cannot change the cashable flag when the time deposit is not on a 'ongoing' status");
    }

    _isCashable = isCashable;
  }
  set earlyWithdrawalInterestRate(double earlyWithdrawalInterestRate){
    if(super.status != FinancialInstrumentStatus.ongoing){
      throw Exception("Cannot change the withdrawal interest rate when the time deposit is not on a 'ongoing' status");
    }
    if(earlyWithdrawalInterestRate < 0.0){
      throw Exception("In a time deposit the early withdrawal interest rate can't be 0% or less");
    }

    _earlyWithdrawalInterestRate = earlyWithdrawalInterestRate;
  }
  /* setter to avoid the error but not working */
  @override
  set timeInfo(dynamic timeInfo){
    throw Exception("Can't set time info attribute");
  }

  /// Override of the method proposed by the interface [CadenceCheck]
  @override
  List<BankTransaction> checkAndExecute(){
    List<BankTransaction> transactions = []; // declare an empty list

    /* use cycle because this operation could be 
    without a regular cadence, having even more
    transactions of the same type to do */
    while(super.isActive && _timeInfo.isTime()){
      /* otherwise calculate the interest, 
      the tax applied and the current value of the time deposit */
      double interests = super.initialValue * _timeInfo.timeFrequency.getExactInterest(_interestRate);
      double taxes = interests * super.taxRate;
      super.currentValue += interests - taxes;

      /* create the transactions to be returned */
      transactions.add(
        Income(IncomeCategory.financial_interest, "Interessi dal deposito: ${super.name}", interests, DateTime.now())
      );
      if(taxes > 0){
        transactions.add(
          Outcome(OutcomeCategory.financial_tax, "Tasse applicate dagli intreressi generate dal deposito: ${super.name}", taxes, DateTime.now())
        );
      }

      _timeInfo.acknowledgeSignal(); // at the end the operation register the last activity date

      /* if it's the ending date, force the 
      end method to complete the procedure */
      if(!DateTime.now().isBefore(_timeInfo.endingDate)){
        transactions.addAll(end());
        break;
      } 
    }

    return transactions;
  }

  /// Override of the stop method provided 
  /// by the class [FinancialInstrument]
  @override
  List<BankTransaction> stop({DateTime? datetimeStop}){
    DateTime stopDate = datetimeStop ?? DateTime.now(); // first get the stop date

    /* then understand if it's possible to 
    cash the time deposit */
    if(!_isCashable){
      throw Exception("Could not stop time deposit because it's not cashable before expiration date");
    }

    /* otherwise calculate a possible interest gained by 
    rate provided by the financial institute */
    double interests = super.initialValue * _timeInfo.timeFrequency.getExactInterest(_earlyWithdrawalInterestRate);
    double taxes = interests * super.taxRate;
    
    /* create the transactions */
    List<BankTransaction> transactions = [];
    transactions.add(
      Income(IncomeCategory.financial_cashing, "Incasso capitale deposito ${super.name} dopo liquidazione anticipata", super.initialValue, stopDate)
    );
    if(interests > 0){
      Income(IncomeCategory.financial_interest, "Interessi liquidazione anticipata deposito: ${super.name}", interests, stopDate);
    }
    if(taxes > 0){
      Outcome(OutcomeCategory.financial_tax, "Tasse applicate sulla liquidazione anticipata del deposito: ${super.name}", taxes, stopDate);
    }

    super.stop(); // do the operation provided in the super stop method provided

    return transactions;
  } 

  /// Override of the method to reduce the amount of the initial value
  /// provided by the class [FinancialInstrument]
  @override
  List<BankTransaction> reduce(double amount, {DateTime? datetimeWithdraw}){
    DateTime reduceDate = datetimeWithdraw ?? DateTime.now(); // get the date

    /* then understand if it's possible to 
    cash the time deposit */
    if(!_isCashable){
      throw Exception("Could not stop time deposit because it's not cashable before expiration date");
    }

    /* then control if the amount to retire is available 
    from the value of the time deposit */
    if(amount > super.initialValue){
      throw Exception("Cannot reduce the time deposit of an amount which is not available in the initial value");
    }

    /* create the transactions */
    List<BankTransaction> transactions = [];
    transactions.add(
      Income(IncomeCategory.financial_cashing, "Riduzione capitale deposito ${super.name} dopo liquidazione anticipata", amount, reduceDate)
    );

    super.reduce(amount); // call super method

    return transactions; // return the list of transactions
  }

  /// Method to end regularly a time deposit, override
  /// of the one provided by the class [FinancialInstrument]
  @override
  List<BankTransaction> end(){
    /* create the transactions */
    List<BankTransaction> transactions = [];
    transactions.add(
      Income(IncomeCategory.financial_cashing, "Scadenza deposito ${super.name}", super.initialValue, _timeInfo.endingDate)
    );

    super.end(); // call the super method for ending

    return transactions;
  }
  
  /// Method to generate a deep clone of the instance
  @override
  TimeDeposit clone(){
    return TimeDeposit(
      super.name,
      super.providerType,
      super.initialValue,
      super.taxRate,
      super.instrumentModelName!,
      _interestRate,
      _timeInfo.startingDate,
      _timeInfo.timeFrequency,
      _timeInfo.dayOfMonth,
      monthOfYear: _timeInfo.monthOfYear,
      includeStart: _timeInfo.includeStart,
      lastDateActivity: _timeInfo.lastDateActivity,
      includeEnd: _timeInfo.includeEnd,
      endingDate: _timeInfo.endingDate,
      id: super.id,
      provider: super.provider?.clone(),
      currentValue: super.currentValue,
      isCashable: _isCashable,
      earlyWithdrawalInterestRate: _earlyWithdrawalInterestRate
    );
  }

  /// Method to convert an object into a map for
  /// database manipulation
  @override
  Map<String, dynamic> toMap(){
    return {
      ...super.toMap(),
      'interestRate': _interestRate,
      'isCashable': _isCashable,
      'earlyWithdrawalInterestRate': _earlyWithdrawalInterestRate,
      ..._timeInfo.toMap()
    };
  }

  /// Factory method to transform a map object into an 
  /// instance of a time deposit
  /// * [map] map object from the database
  /// * [provider] optional provider of the time deposit service
  factory TimeDeposit.fromMap(Map<String, dynamic> map, FinancialInstitute? provider){
    return TimeDeposit.withTimeInfo(
      map.remove('name'),
      FinancialInstrumentProvider.values[map.remove('providerType')],
      map.remove('initialValue'),
      map.remove('taxRate'),
      map.remove('instrumentUsed'),
      map.remove('interestRate'),
      id: map.remove('id'),
      provider: map.remove('provider'),
      currentValue: map.remove('currentValue'),
      status: FinancialInstrumentStatus.values[map.remove('status')],
      isCashable: map.remove('isCashable'),
      earlyWithdrawalInterestRate: map.remove('earlyWithdrawalInterestRate'),
      LimitedAccountDuration.fromMap(map)
    );
  }
}