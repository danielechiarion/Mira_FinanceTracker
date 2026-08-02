import 'package:mira_finance_tracker/backend/service/database/SystemDatabaseWrapper.dart';
import 'package:mira_finance_tracker/backend/service/CurrentSession.dart';
import 'package:mira_finance_tracker/classes/account/User.dart';

/// Class to handle the login operation
/// and let the user access correctly
class Login{
  /* attributes definition */
  String _username;
  String _password;

  /// Constructor used to define the login operation
  /// with the attributes needed
  /// * [_username] username of the account
  /// * [_password] password of the account
  Login(this._username, this._password);

  /// Function to execute the login operation
  /// returning if the login has been done successfully
  Future<bool> execute() async {
    /* pick up the system database
    to access to the accounts table */
    SystemDatabaseWrapper database = SystemDatabaseWrapper();
    await database.init();

    User? user = await database.userLogin(_username, _password, close: true);

    /* if the user is not null set 
    the current session with the necessary data */
    if(user != null){
      CurrentSession session = CurrentSession(user);
      await session.init();
    }

    return user != null;
  }
}