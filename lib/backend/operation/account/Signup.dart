import 'package:mira_finance_tracker/classes/account/User.dart';
import 'package:mira_finance_tracker/backend/service/KeyManager.dart';
import 'package:mira_finance_tracker/backend/service/database/SystemDatabaseWrapper.dart';

/// Class to manage the signup operation done
/// from the application interface. 
/// This setting adjusts even the cryptography settings 
/// of the database and the user preferences.
class Signup{
  /* define private attributes */
  User _user;
  String _passkey;

  /// Constructor of the signup operation
  /// with all the requested data
  Signup(this._user, this._passkey);

  /// Method to execute the whole signup procedure
  /// saving the user and generate the cryptography keys
  Future<void> execute() async {
    /* define the system database where
    to save the user data */
    SystemDatabaseWrapper database = SystemDatabaseWrapper();
    await database.init();
    await database.addUser(_user, close: true); // add the user to the database

    /* then define the key manager
    to generate the encryption keys for the user */
    KeyManager keyManager = KeyManager(user: _user, search: false);
    await keyManager.init();
    await keyManager.generateKeyFromPassword(_passkey);
    keyManager.clearSession(); // clear the session at the end
  }
}