import 'package:flutter/foundation.dart';

import 'package:mira_finance_tracker/backend/service/database/SystemDatabaseWrapper.dart';
import 'package:mira_finance_tracker/classes/account/User.dart';

/// Class to manage operations like a super user
/// for the accounts registered inside the local application,
/// interfacing with the database.
class SuperAccountManager extends ChangeNotifier{
  /* define attributes */
  late Set<User> _users;
  late SystemDatabaseWrapper _database;

  /// Constructor to initialize the super
  /// account manager with its attributes
  SuperAccountManager() {
    _users = {};
    _database = SystemDatabaseWrapper();
  }

  /// Function to initialize the async components
  /// of the attributes
  Future<void> init() async {
    /* initialize the database 
    and recover the users to pass 
    to the set */
    await _database.init();
    _users = (await _database.userList()).toSet();
    notifyListeners(); // signal the change
  }

  /* *** GETTER METHODS *** */
  List<User> get users {
    List<User> output = [];
    for(User user in _users){
      output.add(user.clone());
    }
    return output;
  }

  /// Method to remove a user from the application
  /// updating list view and database
  Future<void> removeUser(User user) async {
    /* first control if the user 
    is inside the list */
    if(!_users.contains(user)){
      return;
    }

    /* otherwise remove from the database
    and the list and notify the change */
    await _database.removeUser(user);
    _users.remove(user);
    notifyListeners();
  }

  /// Method to change the password of a user
  /// updating the database and the list view
  /// * [user] the user to change the password
  /// * [newPassword] the new password to set
  Future<void> changePassword(User user, String newPassword) async {
    /* first control if the user exists,
    otherwise end the operation */
    if(!_users.contains(user)){
      return;
    }

    /* find the instance and change the password 
    in the database and in the list */
    User existingUser = _users.lookup(user)!;
    existingUser.password = newPassword;
    await _database.updateUser(existingUser);
  }

  /// Function to disconnect the resources connected
  /// to the super account manager before closing it
  Future<void> disconnect() async {
    await _database.closeDatabase();
  }
} 