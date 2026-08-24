import 'package:meta/meta.dart';

import 'package:mira_finance_tracker/classes/time_management/DurationType.dart';

/// Class used to manage periodic account duration
/// applied to fees, cashback and other financial instruments.
/// This means that the class is used for operation happening
/// at the same frequency which has no apparent expiration date. 
class PeriodicAccountDuration {
  /* attributes definition */
  DateTime _startingDate;
  bool _includeStart; // consider the beginning like a milestone
  DurationType _timeFrequency;
  int _dayOfMonth;
  int? _monthOfYear;
  DateTime? _lastDateActivity;

  /// Constructor of the periodic account duration class,
  /// which needs mandatory arguments like starting date, time frequency and day of month
  /// and optional ones like the month of the year and the including start flag
  /// * [_startingDate] day to star the periodic account duration
  /// * [_timeFrequency] frequency to consider for signal the periodic duration
  /// * [_dayOfMonth] day of the month to signal 
  /// * [_monthOfYear] month of the year to signal (if it's annual of more)
  /// * [_includeStart] flag to indicate if the start has to be signaled
  PeriodicAccountDuration(this._startingDate, this._timeFrequency, this._dayOfMonth, {this._monthOfYear, this._includeStart = false, this._lastDateActivity}){
    /* control the validity of the attributes given, 
    checking the month of the year, the day of the month */
    if(_monthOfYear == null && _timeFrequency.index > 4){
      throw Exception("Duration of a year or longer must have the month of year specified");
    }
    if(_dayOfMonth < 0 || _dayOfMonth > 31){
      throw Exception("Day of month value expressed is not valid");
    }
    if(_monthOfYear != null && (_monthOfYear! <0 || _monthOfYear! >12)){
      throw Exception("Month of year value expressed is not valid");
    }
    if(_timeFrequency == DurationType.atMaturity){
      throw Exception("Period account duration doesn't have an expiration date, so the signal cannot be sent at maturity");
    }
  }

  /* *** GETTER METHODS *** */
  DateTime get startingDate => _startingDate;
  DurationType get timeFrequency => _timeFrequency;
  int get dayOfMonth => _dayOfMonth;
  int? get monthOfYear => _monthOfYear;
  bool get includeStart => _includeStart;
  DateTime? get lastDateActivity => _lastDateActivity;

  /* *** SETTER METHODS *** */ 
  set dayOfMonth(int dayOfMonth){
    if(_dayOfMonth < 0 || _dayOfMonth > 31){
      throw Exception("Day of month value expressed is not valid");
    }

    _dayOfMonth = dayOfMonth;
  }

  set monthOfYear(int monthOfYear){
    if(_monthOfYear == null && _timeFrequency.index > 4){
      throw Exception("Duration of a year or longer must have the month of year specified");
    }
    if(_monthOfYear != null && (_monthOfYear! <0 || _monthOfYear! >12)){
      throw Exception("Month of year value expressed is not valid");
    }

    _monthOfYear = monthOfYear;
  }

  set includeStart(bool includeStart){
    if(_lastDateActivity != null){
      throw Exception("Cannot remove the starting flag because actions has already been done");
    }

    _includeStart = includeStart;
  }

  @protected
  set lastDateActivity(DateTime lastDateActivity) => _lastDateActivity = lastDateActivity;

  /// Method used to return is operations
  /// have already been started looking if a
  /// last date activity has been registered
  bool operationAlreadyStarted(){
    return _lastDateActivity != null;
  }

  /// Function to understand if it's time to
  /// signal the date
  bool isTime(){
    /* first control if the beginning is included 
    so as to signal it */
    if(_includeStart && _lastDateActivity == null){
      return true;
    }

    /* get the next signal date and the current signal date */
    DateTime signalDate = returnNextSignalDate();
    DateTime now = DateTime.now();  
    now = DateTime(now.year, now.month, now.day);

    /* the condition is valid only if the current date 
    corresponds or goes after the next signal date expected */
    return now.isAtSameMomentAs(signalDate) || now.isAfter(signalDate);
  }

  /// Acknowledge signal date 
  /// updating the last activity date 
  /// with the expected signal date
  void acknowledgeSignal(){
    if(_includeStart && _lastDateActivity == null){
      _lastDateActivity = _startingDate;
    }else{
      _lastDateActivity = returnNextSignalDate();
    }
  }

  /* function to return the next date to signal */
  DateTime returnNextSignalDate(){
    DateTime signalDate;
    DateTime lastDate = _lastDateActivity ?? _startingDate;
    /* then control if it's monthly or less than annual frequency
    and it's time to signal it */
    if(_timeFrequency.index < 5) {
      /* add to the last date the time frequency
      expressed */
      signalDate = DateTime(
        lastDate.year,
        lastDate.month + _timeFrequency.duration!.months,
        lastDate.day
      );
    }else{
      /* add to the last date the time frequency expressed */
      signalDate = DateTime(
        lastDate.year + _timeFrequency.duration!.years,
        lastDate.month + _timeFrequency.duration!.months,
        lastDate.day
      );

      /* if the month indicated is after the expressed one,
      try, add a year and move to the month specified */
      if(_monthOfYear! < signalDate.month){
        signalDate = DateTime(signalDate.year+1, _monthOfYear!);
      }
    }

    /* if the day of month comes before the signal date,
    go to the next month and move to the day specified */
    if(_dayOfMonth < signalDate.day){
      signalDate = DateTime(signalDate.year, signalDate.month + 1, _dayOfMonth);
    }
    
    return signalDate;
  }

  /// Function to return a map of the object
  /// for database manipulation
  Map<String, dynamic> toMap(){
    return {
      'startingDate': _startingDate.toIso8601String(),
      'includeStart': _includeStart ? 1 : 0,
      'timeFrequency': _timeFrequency.index,
      'dayOfMonth': _dayOfMonth,
      'monthOfYear': _monthOfYear,
      'lastDateActivity': _lastDateActivity?.toIso8601String()
    };
  }

  /// Method to convert a map object from the database
  /// into an object of the class for the application
  /// * [map] map object from the database
  factory PeriodicAccountDuration.fromMap(Map<String, dynamic> map){
    return PeriodicAccountDuration(
      DateTime.parse(map['startingDate']),
      DurationType.values[map['timeFrequency']],
      map['dayOfMonth'],
      monthOfYear: map['monthOfYear'],
      lastDateActivity: map['lastDateActivity'] == null ? null : DateTime.parse(map['lastDateActivity']),
      includeStart: map['includeStart'] == 1
    );
  }

  /// Method to get a deep clone of the instance
  PeriodicAccountDuration clone(){
    return PeriodicAccountDuration(_startingDate, _timeFrequency, _dayOfMonth, 
            monthOfYear: _monthOfYear, includeStart: _includeStart, lastDateActivity: _lastDateActivity);
  }
}