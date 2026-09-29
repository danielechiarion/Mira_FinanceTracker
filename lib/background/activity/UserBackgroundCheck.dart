import 'package:mira_finance_tracker/classes/account/User.dart';
import 'package:mira_finance_tracker/classes/bank_account/BankAccount.dart';
import 'package:mira_finance_tracker/classes/bank_account/Card.dart';
import 'package:mira_finance_tracker/classes/transaction/BankTransaction.dart';

import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';
import 'package:mira_finance_tracker/backend/service/preference/UserPreferences.dart';
import 'package:mira_finance_tracker/backend/service/notification/NotificationManager.dart';
import 'package:mira_finance_tracker/backend/service/notification/NotificationData.dart';

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

  /// Define the constructor to instantiate 
  /// the class with all the resources connected to it
  /// * [user] user where to make the research
  /// * [_notificationService] service for notification already initialized given as a parameter
  UserBackgroundCheck(User user, this._notificationService) : _user = user, _database = UserDatabaseWrapper(user), _preference = UserPreferences(user);

  /// Function to initialize on the background the
  /// resources used by the class
  Future<void> init() async {
    await _database.init();
    await _preference.init(readDatabase: true); // read the preferences from the database every time
  }

  /// Function to execute the background
  /// check for the user updating the data
  /// inside the database
  Future<void> execute() async {
    /* first of all get the essential preferences
    for the user to do the background check */
    bool backgroundEnabled = _preference.getPreference('enableBackground').currentValue;
    bool notificationEnabled = _preference.getPreference('enableNotifications').currentValue;

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

    await _disposeResources(); // then dispose all the resouces at the end of the operation
  }

  /* function to dispose resources
  at the end of the execution */
  Future<void> _disposeResources() async {
    await _database.closeDatabase();
    await _preference.disconnect();
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
}