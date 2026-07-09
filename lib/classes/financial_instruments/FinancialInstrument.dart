import 'package:mira_finance_tracker/classes/subjects/FinancialInstitute.dart';

/// Define enumerator to classify the financial instrument
/// by the provider offering the service
enum FinancialInstrumentProvider{
  financialInstitution("Istituto finanziaro"),
  publicInstitution("Istituzione pubblica");

  /* define constants */
  final String name;

  /* define constructor */
  const FinancialInstrumentProvider(this.name);
}

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
  String? _description;
  FinancialInstrumentProvider _providerType; // if it's a public organization provider is not needeed
  FinancialInstitute? _provider;
  DateTime _subscriptionDate;
  DateTime? _endingDate;
  double _initialValue;
  double _currentValue;
  FinancialInstrumentStatus _status;

  /// Constructor to define a financial instrument with all the necessary parameters
  /// * [_name] name of the financial instrument, which has to be unique
  /// * [_providerType] type of provider of the service (main difference is between public and private institution)
  /// * [_subscriptionDate] date of subscription of the service
  /// * [_initialValue] initial value of the financial instrument
  /// * [_id] ID of the financial instrument mainly used by the database (if not set it's -1)
  /// * [_description] optional description of the financial instrument 
  /// * [_provider] information about the provider of the service (mandatory if it's a private institution)
  /// * [_endingDate] optional attribute about a possible ending date of the financial instrument (not all them will need it)
  /// * [_currentValue] current value of the financial instrument with all the interest calculated so far
  /// * [_status] status of the financial instrument (ended, ongoing, stopped etc.)
  FinancialInstrument(this._name, this._providerType, this._subscriptionDate, this._initialValue,
    {this._id = -1, this._description, this._provider, this._endingDate, double? currentValue, FinancialInstrumentStatus? financialInstrumentStatus}):
    _currentValue = currentValue ?? _initialValue, _status = financialInstrumentStatus ?? FinancialInstrumentStatus.ongoing {
      if(_provider == null && _providerType == FinancialInstrumentProvider.financialInstitution){
        throw Exception("Every private institution has to be indicated with the provider information.");
      }

      if(_endingDate != null && _endingDate!.isBefore(_subscriptionDate)){
        throw Exception("Ending date of a financial instrument can't come before the subscription date");
      }

      if(_initialValue <= 0){
        throw Exception("Initial value of a financial instrument can't be zero or less");
      }
    }

  /* *** GETTER METHODS *** */
  String get name => _name;
  String? get description => _description;
  FinancialInstrumentProvider get providerType => _providerType;
  FinancialInstitute? get provider => _provider;
  DateTime get subscriptionDate => _subscriptionDate;
  DateTime? get endingDate => _endingDate;
  double get initialValue => _initialValue;
  double get currentValue => _currentValue;
  FinancialInstrumentStatus get status => _status;

  /* *** SETTER METHODS *** */
  set description(String description) => _description = description;
  set id(int id) => _id = id;
  set providerType(FinancialInstrumentProvider providerType){
    if(providerType == FinancialInstrumentProvider.financialInstitution && _provider == null){
      throw Exception("Can't set a provider type to financial institution. Add a provider first");
    }
    _providerType = providerType;
  }
  set provider(FinancialInstitute provider) => _provider = provider;

  /// Method to stop a financial instrument totally before 
  /// its expiration. 
  /// * [datetimeStop] date used to stop the financial service active
  dynamic stop({DateTime? datetimeStop}){
    datetimeStop = datetimeStop ?? DateTime.now(); // set the datetime if not done before

    /* control if the the datetime given comes
    after the subscription date, otherwise it's not 
    possible to continue */
    if(datetimeStop.isBefore(_subscriptionDate)){
      throw Exception("When stopping a financial instrument ending date can't come before the subscription date");
    }

    /* set the necessary attributes */
    _endingDate = datetimeStop;
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
      _status = FinancialInstrumentStatus.reduced;
    }
  }

  /// Method to manage the end of a financial instrument
  /// that happened without stops before.
  /// If the ending date has been specified and the time has not come,
  /// the operation will be denied by the system.
  dynamic end(){
    /* first control if the ending date has been specified. 
    In that case the operation of stopping the service has to come after or 
    at the sime time of the ending date specified */
    if(_endingDate!=null && DateTime.now().isBefore(_endingDate!)){
      throw Exception("Ending date specified in the financial instrument has not come. Ending operation denied.");
    }

    /* update attributes */
    _endingDate = _endingDate ?? DateTime.now();
    _status = FinancialInstrumentStatus.ended;
  }

  /// Equals method comparing the names of two services,
  /// which has to be unique inside the system
  /// [other] object to compare
  @override
  bool operator ==(Object other){
    return other is FinancialInstrument && _name == other._name;
  }

  /// Getter of the hashcode
  @override
  int get hashCode => _name.hashCode;

  Map<String, dynamic> toMap(){
    return {
      if(_id >= 0) 'id': _id,
      'name': _name,
      'description': _description,
      'providerType': _providerType.index,
      if (_provider != null) 'provider': _provider!.id,
      // serialize dates as ISO strings (or use millisecondsSinceEpoch if preferred)
      'subscriptionDate': _subscriptionDate.toIso8601String(),
      'endingDate': _endingDate?.toIso8601String(),
      'initialValue': _initialValue,
      'currentValue': _currentValue,
      'status': _status.index
    };
  }
}