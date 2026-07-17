import 'package:mira_finance_tracker/classes/subjects/FinancialInstitute.dart';
import 'package:mira_finance_tracker/classes/periodic_transactions/BankFee.dart';
import 'package:mira_finance_tracker/classes/periodic_transactions/Cashback.dart';
import 'package:mira_finance_tracker/classes/time_management/PeriodicAccountDuration.dart';
import 'package:mira_finance_tracker/classes/transaction/BankTransaction.dart';
import 'package:mira_finance_tracker/classes/transaction/Income.dart';
import 'package:mira_finance_tracker/classes/transaction/Outcome.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/service/FinancialInstrument.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/model/FinancialInstrumentModel.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/elements/CadenceCheck.dart';
import 'package:mira_finance_tracker/classes/bank_account/BankAccount.dart';

/// Class to manage specifically saving accounts
/// and investments connected to it,
/// extending the class [BankAccount]
class SavingsAccount extends BankAccount{
  /* attributes definition */
  late double _ledgerBalance;
  late Set<FinancialInstrument> _financialServices;

  /// Constructor method to build a savings account
  /// with all its necessary data
  /// * [name] unique name given by the user to the bank account
  /// * [bank] bank institute where the bank account belongs
  /// * [subscriptionDate] date of the subscription of the bank account
  /// * [id] ID of the account from the database (it will be -1 right after the instantiation)
  /// * [availableBalance] it indicates how much money are available for the user
  /// * [IBAN] IBAN code of the bank account (optional)
  /// * [interest] possible interest applied to the availble balance of the bank account
  /// * [active] flag to understand if the user wants this bank account active or just archived
  /// * [endingDate] possible ending date of use of the bank account
  /// * [fees] list of fees of the bank account
  /// * [cashbacks] list of cashbacks of the bank account
  /// * [transactions] list of transactions of the bank account (not necessarily all of them)
  /// * [ledgerBalance] counter of the balance invested and available
  /// * [financialInstruments] list of financial instruments activated
  SavingsAccount(String name, FinancialInstitute bank, DateTime subscriptionDate, 
    {int id=-1, double availableBalance = 0.0, String? IBAN, double interest = 0, bool active = true, DateTime? endingDate, PeriodicAccountDuration? interestTime,
    List<BankFee>? fees, List<Cashback>? cashbacks, List<BankTransaction>? transactions,
    List<FinancialInstrument>? financialInstruments, double? ledgerBalance}) :
    super(name, bank, subscriptionDate, id: id, availableBalance: availableBalance, IBAN: IBAN, interest: interest,
    active: active, endingDate: endingDate, interestTime: interestTime,
    fees: fees, cashbacks: cashbacks, transactions: transactions) {
      /* assign to the attributes the
      corresponding values */
      _financialServices = financialInstruments?.toSet() ?? {};
      _ledgerBalance = ledgerBalance ?? super.availableBalance;
  }

  /* *** GETTER METHODS *** */
  double get ledgerBalance => _ledgerBalance;
  List<FinancialInstrument> get financialServices {
    List<FinancialInstrument> list = [];
    for(FinancialInstrument service in _financialServices){
      list.add(service.clone());
    }
    return list;
  }

  /* *** SETTER METHODS *** */
  set ledgerBalance(double ledgerBalance) => _ledgerBalance = ledgerBalance;

  /* *** CRUD METHODS *** 
  for the list of financial instruments */
  void addService(FinancialInstrument service){
    /* control if the service offered was
    coming from the same financial institution or it's public, 
    otherwise it's not possible to save it */
    if(service.providerType != FinancialInstrumentProvider.publicInstitution &&
      super.bank != service.provider!){
      throw Exception("Can't buy a service of another financial institute");
    }

    /* then control if the available balance 
    is enough to buy the service */
    if(service.currentValue > super.availableBalance){
      throw Exception("Can't buy a service which requires more than the money available in the balance");
    }

    /* update the available balance removing
    what has been given to the financial service */
    if(_financialServices.add(service)){
      super.availableBalance -= service.initialValue;
    }
  }

  void removeService(FinancialInstrument service){
    /* remove the service and update the 
    balance with the real existing value of it */
    FinancialInstrument? existingService = _financialServices.lookup(service);
    if(existingService == null){
      return;
    }

    /* update the ledger balance and remove the service */
    super.availableBalance += existingService.initialValue;
    _financialServices.remove(service);
  }

  void replaceService(FinancialInstrument service){
    FinancialInstrument? existingService = _financialServices.lookup(service);
    if(existingService == null){
      return;
    }

    /* control if the available balance 
    is still positive */
    if(super.availableBalance - (service.initialValue - existingService.initialValue) < 0){
      throw Exception("Can't replace a financial service if the new available balance becomes negative.");
    }

    /* remove the previous balance taken 
    and upload with the new one */
    super.availableBalance += existingService.initialValue;
    super.availableBalance -= service.initialValue;
    _financialServices.remove(existingService);
    _financialServices.add(service);
  }

