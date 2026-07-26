import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:bcrypt/bcrypt.dart';

import 'package:mira_finance_tracker/backend/service/database/EncryptedDatabase.dart';
import 'package:mira_finance_tracker/backend/service/KeyManager.dart';
import 'package:mira_finance_tracker/backend/service/database/SystemDatabaseWrapper.dart';

import 'package:mira_finance_tracker/classes/account/User.dart';

/// Class to handle personal database belonging to 
/// the user registered inside the application. 
/// Extending class of [SystemDatabaseWrapper].
class UserDatabaseWrapper extends SystemDatabaseWrapper{
  /* define attributes */
  User _user;
  
  /// Constructor of the user database wrapper 
  /// starting from user information 
  /// * [user] user owner of the database
  UserDatabaseWrapper(User user): _user = user,
    super(keyManagerInput: KeyManager(user: user, search: false));

  /// Function to initialize the database 
  /// defining the tables. 
  /// Defining also the system database if it has not done before. 
  @override
  Future<void> init() async {
    super.init(); // first start to initialize the system database
    /* then try to add the user, 
    if it has not been done before */
    try{
      await super.addUser(_user);
    }on Exception{
    }finally{
      await database.close(); // close system database after finishing operations
    }
  }
}