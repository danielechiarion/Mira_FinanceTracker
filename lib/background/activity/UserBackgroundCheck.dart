import 'package:mira_finance_tracker/classes/account/User.dart';
import 'package:mira_finance_tracker/classes/bank_account/BankAccount.dart';
import 'package:mira_finance_tracker/classes/bank_account/Card.dart';
import 'package:mira_finance_tracker/classes/transaction/BankTransaction.dart';

import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';
import 'package:mira_finance_tracker/backend/service/preference/UserPreferences.dart';
import 'package:mira_finance_tracker/backend/service/notification/NotificationManager.dart';
import 'package:mira_finance_tracker/backend/service/notification/NotificationData.dart';
import 'package:mira_finance_tracker/backend/service/session/BackgroundSession.dart';

import 'package:mira_finance_tracker/backend/cloud/operation/CloudFileExport.dart';
import 'package:mira_finance_tracker/backend/cloud/operation/CloudFileImport.dart';

import 'package:flutter/foundation.dart';

/// Function to check the state 
/// of each account and resource connected to 
/// the user on the application.
/// 
/// This operation has to be done in the background,
/// to check continuously for updates. 
class UserBackgroundCheck {
  /* define attributes */
  User _user;
  UserDatabaseWrapper _database;
  UserPreferences _preference;
  NotificationManager _notificationService;
  late BackgroundSession _session;

  /// Define the constructor to instantiate 
  /// the class with all the resources connected to it
  /// * [user] user where to make the research
  /// * [_notificationService] service for notification already initialized given as a parameter
  UserBackgroundCheck(User user, this._notificationService) : _user = user, _database = UserDatabaseWrapper(user), _preference = UserPreferences(user),
    _session = BackgroundSession(user);

  /// Function to initialize on the background the
  /// resources used by the class
  Future<void> init() async {
    await _database.init();
    await _preference.init(readDatabase: true); // read the preferences from the database every time
    await _session.init();
  }

  /// Function to execute the background
  /// check for the user updating the data
  /// inside the database
  Future<void> execute() async {
    /* before the operations that has to be done
    in a normal background check, ensure that the data of the application
    are synchronized with the ones saved in the cloud, if that option has been enabled.  */
    if (_user.isUserConnected && !await _cloudImportSynchronization()) {
      await _disposeResources();
      return;
    }

    /* first of all get the essential preferences
    for the user to do the background check */
    bool backgroundEnabled = _preference.getPreference('enableBackground').currentValue;
    bool notificationEnabled = _preference.getPreference('enableNotifications').currentValue;

    debugPrint('🔵 [UBC] user=${_user.name}, bg=$backgroundEnabled, notif=$notificationEnabled');

    /* if the background check is 
    not enabled, just end the execution of the class */
    if (!backgroundEnabled) {
      await _disposeResources();
      return;
    }

    /* then get the list of the 
    bank accounts and check for each one
    if something has to be done */
    List<BankAccount> accounts = await _database.getCompleteBankAccounts();
    List<NotificationData> notificationRequests = [];
    List<BankTransaction> previousTransactions = []; // list to be used on a credit card transaction to distinguish them from new ones
    for(BankAccount singleBankAccount in accounts) {
      /* first check if it's a credit card. 
      in this case get the latest transactions to make
      it sure the control can be made to use the credit */
      if(singleBankAccount is Card && singleBankAccount.cardType == CardType.credit){
        previousTransactions = await _database.getCreditCardTransactions(singleBankAccount);
        singleBankAccount.transactions = List.from(previousTransactions);
      }

      singleBankAccount.check(notificationRequests: notificationRequests);

      /* add an important control for credit cards. 
      Before saving new transactions, there are still old ones that could
      be accounted today. 
      So update before the already existing transactions, 
      then remove them so as to keep only the new transactions to be saved. */
      if(singleBankAccount is Card && singleBankAccount.cardType == CardType.credit){
        for(BankTransaction singleTransaction in previousTransactions){
          await _database.updateTransaction(singleTransaction); // update the existing transaction
          singleBankAccount.removeTransaction(singleTransaction); // then remove it from the list
        }
      }

      /* if notification is enabled
      send notification for each movement */
      if(notificationEnabled) await _sendNotifications(singleBankAccount);

      /* then save the changes inside the database
      to keep it permanent */
      await _saveChanges(singleBankAccount);
    }

    /* publish the notification requests 
    for the user as the last ones, to be more visible */
    for(NotificationData notification in notificationRequests){
      await _notificationService.showNotification(id: NotificationManager.generateNotificationID(), title: notification.title, body: notification.text);
    }

    /* at the end, if the cloud sync has been enable from the user,
    save the changes inside the cloud */
    if(_user.isUserConnected) await _cloudExportSynchronization();

    await _disposeResources(); // then dispose all the resouces at the end of the operation
  }

  /* function to dispose resources
  at the end of the execution */
  Future<void> _disposeResources() async {
    await _database.closeDatabase();
    await _preference.disconnect();
    await _session.disconnect();
  }

  /* function to send notifications for each 
  bank account after generating transactions */
  Future<void> _sendNotifications(BankAccount account) async {
    /* add the text to add to the title
    of the notification */
    String notificationTitle = "${_user.name} / ${account.name}: ";

    /* process each transaction
    and send a notification to the user */
    for(BankTransaction transaction in account.transactions){
      NotificationData notification = transaction.toNotification();
      notification.increaseTitle(notificationTitle, true);
      await _notificationService.showNotification(id: NotificationManager.generateNotificationID(), title: notification.title, body: notification.text);
    }
  }

  /* function to save the changes made
  to a bank account */
  Future<void> _saveChanges(BankAccount account) async {
    /* first save the available balance and,
    if it's a savings account, the ledger balance */
    await _database.updateBankAccountBalance(account);
    await _database.updateAccountServices(account);
    await _database.saveTransactions(account, account.transactions);
  }

  /* function to import files from the cloud
  in order to keep the background updated */
  Future<bool> _cloudImportSynchronization() async {
    /* define variables for a 
    minimum of attempt to execute the import
    when it fails for some reason */
    int importingAttempts = 5;
    bool result = false;

    /* instantiate the import, 
    then repeat the execution if necessary and 
    finally dipose the resources of the instance */
    CloudFileImport importer = CloudFileImport(_session, foreground: false);
    try {
      await importer.init();
      for (int i = 0; i < importingAttempts && !result; i++) {
        result = await importer.execute();
      }
      return result;
    } finally {
      await importer.dispose();
    }
  }

  /* function to export files from the
  cloud in order to keep the background updated*/
  Future<void> _cloudExportSynchronization() async {
    /* define variables for a 
    minimum of attempt to execute the export
    when it fails for some reason */
    int exportingAttempts = 5;
    bool result = false;

    /* instantiate the export, than repeat the execution
    only if it's necessary, then dispose the resources
    connected to the operation */
    CloudFileExport exporter = CloudFileExport(_session, foreground: false);
    await exporter.init();
    for(int i=0; i<exportingAttempts && !result; i++){
      result = await exporter.execute();
    }
    await exporter.dispose();
  }
}