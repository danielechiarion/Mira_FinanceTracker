import 'package:mira_finance_tracker/classes/account/User.dart';

import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';
import 'package:mira_finance_tracker/backend/service/session/CurrentSession.dart';
import 'package:mira_finance_tracker/backend/service/preference/UserPreferences.dart';

import 'package:mira_finance_tracker/backend/cloud/operation/CloudFileExport.dart';
import 'package:mira_finance_tracker/frontend/error_pages/ErrorManager.dart';

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
  Future<bool> execute() async {
    /* then get the current session 
    and erase the current user logged */
    CurrentSession session = (await CurrentSession.getFromMemory())!;
    await session.init();

    /* when session has been initialized, 
    start the export operation */
    CloudFileExport exporter = CloudFileExport(session, showErrorFunction: ErrorManager.redirectToErrorPageExport);
    var exportSucceeded = false;
    try {
      await exporter.init();
      exportSucceeded = await exporter.execute();
    } finally {
      await exporter.dispose();
    }
    if (!exportSucceeded) return false;

    await session.disconnect(); // then disconnect from the session

    /* then erase from the current shared preferences
    the one of the user logged */
    UserPreferences preferences = UserPreferences(_user);
    await preferences.init();

    /* only when the cloud operation has been finished close 
    completely the database */
    UserDatabaseWrapper database = UserDatabaseWrapper(_user.clone());
    await database.init();
    await database.closeCompletelyDatabase();
    return true;
  }
}
