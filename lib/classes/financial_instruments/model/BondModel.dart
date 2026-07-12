import 'package:mira_finance_tracker/classes/financial_instruments/model/FinancialInstrumentModel.dart';
import 'package:mira_finance_tracker/classes/subjects/FinancialInstitute.dart';
import 'package:mira_finance_tracker/classes/time_management/LongDuration.dart';
import 'package:mira_finance_tracker/classes/time_management/DurationType.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/elements/StepInterest.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/elements/InterestList.dart';

/// Enumerator to distinguish different types 
/// of bond based on the interest rate to apply
enum BondType{
  /* enumerator values */
  fixed("Tasso fisso"),
  step("Tasso variabile programmato"),
  variable("Tasso variabile");
  
  /* attributes definition */
  final String name;

  /* constructor definition */
  const BondType(this.name);
}

/// Class to define a bond model supporting 
/// different types of it
class BondModel extends FinancialInstrumentModel implements InterestList{
  /* attributes definition */
  BondType _interestType;
  Set<StepInterest> _interests;

  /// Constructor for a bond model with all the necessary 
  /// data to build it the right way
  /// * [name] name of the financial instrument model
  /// * [providerType] type of provider of the service (mainly private or public)
  /// * [duration] duration of the financial instrument
  /// * [payoutFrequency] frequency of paying out the interests
  /// * [id] ID of the database for the model saved (it will be -1 at the beginning)
  /// * [description] optional description for the financial instrument
  /// * [provider] optional provider of the service (mandatory if it's a private one)
  /// * [taxRate] tax rate applied to the interests earned from the financial instrument
  /// * [_interestType] means which type of interest the model is based on
  /// * [_interests] list used both for variables and fixed interests
  BondModel(String name, FinancialInstrumentProvider providerType, LongDuration duration, DurationType payoutFrequency, this._interestType,
    {int id = -1, String? description, FinancialInstitute? provider, double taxRate = 0.0, Set<StepInterest>? interests}):
    _interests = interests ?? {},
    super(name, providerType, duration, payoutFrequency, id: id, description: description, provider: provider, taxRate: taxRate);

  /* *** GETTER METHODS *** */
  BondType get interestType => _interestType;
  List<StepInterest> get interests {
    List<StepInterest> cloneList = [];

    for(StepInterest singleInterest in _interests){
      cloneList.add(singleInterest.clone());
    }

    cloneList.sort(); // sort the list before returning it
    return cloneList;
  }

  /* *** SETTER METHODS *** */
  set interestType(BondType interestType) => _interestType = interestType;
  set interests(List<StepInterest> interests) => _interests = Set.from(interests);

  /* *** METHOD FOR INTEREST *** */
  /// Override of the method define in the [InterestList] interface
  @override
  int checkDurationValidity(){
    LongDuration sumDuration = LongDuration(); // create the long duration

    /* add the duration of each interest */
    for(StepInterest singleInterest in _interests){
      sumDuration = sumDuration.addDuration(singleInterest.duration);
    }

    return sumDuration.compareTo(super.duration); // compare the sum of durations with another duration
  }

  /// Override of the method define in the [InterestList] interface
  @override
  void addInterest(StepInterest interest, {bool checkDuration = false}) {
    _interests.add(interest); // add a new interest

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
    _interests.remove(interest);
  }
  
  /// Override of the method define in the [InterestList] interface
  @override
  void removeInterest(int position, {bool checkDuration = false}) {
    /* remove the interest */
    List<StepInterest> list = _interests.toList();
    StepInterest objectRemoved = list.removeAt(position);
    _interests = list.toSet();

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
    _interests.add(objectRemoved);
  }

  /// Override of the method define in the [InterestList] interface
  @override
  void replaceInterest(StepInterest interest, {int? position, bool checkDuration = false}){
    /* set the new position, if given,
    to place the new interest */
    if(position != null){
      interest.position = position;
    }

    /* replace the object */
    StepInterest objectRemoved = _interests.elementAt(interest.position);
    _interests.remove(objectRemoved);
    _interests.add(interest);

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
    _interests.remove(interest);
    _interests.add(objectRemoved);
  }

  /// Clone method returning a new instance of a bond model
  @override
  BondModel clone(){
    return BondModel(super.name, super.providerType, super.duration.clone(), super.payoutFrequency, _interestType, 
            id: super.id, description: super.description, provider: super.provider?.clone(), taxRate: super.taxRate, 
            interests: interests.toSet());
  }

  /// Method to return a map of the corresponding object
  /// for database manipulation
  @override
  Map<String, dynamic> toMap(){
    return {
      ...super.toMap(),
      'interestType': _interestType.index
    };
  }

  /// Function to get a bond model starting from 
  /// a map of the database
  /// * [map] map object of the database
  /// * [provider] optional provider of the time deposit
  /// * [interests] list of step interests of the bond
  factory BondModel.fromMap(Map<String, dynamic> map, FinancialInstitute? provider, Set<StepInterest> interests){
    return BondModel(
      map['name'],
      FinancialInstrumentProvider.values[map['providerType']],
      LongDuration.fromString('duration'),
      DurationType.values[map['payoutFrequency']],
      BondType.values[map['interestType']],
      id: map['id'],
      description: map['description'],
      provider: provider,
      taxRate: map['taxRate'],
      interests: interests
    );
  }
}