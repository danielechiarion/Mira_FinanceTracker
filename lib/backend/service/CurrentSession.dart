import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mira_finance_tracker/classes/account/User.dart';

/// Class used to save information 
/// about the current session of the user
/// in order to control multiple access to the same resources,
/// even in a possible backup on cloud situation.
class CurrentSession{
  /* define prefix for the attributes to save
  inside the flutter secure storage or the shared preferences */
  static final String _SECURESTORAGEPREFIX = "currentsession_";
  static final String _SHAREDPREFERENCEPREFIX = "currentsession_";

  /* define static attribute to access to
  flutter secure storage in order to get the necessary information */
  static final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  static late SharedPreferences _sharedPreferences;

  /* define private attributes */
  User _user;
  late String _os;
  late String? _deviceName;
  late String? _deviceModel;
  late DateTime _accessTime;

  /// Constructor of the current session with all the
  /// necessary data to use in this instance
  /// * [_user] user who accesses the application
  /// * [accessTime] possible date of access given
  CurrentSession(this._user, {DateTime? accessTime}) {
    _accessTime = accessTime ?? DateTime.now(); // set the access time if not given
  }

  /// Function to init functionalities of the current
  /// session that are async and recover resources 
  /// from the system to proceed
  Future<void> init() async{
    _sharedPreferences = await SharedPreferences.getInstance(); // get the shared preferences instance

    await _saveInformation(); // save information inside the storages

    /* understand how to get system information
    based on the os where the application is executed.
    But do this operation only if the device still doesn't have the 
    system information */
    if(_hasSystemInfo()){
      _setSystemInformation(); // set system information
      return;
    }

    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if(Platform.isAndroid){
      _os = "Android"; // set the os
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      _deviceName = androidInfo.host;
      _deviceModel = androidInfo.model;
    }else if(Platform.isIOS){
      _os = "iOS";
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      _deviceName = iosInfo.name;
      _deviceModel = iosInfo.model;
    }else if(Platform.isWindows){
      _os = "Windows";
      WindowsDeviceInfo windowsInfo = await deviceInfo.windowsInfo;
      _deviceName = windowsInfo.computerName;
      _deviceModel = null;
    }else if(Platform.isMacOS){
      _os = "MacOS";
      MacOsDeviceInfo macInfo = await deviceInfo.macOsInfo;
      _deviceName = macInfo.computerName;
      _deviceModel = macInfo.model;
    }else if(Platform.isLinux){
      _os = "Linux";
      _deviceModel = null;
      _deviceName = null;
    }

    await _saveSystemInformation(); // save the system information inside the shared preferences
  }

  /* function to understand if the application
  has the right system information to save
  the current session */
  bool _hasSystemInfo() {
    return _sharedPreferences.containsKey( '${_SHAREDPREFERENCEPREFIX}deviceName');
  }

  /* function to save information inside 
  the flutter secure storage
  and shared preferences provided by flutter */
  Future<void> _saveInformation() async {
    await _secureStorage.write(key: '${_SECURESTORAGEPREFIX}user', value: jsonEncode(_user.toMap())); // save the user in the secure storage
    await _sharedPreferences.setString('${_SHAREDPREFERENCEPREFIX}accessTime', _accessTime.toIso8601String());
  }

  /* function to save system information
  inside the shared preferences */
  Future<void> _saveSystemInformation() async {
     /* now save other data into 
    shared preferences */
    await _sharedPreferences.setString('${_SHAREDPREFERENCEPREFIX}deviceName', _deviceName ?? '');
    await _sharedPreferences.setString('${_SHAREDPREFERENCEPREFIX}deviceModel', _deviceModel ?? '');
    await _sharedPreferences.setString('${_SHAREDPREFERENCEPREFIX}os', _os);
  }

  /* function to set system information. 
  Use only after the confirm the applicatio
  has system information */
  void _setSystemInformation() {
    /* then set the attributes of the user */
    _os = _sharedPreferences.getString('${_SHAREDPREFERENCEPREFIX}os')!;
    _deviceName = _sharedPreferences.getString('${_SHAREDPREFERENCEPREFIX}deviceName')!;
    _deviceModel = _sharedPreferences.getString('${_SHAREDPREFERENCEPREFIX}deviceModel')!;
  }

  /// Function to return the current session from
  /// the flutter storages where the attributes where saved
  static Future<CurrentSession?> getFromMemory() async {
    // ensure shared preferences instance is available
    _sharedPreferences = await SharedPreferences.getInstance();

    /* first understand if the user has
    been registered, otherwise return a null */
    if (!(await _secureStorage.containsKey(key: '${_SECURESTORAGEPREFIX}user'))) {
      return null;
    }

    /* get the user and datetime from the storages 
    to build the constructor */
    String? userValue = await _secureStorage.read(key: '${_SECURESTORAGEPREFIX}user');
    if (userValue == null) {
      return null;
    }
    User user = User.fromMap(jsonDecode(userValue));

    String? accessTimeStr = _sharedPreferences.getString('${_SHAREDPREFERENCEPREFIX}accessTime');
    if (accessTimeStr == null) {
      return null;
    }
    DateTime accessTime = DateTime.parse(accessTimeStr);
    CurrentSession session = CurrentSession(user, accessTime: accessTime);

    /* then set the attributes of the user */
    session._os = _sharedPreferences.getString('${_SHAREDPREFERENCEPREFIX}os') ?? '';
    session._deviceName = _sharedPreferences.getString('${_SHAREDPREFERENCEPREFIX}deviceName') ?? '';
    session._deviceModel = _sharedPreferences.getString('${_SHAREDPREFERENCEPREFIX}deviceModel') ?? '';

    return session;
  }

  /* *** GETTER METHODS *** */
  User get user => _user;

  /// Function to compare two sessions based on the 
  /// user logged and the device name
  @override
  bool operator ==(Object other){
    return other is CurrentSession && other._user == _user && other._deviceName == _deviceName;
  }

  /// Getter of the hashCode
  @override
  int get hashCode => Object.hash(_user, _deviceName);

  /// Function to map an object of current session
  /// into a map for file saving
  Map<String, dynamic> toMap(){
    return {
      'user': _user.toMap(),
      'os': _os,
      'deviceModel': _deviceModel,
      'deviceName': _deviceName,
      'accessTime': _accessTime.toIso8601String()
    };
  }

  /// Function to convert a map object from a file
  /// into the an instance of current session
  /// * [map] map object to convert
  factory CurrentSession.fromMap(Map<String, dynamic> map){
    CurrentSession session = CurrentSession(User.fromMap(map['user']), accessTime: DateTime.parse(map['accessTime']));
    session._deviceModel = map['deviceModel'];
    session._deviceName = map['deviceName'];
    session._os = map['os'];

    return session;
  }

  /// Method to understand from a content of a file 
  /// to find if a common resource is busy because
  /// another software instance is using it
  /// * [map] map of the session which controls the resource
  bool isBusy(Map<String, dynamic> map){
    CurrentSession sessionRegistered = CurrentSession.fromMap(map); // get the session registered

    return sessionRegistered != this; // compare if the two session are equal, otherwise it means the channel is busy
  }

  /// Function to remove the data after 
  /// the end of the session 
  Future<void> disconnect() async {
    /* delete only the information
    connected to the single user */
    await _secureStorage.delete(key: '${_SECURESTORAGEPREFIX}user');
    await _sharedPreferences.remove('${_SHAREDPREFERENCEPREFIX}accessTime');
  }
}