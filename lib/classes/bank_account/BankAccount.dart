import 'package:mira_finance_tracker/classes/subjects/FinancialInstitute.dart';
import 'package:mira_finance_tracker/classes/time_management/PeriodicAccountDuration.dart';
import 'package:mira_finance_tracker/classes/time_management/DurationType.dart';
import 'package:mira_finance_tracker/classes/periodic_transactions/BankFee.dart';
import 'package:mira_finance_tracker/classes/periodic_transactions/Cashback.dart';
import 'package:mira_finance_tracker/classes/transaction/BankTransaction.dart';
import 'package:mira_finance_tracker/classes/transaction/Income.dart';

/// Class used to manage general information
/// about a bank account
abstract class BankAccount{
  /* attributes definition */
  int _id;
  String _name;
  double _interest;
  double _availableBalance;
  String? _IBAN;
  FinancialInstitute _bank;
  DateTime _subscriptionDate;
  late PeriodicAccountDuration _interestTime;
  late Set<BankFee> _fees;
  late Set<Cashback> _cashbacks;
  late Set<BankTransaction> _transactions;

  /// Constructor method to build a bank account with it's basic
  /// functionalities
  /// * [_name] unique name given by the user to the bank account
  /// * [_bank] bank institute where the bank account belongs
  /// * [_subscriptionDate] date of the subscription of the bank account
  /// * [_id] ID of the account from the database (it will be -1 right after the instantiation)
  /// * [_availableBalance] it indicates how much money are available for the user
  /// * [_IBAN] IBAN code of the bank account (optional)
  /// * [_interest] possible interest applied to the availble balance of the bank account
  /// * [fees] list of fees of the bank account
  /// * [cashbacks] list of cashbacks of the bank account
  /// * [transactions] list of transactions of the bank account (not necessarily all of them)
  BankAccount(this._name, this._bank, this._subscriptionDate, 
    {this._id = -1, this._availableBalance = 0.0, this._IBAN, this._interest = 0.0,
    List<BankFee>? fees, List<Cashback>? cashbacks, List<BankTransaction>? transactions}){
    /* control validity of the attributes first */
    if(_subscriptionDate.isAfter(DateTime.now())){
      throw Exception("In a bank account the subscription date must come before the current datetime");
    }
    if(_interest < 0){
      throw Exception("In a bank account the possible interest applied must be 0% or more.");
    }

    /* populate the lists */
    _fees = fees?.toSet() ?? {};
    _cashbacks = cashbacks?.toSet() ?? {};
    _transactions = transactions?.toSet() ?? {};

    /* then populate the interest time 
    with day of the month corresponding to the one of the subscription date */
    _interestTime = PeriodicAccountDuration(_subscriptionDate, DurationType.monthly, _subscriptionDate.day);
  }

  /* *** GETTER METHODS *** */
  String get name => _name;
  double get interest => _interest;
  double get availableBalance => _availableBalance;
  String? get IBAN => _IBAN;
  DateTime get subscriptionDate => _subscriptionDate;
  FinancialInstitute get bank => _bank.clone();
  PeriodicAccountDuration get interestTime => _interestTime.clone();
  List<BankFee> get fees {
    List<BankFee> list = [];
    for(BankFee singleFee in _fees){
      list.add(singleFee.clone());
    }
    return list;
  }
  List<Cashback> get cashbacks {
    List<Cashback> list = [];
    for(Cashback singleCashback in _cashbacks){
      list.add(singleCashback.clone());
    }
    return list;
  }
  List<BankTransaction> get transactions {
    List<BankTransaction> list = [];
    for(BankTransaction singleTransaction in _transactions){
      list.add(singleTransaction.clone());
    }
    return list;
  }

  /* *** SETTER METHODS *** */
  set id(int id) => _id = id;
  set interest(double interest) {
    if(interest < 0){
      throw Exception("In a bank account the possible interest applied must be 0% or more.");
    }

    _interest = interest;
  }
  set availableBalance(double availableBalance) => _availableBalance = availableBalance;
  set IBAN(String IBAN) => _IBAN = IBAN;
  set subscriptionDate(DateTime subscriptionDate){
    if(_subscriptionDate.isAfter(DateTime.now())){
      throw Exception("In a bank account the subscription date must come before the current datetime");
    }
    _subscriptionDate = subscriptionDate;
  }

