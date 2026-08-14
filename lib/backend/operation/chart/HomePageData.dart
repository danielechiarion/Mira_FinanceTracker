import 'package:mira_finance_tracker/classes/transaction/BankTransaction.dart';
import 'package:mira_finance_tracker/backend/operation/chart/ChartElements.dart';
import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';
import 'package:mira_finance_tracker/classes/account/User.dart';

/// Class to manage data inside the home page
/// in order to build up labels and graphs
class HomePageData{
  /* define attributes */
  User _user;
  double _totalBalance;
  late double _periodIncome;
  late double _periodOutcome;
  String _currency;
  late List<AccountShare> _patrimonyDistribution;
  late List<MonthlyFlow> _monthlyTrend;
  late List<BankTransaction> _recentOperations;

  /// define constructor for the home page
  /// summary data 
  /// * [_user] user whose data have to be displayed
  /// * [_currency] currency used to express the financial data, automatically set to euros
  HomePageData(this._user, {this._currency = 'EUR'}) : _totalBalance = 0.0;

  /// Function to init the environment and the other
  /// attributes inside the class
  Future<void> init() async {
    /* instantiate the user dataabase wrapper */
    UserDatabaseWrapper database = UserDatabaseWrapper(_user);
    await database.init();

    _recentOperations = await database.getLatestTransactions(limit: 5); // get first the latest transactions

    _monthlyTrend = await database.getMonthsTrend(); // get the monthly trend
    /* by the monthly trend get the
    data of the trend of the last month, 
    which have to be displayed on their own */
    _periodIncome = _monthlyTrend.last.income;
    _periodOutcome = _monthlyTrend.last.outcome;

    _patrimonyDistribution = await database.getPatrimonyDistribution(); // then get the patrimony distribution
    /* by the distribution given calculate 
    the total balance of the user */
    for(AccountShare singleShare in _patrimonyDistribution){
      _totalBalance += singleShare.amount;
    }
  }

  /* *** GETTER METHODS *** */
  double get totalBalance => _totalBalance;
  double get periodIncome => _periodIncome;
  double get periodOutcome => _periodOutcome;
  String get currency => _currency;
  List<AccountShare> get patrimonyDistribution => _patrimonyDistribution;
  List<MonthlyFlow> get monthlyTrend => _monthlyTrend;
  List<BankTransaction> get recentOperations => _recentOperations;
}