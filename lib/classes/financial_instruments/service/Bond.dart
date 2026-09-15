import 'package:mira_finance_tracker/classes/subjects/FinancialInstitute.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/service/FinancialInstrument.dart';
import 'package:mira_finance_tracker/classes/time_management/DurationType.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/model/BondModel.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/model/FinancialInstrumentModel.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/elements/CadenceCheck.dart';
import 'package:mira_finance_tracker/classes/time_management/LimitedAccountDuration.dart';
import 'package:mira_finance_tracker/classes/time_management/LongDuration.dart';
import 'package:mira_finance_tracker/classes/time_management/PeriodicAccountDuration.dart';
import 'package:mira_finance_tracker/classes/transaction/BankTransaction.dart';
import 'package:mira_finance_tracker/classes/transaction/Income.dart';
import 'package:mira_finance_tracker/classes/transaction/Outcome.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/elements/InterestList.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/elements/StepInterest.dart';

/// Class of bond used to define this particular
/// type of financial instrument, with all the 
/// methods and information connected to it
class Bond extends FinancialInstrument implements CadenceCheck, InterestList{
  /* attribute definition */
  double _purchasePrice; // percentage of the starting value when the bond has been purchased
  BondType _interestType; // type of interest: fixed, variable, step
  double _minimumDenomination; // mininum value to invest or reduce, using multiples of it
  late Set<StepInterest> _couponSchedule; 
  late LimitedAccountDuration _timeInfo;