  /* *** CRUD METHODS ***
  Used for the lists of periodic account billings
  and transactions */
  void addFee(BankFee fee){
    _fees.add(fee);
  }
  void removeFee(BankFee fee){
    _fees.remove(fee);
  }
  void replaceFee(BankFee fee){
    _fees.remove(fee);
    _fees.add(fee);
  }

  void addCashback(Cashback cashback){
    _cashbacks.add(cashback);
  }
  void removeCashback(Cashback cashback){
    _cashbacks.remove(cashback);
  }
  void replaceCashback(Cashback cashback){
    _cashbacks.remove(cashback);
    _cashbacks.add(cashback);
  }

  void addTransaction(BankTransaction transaction){
    /* in this case and in the following methods,
    the bank transaction will also change the 
    available balance */

    if(transaction is Income){
      _availableBalance += transaction.amount;
    }else{
      _availableBalance -= transaction.amount;
    }

    _transactions.add(transaction);
  }
  void removeTransaction(BankTransaction transaction){
    /* first try to understand if the 
    element really exists */
    BankTransaction? existingTransaction = _transactions.lookup(transaction);
    if(existingTransaction == null){
      return;
    }

    if(existingTransaction is Income){
      availableBalance -= existingTransaction.amount;
    }else{
      availableBalance += existingTransaction.amount;
    }
  }
  void replaceTransaction(BankTransaction transaction){
    /* first try to understand if the 
    element really exists */
    BankTransaction? existingTransaction = _transactions.lookup(transaction);
    if(existingTransaction == null){
      return;
    }

    if(existingTransaction is Income){
      _availableBalance -= existingTransaction.amount;
      _availableBalance += transaction.amount;
    }else{
      _availableBalance += existingTransaction.amount;
      _availableBalance -= transaction.amount;
    }
  }

  /// Method to add multiple or no transaction inside the bank account.
  /// It's commonly used when calculating interest, billings and 
  /// controlled movements. 
  /// * [transactions] list of transactions to save
  void addTransactions(List<BankTransaction> transactions){
    for(BankTransaction singleTransaction in transactions){
      addTransaction(singleTransaction);
    }
  }

  /// Function to check possible actions 
  /// to make inside the bank account,
  /// like calculating billings and interests
  void check(){
    /* first control if the time has come and 
    there is the interest on the available balance
    to calculate */
    _calculateInterest();

    /* then calculate possible fees and cashbacks */
    _calculateFees();
    _calculateCashbacks();
  }

  /* function to calculate the possible interest
  on an available balance */
  void _calculateInterest(){
    if(_interest <= 0 || !_interestTime.isTime()){
      return;
    }

    /* try to calculate the interest */
    double amount = _availableBalance * _interest;
    _availableBalance += amount; // add the interest calculated to the available balance

    /* add the transaction */
    addTransaction(
      Income(IncomeCategory.bank_interest, "Interesse saldo disponibile", amount, DateTime.now())
    );
  }

  void _calculateFees(){
    /* cycle all the fees and add 
    the transactions in the function */
    for(BankFee singleFee in _fees){
      addTransactions(singleFee.checkAndExecute());
    }
  }

  void _calculateCashbacks(){
    /* cycle all the cashbacks 
    and the corresponding transactions
    in the bank account */
    for(Cashback singleCashback in _cashbacks){
      addTransactions(singleCashback.checkAndExecute());
    }
  }

  /// Override method comparing the bank accounts by 
  /// the name, unique identifier used in the application
  /// * [other] object to compare
  @override
  bool operator ==(Object other){
    return other is BankAccount && other.runtimeType == runtimeType && _name == other._name;
  }

  /// Getter of the hascode of the instance
  @override
  int get hashCode => _name.hashCode;

  /* *** ABSTRACT METHODS *** */
  /// Method creating a deep clone of the object
  /// removing current references
  BankTransaction clone(); 

  /// Function converting the object into a map
  /// for database manipulation
  Map<String, dynamic> toMap(){
    return {
      if(_id >= 0) 'id': _id,
      'name': _name,
      'interest': _interest,
      'availableBalance': _availableBalance,
      'IBAN': _IBAN,
      'bank': _bank.id,
      'subscriptionDate': _subscriptionDate.toIso8601String(),
      ..._interestTime.toMap()
    };
  }
}