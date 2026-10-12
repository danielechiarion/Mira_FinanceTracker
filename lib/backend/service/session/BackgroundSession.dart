import 'package:mira_finance_tracker/classes/account/User.dart';
import 'package:mira_finance_tracker/backend/service/session/CurrentSession.dart';

/// Class to manage background session with data about 
/// starting and ending time using extending [CurrentSession] class
class BackgroundSession extends CurrentSession {
  /* define attributes for current session */
  late DateTime? _endingTime;

  /// Constructor of the background session 
  /// to initialize the superclass
  BackgroundSession(User user, {DateTime? accessTime}): super(user, accessTime: accessTime);

  /// Function to initialize resources available
  /// inside class and superclass
  @override
  Future<void> init() async {
    await super.init();
  }

  /// Function to change attribute if the session is finished
  void endSession(){
    _endingTime = DateTime.now();
  }

  /// Function that compares current background session
  /// with another one and decides if it's time to 
  /// take control of the background operations or not
  @override
  bool isBusy(Map<String, dynamic> map){
    BackgroundSession another = BackgroundSession.fromMap(map); // convert the map to a background session object
    if(this == another) return true; // if the two sessions are equal it must be time

    /* if the other session is not finished but the starting time
    has been registered more than 30 mins ago, return true */
    DateTime currentDate = DateTime.now();
    if(another._endingTime == null && currentDate.difference(another.accessTime) > Duration(minutes: 30)) return true;

    /* if the other session is finished and more than 20 hours has passed from last control, 
    return true and let the background execute */
    if(another._endingTime != null && currentDate.difference(another._endingTime!) > Duration(hours: 20)) return true;

    return false; // otherwise return false
  }

  /// Function to convert an object to a map 
  /// overriding the one provided in [CurrentSession]
  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      if(_endingTime != null) 'endingTime': _endingTime!.toIso8601String()
    };
  }

  factory BackgroundSession.fromMap(Map<String, dynamic> map){
    BackgroundSession session = BackgroundSession(User.fromMap(map['user']), accessTime: DateTime.parse(map['accessTime']));
    session.deviceModel = map['deviceModel'];
    session.deviceName = map['deviceName'];
    session.os = map['os'];
    session._endingTime = map.containsKey('endingTime') ? map['endingTime'] : null;

    return session;
  }
}