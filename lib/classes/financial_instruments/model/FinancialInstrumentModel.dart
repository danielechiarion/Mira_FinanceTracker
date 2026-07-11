import 'package:meta/meta.dart';

import 'package:mira_finance_tracker/classes/subjects/FinancialInstitute.dart';
import 'package:mira_finance_tracker/classes/time_management/LongDuration.dart';
import 'package:mira_finance_tracker/classes/time_management/DurationType.dart';

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

/// Class to define a saved model of financial instrument, 
/// with the tax rate, interest rate and time needed
abstract class FinancialInstrumentModel{
  /* attributes definition */
  int _id;
  String _name;
  String? _description;
  FinancialInstrumentProvider _providerType;
  FinancialInstitute? _provider;
  double _taxRate;
  LongDuration _duration;
  DurationType _payoutFrequency;

  /// Constructor for a financial instrument model with all the necessary 
  /// data to build it the right way
  /// * [_name] name of the financial instrument model
  /// * [_providerType] type of provider of the service (mainly private or public)
  /// * [_duration] duration of the financial instrument
  /// * [_payoutFrequency] frequency of paying out the interests
  /// * [_id] ID of the database for the model saved (it will be -1 at the beginning)
  /// * [_description] optional description for the financial instrument
  /// * [_provider] optional provider of the service (mandatory if it's a private one)
  /// * [_taxRate] tax rate applied to the interests earned from the financial instrument
  FinancialInstrumentModel(this._name, this._providerType, this._duration, this._payoutFrequency, 
    {this._id = -1, this._description, this._provider, this._taxRate = 0.0}) {
    /* control the attributes provided */
    if(_provider == null && _providerType == FinancialInstrumentProvider.financialInstitution){
      throw Exception("Every private institution has to be indicated with the provider information.");
    }

    if(_taxRate < 0){
      throw Exception("In a financial instrument tax rate can never be less than 0%");
    }
  }

  /* *** GETTER METHODS *** */
  @protected
  int get id => _id;
  String get name => _name;
  String? get description => _description;
  FinancialInstrumentProvider get providerType => _providerType;
  FinancialInstitute? get provider => _provider?.clone();
  double get taxRate => _taxRate;
  LongDuration get duration => _duration.clone();
  DurationType get payoutFrequency => _payoutFrequency;

  /* *** SETTER METHODS *** */
  set id(int id) => _id = id;
  set description(String description) => _description = description;
  set taxRate(double _taxRate) {
    if(taxRate < 0){
      throw Exception("In a financial instrument tax rate can never be less than 0%");
    }

    _taxRate = taxRate;
  }
  set duration(LongDuration duration) => _duration = duration;
  set payoutFrequency(DurationType payoutFrequency) => _payoutFrequency = payoutFrequency;

  /// Equals method comparing the names of two services models,
  /// which has to be unique inside the system
  /// [other] object to compare
  @override
  bool operator ==(Object other){
    return other is FinancialInstrumentModel && _name == other._name;
  }

  /// Getter of the hashcode
  @override
  int get hashCode => _name.hashCode;

  
  /// Method to convert a financial instrument model 
  /// in a map for database manipulation
  Map<String, dynamic> toMap(){
    return {
      if(_id >= 0) 'id': _id,
      'name': _name,
      'description': _description,
      'providerType': _providerType.index,
      'provider': _provider?.id,
      'taxRate': _taxRate,
      'duration': _duration.toString(),
      'payoutFrequency': _payoutFrequency.index
    };
  }

  /// Method to get a deep clone of the instance
  FinancialInstrumentModel clone();
}