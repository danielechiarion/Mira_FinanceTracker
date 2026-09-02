import 'package:meta/meta.dart';

import 'package:mira_finance_tracker/classes/subjects/FinancialInstitute.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/model/FinancialInstrumentModel.dart';

/// Enumerator to classify the status of a 
/// financial instrument, in order to use it better
/// during the manipulation inside the application
enum FinancialInstrumentStatus{
  ongoing, // going on regularly
  stopped, // all the sum has been withdrawn before the ending
  reduced, // the starting sum has been reduced before the ending
  ended // the financial instrument has ended its path
}

/// Class used to define a general financial 
/// instrument with its essential characteristics
abstract class FinancialInstrument {
  /* defining attributes */
  int _id;
  String _name;
  String? _instrumentUsed; // name of the instrument used
  FinancialInstrumentProvider _providerType; // if it's a public organization provider is not needeed
  FinancialInstitute? _provider;
  double _initialValue;
  double _currentValue;
  double _taxRate;
  FinancialInstrumentStatus _status;

  /// Constructor to define a financial instrument with all the necessary parameters
  /// * [_name] name of the financial instrument, which has to be unique
  /// * [_providerType] type of provider of the service (main difference is between public and private institution)
  /// * [_initialValue] initial value of the financial instrument
  /// * [_taxRate] tax rate applied to the interests earned
  /// * [_id] ID of the financial instrument mainly used by the database (if not set it's -1)
  /// * [_provider] information about the provider of the service (mandatory if it's a private institution)
  /// * [_currentValue] current value of the financial instrument with all the interest calculated so far
  /// * [_status] status of the financial instrument (ended, ongoing, stopped etc.)
  /// * [_instrumentUsed] name of the possible instrument model used for this service deployed
  FinancialInstrument(this._name, this._providerType, this._initialValue, this._taxRate,
    {this._id = -1, this._provider, this._instrumentUsed ,double? currentValue, FinancialInstrumentStatus? financialInstrumentStatus}):
    _currentValue = currentValue ?? _initialValue, _status = financialInstrumentStatus ?? FinancialInstrumentStatus.ongoing {
      if(_provider == null && _providerType == FinancialInstrumentProvider.financialInstitution){
        throw Exception("Every private institution has to be indicated with the provider information.");
      }

      if(_initialValue <= 0){
        throw Exception("Initial value of a financial instrument can't be zero or less");
      }

      if(_taxRate < 0){
        throw Exception("In a financial instrument tax rate can never be less than 0%");
      }
    }

  /* *** GETTER METHODS *** */
  int get id => _id;
  String get name => _name;
  String? get instrumentModelName => _instrumentUsed;
  FinancialInstrumentProvider get providerType => _providerType;
  FinancialInstitute? get provider => _provider;
  double get initialValue => _initialValue;
  double get currentValue => _currentValue;
  double get taxRate => _taxRate;
  FinancialInstrumentStatus get status => _status;
  bool get isActive {
    return _status != FinancialInstrumentStatus.ended && _status != FinancialInstrumentStatus.stopped;
  }

  /* *** SETTER METHODS *** */
  set id(int id) => _id = id;
  set providerType(FinancialInstrumentProvider providerType){
    if(providerType == FinancialInstrumentProvider.financialInstitution && _provider == null){
      throw Exception("Can't set a provider type to financial institution. Add a provider first");
    }
    _providerType = providerType;
  }
  set provider(FinancialInstitute provider) => _provider = provider;
  set taxRate(double taxRate) {
    if(taxRate < 0){
      throw Exception("In a financial instrument tax rate can never be less than 0%");
    }

    _taxRate = taxRate;
  }
  @protected
  set initialValue(double initialValue){
    if(initialValue < 0){
      throw Exception("In a financial instrument it's impossible to have an initial value which is <0");
    }

    _initialValue = initialValue;
  }
  @protected
  set currentValue(double currentValue){
    if(currentValue < 0){
      throw Exception("In a financial instrument it's impossible to have a current value which is <0");
    }

    _currentValue = currentValue;
  }

  /// Method to stop a financial instrument totally before 
  /// its expiration. 
  /// * [datetimeStop] date used to stop the financial service active
  dynamic stop({DateTime? datetimeStop}){
    /* set the necessary attributes */
    _status = FinancialInstrumentStatus.stopped;
  }

  /// Method to reduce a financial instrument when the 
  /// client needs to withdraw some money from it
  /// * [amount] amount to withdraw from the financial instrument
  /// * [datetimeWithdraw] optional date and time of the reduction
  dynamic reduce(double amount, {DateTime? datetimeWithdraw}){
    /* first control the value of the amount compared to the current value
    of the financial instrument:
    - if it's more it can't be possible
    - if it's equal the financial instrument has been stop
    - if it's less it's just a reduction of the value to invest */
    if(amount > _currentValue){
      throw Exception("When reducing a financial instrument the amount can't more than the current value");
    }else if(amount == _currentValue){
      datetimeWithdraw = datetimeWithdraw ?? DateTime.now();
      stop(datetimeStop: datetimeWithdraw);
    }else{
      _initialValue -= amount;
      _currentValue -= amount;
      _status = FinancialInstrumentStatus.reduced;
    }
  }

  /// Method to manage the end of a financial instrument
  /// that happened without stops before.
  /// If the ending date has been specified and the time has not come,
  /// the operation will be denied by the system.
  dynamic end(){
    /* update attributes */
    _status = FinancialInstrumentStatus.ended;
  }

  /// Equals method comparing the names of two services,
  /// which has to be unique inside the system
  /// [other] object to compare
  @override
  bool operator ==(Object other){
    return other is FinancialInstrument && other.runtimeType == runtimeType && _name == other._name;
  }

  /// Getter of the hashcode
  @override
  int get hashCode => _name.hashCode;

  /// Method to convert the object into a map
  /// used for database manipulation
  Map<String, dynamic> toMap(){
    return {
      if(_id >= 0) 'id': _id,
      'name': _name,
      'instrumentUsed': _instrumentUsed,
      'providerType': _providerType.index,
      if (_provider != null) 'provider': _provider!.id,
      'initialValue': _initialValue,
      'currentValue': _currentValue,
      'status': _status.index,
      'taxRate': _taxRate
    };
  }

  /// Method to clone the object into a new one
  /// with different references
  FinancialInstrument clone();
}