  /// Method to add a transaction, 
  /// override of the method in class [BankAccount].
  /// It supports the types of income provided for a savings account and 
  /// it updates also the ledger balance.
  /// * [transaction] transaction to register
  @override
  void addTransaction(BankTransaction transaction){
    /* first control if it's a financial investment
    or a stock one, just changing the balance
    but not displaying it in the list */
    if(transaction is Income && transaction.category == IncomeCategory.financial_cashing){
      super.availableBalance += transaction.amount;
    }else if(transaction is Outcome && transaction.category == OutcomeCategory.stock_investment){
      super.availableBalance -= transaction.amount;
    }else{
      /* call the superclass method and updating
      also the ledger balance */
      super.addTransaction(transaction);
      if(transaction is Income){
        _ledgerBalance += transaction.amount;
      }else{
        _ledgerBalance -= transaction.amount;
      }
    }
  }

  /// Method to remove the transaction 
  /// considering the ledger balance.
  /// Override of the superclass method in [BankAccount].
  /// * [transaction] transaction to register
  @override
  void removeTransaction(BankTransaction transaction){
    /* first control if the transaction
    is completed by the superclass method, 
    then update the ledger balance */
    BankTransaction? existingTransaction = super.replaceTransaction(transaction);
    if(existingTransaction == null){
      return;
    }
    
    if(transaction is Income){
      _ledgerBalance -= existingTransaction.amount;
    }else{
      _ledgerBalance += existingTransaction.amount;
    }
  }

  /// Function to replace transactions considering
  /// the ledger balance.
  /// Override of the superclass method in [BankAccount].
  /// * [transaction] transaction to register
  @override
  void replaceTransaction(BankTransaction transaction){
    /* first control if the transaction
    is completed by the superclass method, 
    then update the ledger balance */
    BankTransaction? existingTransaction = super.replaceTransaction(transaction);
    if(existingTransaction == null){
      return;
    }

    /* update the ledger balance */
    if(existingTransaction is Income){
      _ledgerBalance += transaction.amount;
      _ledgerBalance -= existingTransaction.amount;
    }
    else{
      _ledgerBalance -= transaction.amount;
      _ledgerBalance += existingTransaction.amount;
    }
  }

  /// Override of the superclass method in [BankAccount]
  /// to check periodically services provided
  @override
  void check(){
    super.check(); // call the superclass method to check
    _checkServices();
  }

  /* function to check periodically services
  inside the savings account */
  void _checkServices(){
    for(FinancialInstrument service in _financialServices){
      if(service is CadenceCheck){
        addTransactions((service as CadenceCheck).checkAndExecute());
      }
    }
  }

  /// Method returning a clone of the Savings Account
  /// overriding the method in class [BankAccount]
  @override
  SavingsAccount clone(){
    return SavingsAccount(super.name, super.bank, super.subscriptionDate, id: super.id, availableBalance: super.availableBalance,
                          IBAN: super.IBAN, interest: super.interest, active: super.isActive, endingDate: super.endingDate,
                          interestTime: super.interestTime, fees: super.fees, cashbacks: super.cashbacks,
                          transactions: super.transactions, financialInstruments: financialServices, ledgerBalance: _ledgerBalance);
  }

  /// Function to convert the object in map
  /// to be used for database manipulation
  @override
  Map<String, dynamic> toMap(){
    return {
      ...super.toMap(),
      'ledgerBalance': _ledgerBalance
    };
  }

  /// Method to convert a map object into a 
  /// Savings Account instance
  /// * [map] map object from database
  /// * [fees] list of fees
  /// * [cashbacks] list of cashbacks
  /// * [transactions] list of transactions
  /// * [services] list of financial services provided
  /// * [financialInstitute] institute offering the bank account service
  /// 
  /// All the arguments except for the map comes from other tables,
  /// so they have to be already converted. 
  factory SavingsAccount.fromMap(Map<String, dynamic> map, List<BankFee> fees, List<Cashback> cashbacks, List<BankTransaction> transactions, 
                                  List<FinancialInstrument> services, FinancialInstitute financialInstitute){
    return SavingsAccount(
      map.remove('name'),
      financialInstitute,
      DateTime.parse(map.remove('subscriptionDate')),
      id: map.remove('id'),
      availableBalance: map.remove('availableBalance'),
      IBAN: map.remove('IBAN'),
      interest: map.remove('interest'),
      active: map.remove('active'),
      endingDate: map.remove('endingDate'),
      interestTime: PeriodicAccountDuration.fromMap(map),
      fees: fees,
      cashbacks: cashbacks,
      transactions: transactions,
      financialInstruments: services,
      ledgerBalance: map['ledgerBalance']
    );
  }
}