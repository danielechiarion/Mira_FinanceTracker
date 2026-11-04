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
    final currentDatabase = database;

    /* if the database for the same user is already open,
    do not reopen it */
    if (currentDatabase != null && currentDatabase.user == user) {
      return;
    }

    /* if there was another database before,
    close it completely before creating a new one */
    if (currentDatabase != null) {
      database = null;
      await currentDatabase.closeDatabase();
    }

    /* then open the new database and initialize it */
    database = UserDatabaseWrapper(user);
    await database!.init();
  }

  /// Function to close the database if it was opened
  /// before and close it definitely
  static Future<void> closeDatabase() async {
    final currentDatabase = database;
    if (currentDatabase == null) return;

    database = null;
    await currentDatabase.closeDatabase();
  }
}