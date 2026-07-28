import 'dart:convert';

/// Class used to manage a single preference
/// that can be customized and changed by the user
/// and managed into the shared preferences.
/// Make sure it's a primitive type to avoid problems.
class SinglePreference{
  /* define attributes */
  String _preferenceName;
  dynamic _currentValue;
  dynamic _defaultValue;
  bool _local;

  /// Create constructor of the single preference
  /// * [_preferenceName] unique name to identify the preference
  /// * [_currentValue] current value of the preference (could be anything, also null at the beginning)
  /// * [_defaultValue] default value of the preference, as a reference point for future changes
  /// * [_local] flag to indicate if the attribute is local and has to be kept in the application or it can be exported
  SinglePreference(this._preferenceName, this._local, {this._currentValue, this._defaultValue}){
    /* if the current value is not primitive 
    throw Exception */
    if(_currentValue != null && _defaultValue != null && _currentValue.runtimeType != _defaultValue.runtimeType){
      throw Exception("Current value must have the same of value of the default one in a shared preference");
    }
    if(_currentValue != null && !_isPrimitive(_currentValue)){
      throw Exception("The value saved in the single preference must be primitive");
    }

    /* if default value is not set 
    give it the current value */
    _defaultValue = _defaultValue ?? _currentValue;
  }

  /* *** GETTER METHODS *** */
  String get name => _preferenceName;
  dynamic get currentValue => _currentValue;
  dynamic get defaultValue => _defaultValue;
  bool get exportable => !_local;

  /* *** SETTER METHODS *** */
  set currentValue(dynamic value){
    /* make controls on the new value */
    if(value != null && _defaultValue != null && value.runtimeType != _defaultValue.runtimeType){
      throw Exception("Current value must have the same of value of the default one in a shared preference");
    }
    if(value != null && !_isPrimitive(value)){
      throw Exception("The value saved in the single preference must be primitive");
    }

    _currentValue = value;
    _defaultValue = _defaultValue ?? value;
  }

  /// Create the operator to compare different
  /// single preferences by the name
  @override
  bool operator ==(Object other){
    return other is SinglePreference && other._preferenceName == _preferenceName;
  }

  /// getter for the hascode
  @override
  int get hashCode => _preferenceName.hashCode;

  /// Function to convert the content of a
  /// single preference into a string
  /// for saving it inside the shared preference
  @override
  String toString(){
    return jsonEncode(
      {
        'defaultValue': _defaultValue,
        'currentValue': _currentValue,
        'local': _local
      }
    );
  }

  /// Function to convert the single preference
  /// in a map entry with its key and value
  /// ready to be saved inside a shared preference
  MapEntry<String, String> toMapEntry({String prefix = ''}){
    return MapEntry(_preferenceName, '$prefix${toString()}');
  }

  /// Method to convert the key and the value saved 
  /// in the shared preference into a single preference object
  factory SinglePreference.fromSharedPreference(String key, String value, {String prefix = ''}){
    Map<String, dynamic> map = jsonDecode(value);
    return SinglePreference(
      key.replaceFirst(prefix, ''), // the name of the preference should not have the prefix imposed
      map['local'], 
      currentValue: map['currentValue'], 
      defaultValue: map['defaultValue']
    );
  }

  /// Method to make a deep clone
  /// of the single preference object
  SinglePreference clone(){
    return SinglePreference(_preferenceName, _local, currentValue: _currentValue, defaultValue: _defaultValue);
  }

  /* method to understand if the value is primitive */
  bool _isPrimitive(dynamic value){
    return value is num || value is bool || value is String;
  }
}