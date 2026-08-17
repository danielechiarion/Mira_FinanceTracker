import 'package:mira_finance_tracker/classes/account/User.dart';
import 'package:mira_finance_tracker/backend/service/database/SystemDatabaseWrapper.dart';

/// Class to save the changes
/// made to user attributes and save it into the database
class ProfileChanges{
  /* define attributes */
  User _user;
  SystemDatabaseWrapper _database;
  
  /// Constructor of the profile changes 
  /// having the [_user] as the obly parameter necessary
  ProfileChanges(this._user) : _database = SystemDatabaseWrapper();

  /// Method to init all the attributes inside the 
  /// instance using async calls
  Future<void> init() async {
    await _database.init();
  }

  /// Method to change [name] and [surname] of the user
  /// and saving it inside the database
  Future<void> changeUserNameSurname(String name, String surname) async {
    /* update the attributes value */
    _user.name = name;
    _user.surname = surname;

    await _database.updateUser(_user.clone());
  }

  /// Function to change the user password considering also
  /// the old one, that has to be correct
  /// * [oldPassword] previous password to be changed
  /// * [newPassword] password to set
  /// Returns a boolean to indicate if the password has changed or the 
  /// control with the old one was not correct
  Future<bool> changeUserPassword(String oldPassword, String newPassword) async {
    try{
      _user.setPassword(oldPassword, newPassword); // try to set the new password
    }on Exception {
      return false;
    }

    await _database.updateUser(_user); // update user in the database
    return true;
  }

  /// Function to disconnect from the current
  /// resources opened by the instance
  Future<void> disconnect() async {
    await _database.closeDatabase(); // the only function to call is to close the database
  }
}