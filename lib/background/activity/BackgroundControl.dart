import 'package:mira_finance_tracker/classes/account/User.dart';

import 'package:mira_finance_tracker/backend/service/database/SystemDatabaseWrapper.dart';
import 'package:mira_finance_tracker/backend/service/notification/NotificationManager.dart';

import 'package:mira_finance_tracker/background/activity/UserBackgroundCheck.dart';

/// Class to handle general background control
/// inside each user registered in the application
class BackgroundControl {
  /* define attributes */
  SystemDatabaseWrapper _database;
  NotificationManager _notificationManager;

  /// Constructor of the background control 
  /// to define the resources needed
  BackgroundControl({
    SystemDatabaseWrapper? database,
    NotificationManager? notificationManager
  }) : _database = database ?? SystemDatabaseWrapper(), _notificationManager = notificationManager ?? NotificationManager();

  /// Function to initialize the resources needed 
  /// to build up the background control
  Future<void> init() async {
    await _database.init();
    await _notificationManager.initialize();
  }

  /// Function to execute all the background
  /// control operations needed 
  Future<void> execute() async {
    List<User> users = await _database.userList(); // get the users

    /* create the instance for each user,
    pass the arguments and execute it */
    for(User user in users){
      UserBackgroundCheck operations = UserBackgroundCheck(user, _notificationManager);
      await operations.init();
      await operations.execute();
    }

    /* then dispose all the necessary resources */
    await _database.closeDatabase();
    _notificationManager.dispose();
  }
}