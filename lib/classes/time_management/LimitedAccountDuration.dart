import 'package:mira_finance_tracker/classes/time_management/PeriodicAccountDuration.dart';
import 'package:mira_finance_tracker/classes/time_management/DurationType.dart';
import 'package:mira_finance_tracker/classes/time_management/LongDuration.dart';

/// Class to manage an account duration like the 
/// PeriodicAccountDuration class,
/// with the different of an expiration date to handle
class LimitedAccountDuration extends PeriodicAccountDuration{
  /* attributes definition */
  late DateTime _endingDate;
  bool _includeEnd;

  /// Constructor of the Limited account duration 
  /// using the super constructor and adding the required attribute
  /// * [startingDate] day to star the periodic account duration
  /// * [timeFrequency] frequency to consider for signal the periodic duration
  /// * [dayOfMonth] day of the month to signal 
  /// * [monthOfYear] month of the year to signal (if it's annual of more)
  /// * [includeStart] flag to indicate if the start has to be signaled
  /// * [_endingDate] ending date of the total duration
  /// * [_includeEnd] flag if include end has to be signaled
  LimitedAccountDuration(DateTime startingDate, DurationType frequency, int dayOfMonth,
    {int? monthOfYear, bool includeStart = false, DateTime? lastDateActivity, 
    this._includeEnd = false, DateTime? endingDate, LongDuration? duration}) : 
    super(startingDate, frequency, dayOfMonth, monthOfYear: monthOfYear, includeStart: includeStart, lastDateActivity: lastDateActivity){
    /* first control if either the ending date of the duration
    has been given. It's not allowed both null values */
    if(duration == null && endingDate == null){
      throw Exception("In a limited account duration it's not allowed to have both duration and ending date null");
    }

    /* if the ending date is null,
    add to the starting date the duration provided */
    if(endingDate == null){
      _endingDate = DateTime(
        super.startingDate.year + duration!.years,
        super.startingDate.month + duration!.months,
        super.startingDate.day + duration!.days
      );
    }else{
      _endingDate = endingDate;
    }
    
    if(!_endingDate.isAfter(super.startingDate)){
      throw Exception("The ending date must be after the starting date");
    }
  }

  /* *** GETTER METHODS *** */
  DateTime get endingDate => _endingDate;
  bool get includeEnd => _includeEnd;

  /* *** SETTER METHODS *** */
  set endingDate(DateTime endingDate){
    if(!endingDate.isAfter(super.startingDate)){
      throw Exception("The ending date must be after the starting date");
    }
    if(super.lastDateActivity == null || super.lastDateActivity!.isAtSameMomentAs(endingDate)){
      throw Exception("Ending date cannot be changed because action has already been done");
    }

    _endingDate = endingDate;
  }

  set includeEnd(bool includeEnd){
    if(super.lastDateActivity == null || super.lastDateActivity!.isAtSameMomentAs(endingDate)){
      throw Exception("Ending date inclusion cannot be changed because action has already been done");
    }

    _includeEnd = includeEnd;
  }

  /// Function to understand if it's time to
  /// signal the date
  @override
  bool isTime(){
    /* first get the super result, 
    and return it if it's true */
    bool superResult = super.isTime();
    if(superResult){
      return true;
    }

    /* otherwise control if ending date is available
    and the current date passes it */
    if(_includeEnd && (super.lastDateActivity==null || super.lastDateActivity!.isBefore(endingDate)) && 
      DateTime.now().compareTo(endingDate)>=0){
      return true;
    }

    return false;
  }

  /// Acknowledge signal date 
  /// updating the last activity date 
  /// with the expected signal date
  @override
  void acknowledgeSignal(){
    if(super.lastDateActivity!.isAtSameMomentAs(_endingDate)){
      return;
    }
    else if(_includeEnd && super.returnNextSignalDate().isAfter(_endingDate)){
      super.lastDateActivity = _endingDate;
    }else{
      super.acknowledgeSignal();
    }
  }

  /// Function to return a map of the object
  /// for database manipulation
  @override
  Map<String, dynamic> toMap(){
    Map<String, dynamic> additionalMap = {
      'endingDate': _endingDate.toIso8601String(),
      'includeEnd': _includeEnd ? 1 : 0
    };
    return {...super.toMap(), ...additionalMap};
  }

  /// Method to convert a map object from the database
  /// into an object of the class for the application
  /// * [map] map object from the database
  factory LimitedAccountDuration.fromMap(Map<String, dynamic> map){
    return LimitedAccountDuration(
      map['startingDate'],
      DurationType.values[map['timeFrequency']],
      map['dayOfMonth'],
      endingDate: map['endingDate'],
      monthOfYear: map['monthOfYear'],
      lastDateActivity: map['lastDateActivity'],
      includeEnd: map['includeEnd'] == 1,
      includeStart: map['includeStart'] == 1
    );
  }

  /// Method to get a deep clone of the instance
  @override
  LimitedAccountDuration clone(){
    return LimitedAccountDuration(super.startingDate, super.timeFrequency, super.dayOfMonth, 
            monthOfYear: super.monthOfYear, includeStart: super.includeStart, lastDateActivity: super.lastDateActivity, 
            includeEnd: _includeEnd, endingDate: _endingDate);
  }
}