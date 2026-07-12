import 'package:mira_finance_tracker/classes/time_management/LongDuration.dart';

/// Class to define a step interest,
/// so an interest that could change over time in the
/// investment, but that was already plan before the subscription of the
/// financial instrument
class StepInterest implements Comparable<StepInterest>{
  /* attributes definition */
  int _position; // position inside the list of step interests
  LongDuration _duration;
  double _interestRate;

  /// Constructor to define a step interest, 
  /// that could be step up or step down
  /// * [_position] position of the step interest inside a list
  /// * [_duration] duration of the step interest validty
  /// * [_interestRate] annual interest rate
  StepInterest(this._position, this._duration, this._interestRate){
    /* check the validity of the attributes */
    if(_position < 0){
      throw Exception("In a step interest the position index can't be less than 0");
    }
    if(_interestRate <= 0){
      throw Exception("In a step interest the interest rate has to be more than 0%");
    }
  }

  /* *** GETTER METHODS *** */
  int get position => _position;
  LongDuration get duration => _duration.clone();
  double get interestRate => _interestRate;

  /* *** SETTER METHODS *** */
  set position(int position){
    if(position < 0){
      throw Exception("In a step interest the position index can't be less than 0");
    }

    _position = position;
  }
  set duration(LongDuration duration) => _duration;
  set interestRate(double interestRate){
    if(interestRate <= 0){
      throw Exception("In a step interest the interest rate has to be more than 0%");
    }

    _interestRate = interestRate;
  }

  /// Method to get the exact interest rate
  /// knowing the annual one and the duration of the step interest
  double getExactInterestRate(){
    /* first get the duration in years */
    double durationInYears = duration.years + 
                             (duration.months / 12.0) + 
                             (duration.days / 365.0);

    /* than get the exact interest rate 
    multiplying the attribute with the duration in years calculated */
    return _interestRate * durationInYears;
  }

  /// Operator == comparing two step interests by the position they have.
  /// It's not a universal comparison, but it has to be done inside the same list. 
  @override
  bool operator ==(Object other){
    return other is StepInterest && other._position == _position;
  }

  /// Getter of the hascode
  @override
  int get hashCode => _position.hashCode;

  /// Method to convert an object of the step interest into 
  /// a map for database manipulation
  Map<String, dynamic> toMap(){
    return {
      'position': _position,
      'duration': _duration.toString(),
      'interestRate': _interestRate
    };
  }

  /// Method to convert the map object into a
  /// step interest for the application
  factory StepInterest.fromMap(Map<String, dynamic> map){
    return StepInterest(
      map['position'], 
      LongDuration.fromString(map['duration']), 
      map['interestRate']
    );
  }

  /// Method to get a deep clone of the instance
  StepInterest clone(){
    return StepInterest(_position, _duration.clone(), _interestRate);
  }

  /// Create compareTo method to order the step interests
  /// based on their position
  @override
  int compareTo(StepInterest other){
    return _position.compareTo(other._position);
  }
}