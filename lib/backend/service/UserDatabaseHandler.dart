import 'dart:async';

import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';
import 'package:mira_finance_tracker/classes/account/User.dart';

/// Class to handle database
/// opening and closing, making
/// it accessible for all the pages inside the application
class UserDatabaseHandler {
  /* make a public static attribute 
  make the database accessible for everyone   */
  static UserDatabaseWrapper? database;
  static Future<void> _operationQueue = Future<void>.value();

  /// Function to open and initialize a database
  /// for a specific [user] provided
  static Future<void> openDatabase(User user) {
    return _runSerialized(() async {
      final currentDatabase = database;

      /* if the database for the same user is already open,
      do not reopen it */
      if (currentDatabase != null &&
          currentDatabase.user == user &&
          currentDatabase.isDatabaseOpen) {
        return;
      }

      /* if there was another database before,
      close it completely before creating a new one */
      if (currentDatabase != null) {
        database = null;
        await currentDatabase.closeDatabase();
      }

      /* publish the connection only after initialization succeeds */
      final newDatabase = UserDatabaseWrapper(user);
      try {
        await newDatabase.init();
        database = newDatabase;
      } catch (_) {
        await newDatabase.closeDatabase();
        rethrow;
      }
    });
  }

  /// Function to close the database if it was opened
  /// before and close it definitely
  static Future<void> closeDatabase() {
    return _runSerialized(() async {
      final currentDatabase = database;
      if (currentDatabase == null) return;

      database = null;
      await currentDatabase.closeDatabase();
    });
  }

  static Future<void> _runSerialized(Future<void> Function() operation) async {
    final previousOperation = _operationQueue;
    final completion = Completer<void>();
    _operationQueue = completion.future;

    await previousOperation;
    try {
      await operation();
    } finally {
      completion.complete();
    }
  }
}