  /// Constructor to define a bond with all the necessary parameters
  /// * [name] name of the financial instrument, which has to be unique
  /// * [providerType] type of provider of the service (main difference is between public and private institution)
  /// * [initialValue] initial value of the financial instrument
  /// * [taxRate] tax rate applied to the interests earned
  /// * [id] ID of the financial instrument mainly used by the database (if not set it's -1)
  /// * [provider] information about the provider of the service (mandatory if it's a private institution)
  /// * [currentValue] current value of the financial instrument with all the interest calculated so far
  /// * [status] status of the financial instrument (ended, ongoing, stopped etc.)
  /// * [_purchasePrice] percentage of the original value considered at the moment of buying the bond (ex. 100.0%, 98.0%, 101.2%)
  /// * [_interestType] type of interest calculated in the bond (fixed, step up, variable etc.)
  /// * [_minimumDenomination] minium value used to invest or reduce the capital (then multiples of it will be considered for these operations)
  /// * [_couponSchedule] list of coupon organised in precise schedule
  /// 
  /// There also some other variables used to build the time information attribute, 
  /// which is an instance of the [LimitedAccountDuration] class helping on understanding whether it's time
  /// to calculate the interests and the fees.
  Bond(String name, FinancialInstrumentProvider providerType, double initialValue, double taxRate, 
    DateTime startingDate, DurationType frequency, int dayOfMonth, 
    this._purchasePrice, this._interestType,
    {int? monthOfYear, bool? includeStart, DateTime? lastDateActivity, bool? includeEnd, DateTime ?endingDate, LongDuration? duration,
    int id = -1, FinancialInstitute? provider, double? currentValue, FinancialInstrumentStatus? status, String? instrumentUsed,
    this._minimumDenomination = 1000, List<StepInterest>? couponSchedule}) : 
    super(name, providerType, initialValue, taxRate, 
    id: id, provider: provider, instrumentUsed: instrumentUsed, currentValue: currentValue, financialInstrumentStatus: status) {
      /* first control the validity of the 
      parameters given */
      if(_purchasePrice < 0){
        throw Exception("The percentage of purchase price in a bond can't be less than 0%");
      }
      if(_minimumDenomination > super.initialValue){
        throw Exception("The minimum denomination of a bond can't be more than the purchase value itself");
      }
      if((couponSchedule == null || couponSchedule.isEmpty) && interestType != BondType.variable){
        throw Exception("Can't set the coupon schedule empty if the interest rate is not variable.");
      }

      /* update some attributes */
      _couponSchedule = couponSchedule?.toSet() ?? {};
      super.currentValue = _purchasePrice * super.initialValue;
      if(_interestType == BondType.variable){
        _couponSchedule = {};
      }

      /* if the purchase price is >100,
      divide it with 100 */
      if(_purchasePrice > 100){
        _purchasePrice /= 100;
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

  /// Add a second constructor that create a bond starting from a model, 
  /// so as to copy the information in the instrument used. 
  /// It safer not to have the reference of the model because it could change over time, 
  /// but the conditions for the single bond has to remain the same till the end. 
  factory Bond.fromModel(BondModel model, String name, double initialValue, double purchasePrice,
                                {DateTime? startingDate, int? id, int? day, int? month, bool includeStart = false, bool includeEnd = false, double? currentValue,
                                double minimumDenomination = 1000}){
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
    return Bond(
      name,
      model.providerType,
      initialValue,
      model.taxRate,
      firstDate,
      model.payoutFrequency,
      dayOfMonth,
      purchasePrice,
      model.interestType,
      monthOfYear: monthOfYear,
      includeStart: includeStart,
      includeEnd: includeEnd,
      id: id ?? -1,
      currentValue: currentValue,
      duration: model.duration.clone(),
      provider: model.provider?.clone(),
      minimumDenomination: minimumDenomination,
      couponSchedule: model.interests,
      instrumentUsed: model.name,
    );
  }

   /// Another version of the constructor with the duration expressed instead of the different parameters  
  Bond.withTimeInfo(String name, FinancialInstrumentProvider providerType, double initialValue, double taxRate, String? instrumentUsed,
    this._purchasePrice, this._interestType, LimitedAccountDuration timeInfo,
    {int id = -1, FinancialInstitute? provider, double? currentValue, FinancialInstrumentStatus? status, 
    this._minimumDenomination = 1000, List<StepInterest>? couponSchedule}) :
    super(name, providerType, initialValue, taxRate, 
    id: id, provider: provider, instrumentUsed: instrumentUsed, currentValue: currentValue, financialInstrumentStatus: status){
    /* first control the validity of the 
    parameters given */
    if(_purchasePrice < 0){
      throw Exception("The percentage of purchase price in a bond can't be less than 0%");
    }
    if(_minimumDenomination > _purchasePrice*super.initialValue){
      throw Exception("The minimum denomination of a bond can't be more than the purchase value itself");
    }
    if((couponSchedule == null || couponSchedule.isEmpty) && interestType != BondType.variable){
      throw Exception("Can't set the coupon schedule empty if the interest rate is not variable.");
    }

    /* update some attributes */
    _couponSchedule = couponSchedule?.toSet() ?? {};
    super.currentValue = _purchasePrice * super.initialValue;
    if(_interestType == BondType.variable){
      _couponSchedule = {};
    }

    /* attributes assignment */
    _timeInfo = timeInfo;
  }

  /* *** GETTER METHODS *** */
  double get purchasePrice => _purchasePrice;
  BondType get interestType => _interestType;
  double get minimumDenomination => _minimumDenomination;
  @override
  LimitedAccountDuration get timeInfo => _timeInfo.clone();
  List<StepInterest> get couponSchedule {
    List<StepInterest> list = [];
    for(StepInterest interest in _couponSchedule){
      list.add(interest.clone());
    }

    return list;
  }

  /* *** SETTER METHODS *** */
  set interestType(BondType interestType){
    /* first control if operations has already started, 
    in this case it's not possible to change the attribute */
    if(_timeInfo.operationAlreadyStarted()){
      throw Exception("Can't change the interest type in a bond when operations have already started");
    }

    _interestType = interestType;
  }
  set minimumDenomination(double minimumDenomination){
    if(minimumDenomination <= 0){
      throw Exception("Minimum denomination in a bond is a value which must be more than 0");
    }
    if(minimumDenomination > super.initialValue){
      throw Exception("In a bond can't set minimum denomination as a higher value of the purchasing one");
    }

    _minimumDenomination = minimumDenomination;
  }
  set couponSchedule(List<StepInterest> couponSchedule){
    /* first control if operations has already started, 
    in this case it's not possible to change the attribute */
    if(_timeInfo.operationAlreadyStarted()){
      throw Exception("Can't change the coupon schedule in a bond when operations have already started");
    }
    if(couponSchedule.isEmpty && _interestType != BondType.variable){
      throw Exception("Can't set the coupon schedule empty if the interest rate is not variable.");
    }

    _couponSchedule = couponSchedule.toSet();
  }
  @override
  set timeInfo(PeriodicAccountDuration timeInfo){
    throw Exception("Can't use set time info method for bond");
  }

  /* *** METHOD FOR INTEREST *** */
  /// Override of the method define in the [InterestList] interface
  @override
  int checkDurationValidity(){
    LongDuration sumDuration = LongDuration(); // create the long duration

    /* add the duration of each interest */
    for(StepInterest singleInterest in _couponSchedule){
      sumDuration = sumDuration.addDuration(singleInterest.duration);
    }

    return sumDuration.compareTo(LongDuration.calculateExpandedDifference(_timeInfo.startingDate, _timeInfo.endingDate)); // compare the sum of durations with another duration
  }

  /// Override of the method define in the [InterestList] interface
  @override
  void addInterest(StepInterest interest, {bool checkDuration = false}) {
    /* first control if operations has already started, 
    in this case it's not possible to change the attribute */
    if(_timeInfo.operationAlreadyStarted()){
      throw Exception("Can't change the coupon schedule in a bond when operations have already started");
    }

    _couponSchedule.add(interest); // add a new interest

    /* if the control has been activated, 
    check the duration validity */
    if(!checkDuration) return;
    int result = checkDurationValidity();
    if(result == 0) return;

    if(result > 0){
      throw Exception("The total duration of the step interests adding the new one is more the original duration.");
    }else if(result < 0){
      throw Exception("The total duration of the step interests adding the new one is less the original duration.");
    }

    /* restore situation */
    _couponSchedule.remove(interest);
  }
  
  /// Override of the method define in the [InterestList] interface
  @override
  void removeInterest(int position, {bool checkDuration = false}) {
    /* first control if operations has already started, 
    in this case it's not possible to change the attribute */
    if(_timeInfo.operationAlreadyStarted()){
      throw Exception("Can't change the coupon schedule in a bond when operations have already started");
    }

    /* remove the interest */
    List<StepInterest> list = _couponSchedule.toList();
    StepInterest objectRemoved = list.removeAt(position);
    _couponSchedule = list.toSet();

    /* if the control has been activated, 
    check the duration validity */
    if(!checkDuration) return;
    int result = checkDurationValidity();
    if(result == 0) return;

    if(result > 0){
      throw Exception("The total duration of the step interests removing one is more the original duration.");
    }else if(result < 0){
      throw Exception("The total duration of the step interests removing one is less the original duration.");
    }

    /* restore situation */
    _couponSchedule.add(objectRemoved);
  }

  /// Override of the method define in the [InterestList] interface
  @override
  void replaceInterest(StepInterest interest, {int? position, bool checkDuration = false}){
    /* first control if operations has already started, 
    in this case it's not possible to change the attribute */
    if(_timeInfo.operationAlreadyStarted()){
      throw Exception("Can't change the coupon schedule in a bond when operations have already started");
    }

    /* set the new position, if given,
    to place the new interest */
    if(position != null){
      interest.position = position;
    }

    /* replace the object */
    StepInterest objectRemoved = _couponSchedule.elementAt(interest.position);
    _couponSchedule.remove(objectRemoved);
    _couponSchedule.add(interest);

    /* if the control has been activated, 
    check the duration validity */
    if(!checkDuration) return;
    int result = checkDurationValidity();
    if(result == 0) return;

    if(result > 0){
      throw Exception("The total duration of the step interests replacing one is more the original duration.");
    }else if(result < 0){
      throw Exception("The total duration of the step interests replacing one is less the original duration.");
    }

    /* restore situation */
    _couponSchedule.remove(interest);
    _couponSchedule.add(objectRemoved);
  }

  /// Override of the method proposed by the interface [CadenceCheck]
  @override
  List<BankTransaction> checkAndExecute({double? variableInterest}){
    List<BankTransaction> transactions = []; // declare an empty list

    /* use cycle because this operation could be 
    without a regular cadence, having even more
    transactions of the same type to do */
    while(super.isActive && _timeInfo.isTime()){
      /* understand the interest rate 
      to apply to the sum */
      double interestRate;
      if(_interestType == BondType.fixed){
        interestRate = _couponSchedule.first.interestRate;
      }else if(_interestType == BondType.step){
        interestRate = _getRightInterest();
      }else if(_interestType == BondType.variable && variableInterest == null){
        /* if the tax rate is variable it's impossible to calculate 
        it with the right interest, unless it's provided by the user */
        return transactions;
      }else{
        interestRate = variableInterest!;
      }

      /* otherwise calculate the interest, 
      the tax applied and the current value of the bond */
      double interests = super.initialValue * _timeInfo.timeFrequency.getExactInterest(interestRate);
      double taxes = interests * super.taxRate;
      super.currentValue += interests - taxes;

      /* create the transactions to be returned */
      transactions.add(
        Income(IncomeCategory.financial_interest, "Interessi dal titolo: ${super.name}", interests, DateTime.now())
      );
      if(taxes > 0){
        transactions.add(
          Outcome(OutcomeCategory.financial_tax, "Tasse applicate dagli intreressi generate dal titolo: ${super.name}", taxes, DateTime.now())
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

  /* function to get the right interest considering 
  the time passed from the starting date */
  double _getRightInterest(){
    /* find the exact interest of the period to 
    take into account */
    DateTime operationsDate = _timeInfo.returnNextSignalDate();

    /* find difference between starting date and 
    next operation date */
    LongDuration timeDifference = LongDuration.calculateExpandedDifference(_timeInfo.startingDate, operationsDate);
    
    /* count how many slot the program has to
    skip to find the right interest */
    LongDuration durationSum = _couponSchedule.first.duration;
    int index = 0;
    while(durationSum.compareTo(timeDifference) < 0){
      index++;
      durationSum = durationSum.addDuration(_couponSchedule.elementAt(index).duration);
    }

    return couponSchedule.elementAt(index).interestRate;
  }

  /// Method to end regularly a bond, override
  /// of the one provided by the class [FinancialInstrument]
  @override
  List<BankTransaction> end(){
    /* create the transactions */
    List<BankTransaction> transactions = [];
    transactions.add(
      Income(IncomeCategory.financial_cashing, "Scadenza titolo ${super.name}", super.initialValue, _timeInfo.endingDate)
    );

    super.end(); // call the super method for ending

    return transactions;
  }

  /// Override of the stop method provided 
  /// by the class [FinancialInstrument]
  @override
  List<BankTransaction> stop({DateTime? datetimeStop, double sellingValue = 100.0}){
    DateTime stopDate = datetimeStop ?? DateTime.now(); // first get the stop date
    
    /* create the transactions */
    List<BankTransaction> transactions = [];
    double endingCapital = sellingValue * super.initialValue; // establish the value of selling the bond with the value in percentage
    transactions.add(
      Income(IncomeCategory.financial_cashing, "Incasso capitale titolo ${super.name} dopo liquidazione anticipata con valore pari a ${sellingValue.toStringAsFixed(2)}%", endingCapital, stopDate)
    );

    super.stop(); // do the operation provided in the super stop method provided

    return transactions;
  } 

  /// Override of the method to reduce the amount of the initial value
  /// provided by the class [FinancialInstrument]
  @override
  List<BankTransaction> reduce(double amount, {DateTime? datetimeWithdraw, double sellingValue = 100.0}){
    DateTime reduceDate = datetimeWithdraw ?? DateTime.now(); // get the date

    /* then control if the amount to retire is available 
    from the value of the bond */
    if(amount > super.initialValue){
      throw Exception("Cannot reduce the bond of an amount which is not available in the initial value");
    }

    /* create the transactions */
    List<BankTransaction> transactions = [];
    double endingCapital = sellingValue * super.initialValue; // establish the value of selling the bond with the value in percentage
    transactions.add(
      Income(IncomeCategory.financial_cashing, "Riduzione capitale titolo ${super.name} dopo liquidazione anticipata con valore ${sellingValue.toStringAsFixed(2)}%", endingCapital, reduceDate)
    );

    super.reduce(amount); // call super method

    return transactions; // return the list of transactions
  }

  /// Method to generate a deep clone of the instance
  @override
  Bond clone(){
    return Bond(
      super.name,
      super.providerType,
      super.initialValue,
      super.taxRate,
      _timeInfo.startingDate,
      _timeInfo.timeFrequency,
      _timeInfo.dayOfMonth,
      _purchasePrice,
      _interestType,
      monthOfYear: _timeInfo.monthOfYear,
      includeStart: _timeInfo.includeStart,
      lastDateActivity: _timeInfo.lastDateActivity,
      includeEnd: _timeInfo.includeEnd,
      endingDate: _timeInfo.endingDate,
      id: super.id,
      provider: super.provider?.clone(),
      currentValue: super.currentValue,
      couponSchedule: couponSchedule,
      minimumDenomination: _minimumDenomination,
      instrumentUsed: super.instrumentModelName,
    );
  }

  /// Method to convert an object into a map for
  /// database manipulation
  @override
  Map<String, dynamic> toMap(){
    return {
      ...super.toMap(),
      'purchasePrice': _purchasePrice,
      'minimumDenomination': _minimumDenomination,
      'interestType': _interestType.index,
      ..._timeInfo.toMap()
    };
  }

  /// Factory method to transform a map object into an 
  /// instance of a bond
  /// * [map] map object from the database
  /// * [provider] optional provider of the bond service
  /// * [couponSchedule] schedule of coupons already converted from the database
  factory Bond.fromMap(Map<String, dynamic> map, FinancialInstitute? provider, List<StepInterest> couponSchedule){
    Map<String, dynamic> inputMap = Map<String, dynamic>.from(map);
    
    return Bond.withTimeInfo(
      inputMap.remove('name'),
      FinancialInstrumentProvider.values[inputMap.remove('providerType')],
      inputMap.remove('initialValue'),
      inputMap.remove('taxRate'),
      inputMap.remove('instrumentUsed'),
      inputMap.remove('purchasePrice'),
      BondType.values[inputMap.remove('interestType')],
      id: inputMap.remove('id'),
      provider: provider,
      currentValue: inputMap.remove('currentValue'),
      status: FinancialInstrumentStatus.values[inputMap.remove('status')],
      minimumDenomination: inputMap.remove('minimumDenomination'),
      couponSchedule: couponSchedule,
      LimitedAccountDuration.fromMap(inputMap)
    );
  }
}