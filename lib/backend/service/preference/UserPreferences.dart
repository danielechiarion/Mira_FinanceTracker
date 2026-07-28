import 'package:shared_preferences/shared_preferences.dart';

import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';
import 'package:mira_finance_tracker/backend/service/preference/SinglePreference.dart';
import 'package:mira_finance_tracker/classes/account/User.dart';

/// Class used to define user preferences 
/// to be saved, changed and then possibly exported.
/// When the account of the user is disconnected, the preferences
/// are saved inside the database and are removed from the shared preferences.
class UserPreferences{
  /* static attributes definition */
  static final String _KEYPREFIX = "userpreference_"; // prefix for values used only in shared preferences

  /* attributes definition */
  late Set<SinglePreference> _userPreferences;
  late final SharedPreferences _sharedPreferences;
  late User _user;

  /// Method to define user preferences,
  /// initializing them or just reading them from shared preferences.
  /// 
  /// CALL THE init() METHOD TO USE THE SHARED PREFERENCES CORRECTLY! 
  /// 
  /// * [_user] user owning the preferences
  /// * [preferences] optional list of preferences to give
  UserPreferences(this._user, {List<SinglePreference>? preferences}) :
    _userPreferences = preferences?.toSet() ?? {};

  /// Method that must be called to use the preferences.
  /// IF THIS METHOD IS NOT CALLED THE OTHER OPERATIONS WON'T WORK. 
  /// 
  /// * [readDatabase] flag to indicate if preferences has to be read from the database
  Future<void> init({bool readDatabase = false}) async {
    _sharedPreferences = await SharedPreferences.getInstance();

    if(readDatabase){
      _recoverFromDatabase();
    }
    else if(_keysRegistered()){
      _recoverFromSharedPreferences();
    }
    else{
       _giveDefaultValues();
    }
  }

  /* method to read the preferences from the database
  and add them to the object */
  Future<void> _recoverFromDatabase() async {
    /* create and instantiate the database
    to collect the preferences */
    UserDatabaseWrapper database = UserDatabaseWrapper(_user);
    await database.init();

    List<SinglePreference> result = await database.readUserPreferences(close: true);

    /* add them into the object with the 
    method created */
    for(SinglePreference preference in result){
      addPreference(preference);
    }
  }

  /* method to understand if the keys
  are registered inside the shared preferences */
  bool _keysRegistered(){
    final Set<String> keys = _sharedPreferences.getKeys();
    return keys.any((singleKey) => singleKey.startsWith(_KEYPREFIX));
  }

  /* function to recover the keys
  from the shared preferences */
  void _recoverFromSharedPreferences() {
    /* get all the keys startin with the prefix */
    final Set<String> keys = _sharedPreferences.getKeys();
    final List<String> fullKeys = keys.where((singleKey) => singleKey.startsWith(_KEYPREFIX)).toList();

    /* find for each key the corresponding value 
    and add them to the object */
    for(String singleKey in fullKeys){
      _userPreferences.add(SinglePreference.fromSharedPreference(singleKey, _sharedPreferences.get(singleKey).toString()));
    }
  }

  /* function to add default shared preferences
  with values at the beginning of the user creation */
  Future<void> _giveDefaultValues() async {
    /* add the values set for the 
    essential work of the application */
    addPreference(SinglePreference('enableBackground', true, currentValue: true)); // enable background activity
    addPreference(SinglePreference('enableNotifications', true, currentValue: true)); // enable notifications
    addPreference(SinglePreference('backupTime', false, currentValue: 1)); // express the time window to save for the backup (in years)
  }

  /* *** GETTER METHODS *** */
  List<SinglePreference> get userPreferences {
    List<SinglePreference> output = [];
    for(SinglePreference singlePreference in _userPreferences){
      output.add(singlePreference.clone());
    }
    return output;
  }

  /// Method to get the preference by its name
  SinglePreference getPreference(String name) {
    return _userPreferences.firstWhere((preference) => preference.name == name);
  }

  /// Method to add a user preference 
  /// inside the object and in the shared preferences
  Future<void> addPreference(SinglePreference preference) async {
    if(!_userPreferences.add(preference)){ // add the value in the set
      return;
    }
    
    /* then, if it's new, add the 
    object inside the shared preferences */
    MapEntry mapEntry = preference.toMapEntry(prefix: _KEYPREFIX);
    await _sharedPreferences.setString(mapEntry.key, mapEntry.value);
  }

  /// Method to update the preference and, in particular,
  /// its current value during the user session. 
  /// If the preference hasn't existed before, nothing will be done.
  Future<void> updatePreference(SinglePreference preference) async{
    if(!_userPreferences.contains(preference)){
      return;
    } 

    /* set the current value of the user preference */
    SinglePreference preferenceRegistered = _userPreferences.lookup(preference)!;
    preferenceRegistered.currentValue = preference.currentValue;
    /* save the preference inside the shared preferences */
    MapEntry mapEntry = preferenceRegistered.toMapEntry(prefix: _KEYPREFIX);
    await _sharedPreferences.setString(mapEntry.key, mapEntry.value);
  }

  /// Method to remove user preference.
  /// If the preference hasn't existed before,
  /// nothing will be done.   
  Future<void> removePreference(SinglePreference preference) async {
    _userPreferences.remove(preference); // remove from the set
    await _sharedPreferences.remove(preference.toMapEntry(prefix: _KEYPREFIX).key); // remove from shared preference
  }

  /// Method used when disconnecting the user
  /// to erase the preferences from the shared preferences common storage
  /// and saving them inside the database
  Future<void> disconnect() async {
    /* first find the keys and remove
    them from the shared preferences */
    final Set<String> keys = _sharedPreferences.getKeys();
    final List<String> fullKeys = keys.where((singleKey) => singleKey.startsWith(_KEYPREFIX)).toList();
    for(String singleKey in fullKeys){
      await _sharedPreferences.remove(singleKey);
    }

    /* then save the user preferences
    inside the database */
    UserDatabaseWrapper database = UserDatabaseWrapper(_user);
    database.saveUserPreferences(userPreferences);

    _userPreferences.clear(); // then clear the set to make the user unable to access to them anymore
  } 

  /// Method to export only the preferences
  /// that are not local and should be kept even in other applications
  Map<String, dynamic> exportPreferences(){
    Map<String, dynamic> export = {};
    for(SinglePreference preference in _userPreferences){
      if(preference.exportable){
        export.addAll({preference.name: preference.toMapEntry().value});
      }
    }

    return export;
  }

  /// Method to import exportable preferences
  /// from the map format
  /// * [import] list of keys and values to be converted
  Future<void> importPreferences(Map<String, dynamic> import) async {
    for(String singleKey in import.keys){
      SinglePreference newPreference = SinglePreference.fromSharedPreference(singleKey, import[singleKey]);
      /* with the new preference control 
      if it has to be updated or added as a new one */
      if(_userPreferences.contains(newPreference)){
        await updatePreference(newPreference);
      }else{
        await addPreference(newPreference);
      }
    }
  }
}