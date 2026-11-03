import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';
import 'package:mira_finance_tracker/classes/account/User.dart';

/// Class to handle database
/// opening and closing, making
/// it accessible for all the pages inside the application
class UserDatabaseHandler {
  /* make a public static attribute 
  make the database accessible for everyone */
  static UserDatabaseWrapper? database;

  /// Function to open and initialize a database
  /// for a specific [user] provided
  static Future<void> openDatabase(User user) async {
    /* if there was another database before,
    close completely it before creating a new one */
    if(database != null) {
      await database!.closeDatabase();
    }
    /* if the database for the user was already provided
    just end the function */
    else if(database!.user == user){
      return;
    }

    /* then open the new database and initialize it */
    database = UserDatabaseWrapper(user);
    await database!.init();
  }

  /// Function to close the database if it was opened
  /// before and close it definitely
  static Future<void> closeDatabase() async {
    /* if there is a database opened, close it */
    if(database != null) await database!.closeDatabase(); // since it was opened once, just close it
  }
}