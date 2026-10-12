import 'package:mira_finance_tracker/classes/account/User.dart';

import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';
import 'package:mira_finance_tracker/backend/service/session/CurrentSession.dart';
import 'package:mira_finance_tracker/backend/service/preference/UserPreferences.dart';

/// Class to handle correctly logout
/// operation when user goes out of the
/// application
class Logout{
  /* define attributes */
  User _user;

  /// Constructor for the logout 
  /// accepting the [_user]
  Logout(this._user); 

  /// Function to complete the whole procedure
  /// of logout for the user,
  /// erasing personal data shared in common memories
  Future<void> execute() async {
    /* first log out from the database
    which has not to be used again */
    UserDatabaseWrapper database = UserDatabaseWrapper(_user.clone());
    await database.init();
    await database.closeCompletelyDatabase();

    /* then get the current session 
    and erase the current user logged */
    CurrentSession session = (await CurrentSession.getFromMemory())!;
    await session.init();
    await session.disconnect();

    /* then erase from the current shared preferences
    the one of the user logged */
    UserPreferences preferences = UserPreferences(_user);
    await preferences.init();
    await preferences.disconnect();
  }
}