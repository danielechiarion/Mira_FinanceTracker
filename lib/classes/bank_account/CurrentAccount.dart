import 'package:mira_finance_tracker/classes/subjects/FinancialInstitute.dart';
import 'package:mira_finance_tracker/classes/periodic_transactions/BankFee.dart';
import 'package:mira_finance_tracker/classes/periodic_transactions/Cashback.dart';
import 'package:mira_finance_tracker/classes/time_management/PeriodicAccountDuration.dart';
import 'package:mira_finance_tracker/classes/transaction/BankTransaction.dart';
import 'package:mira_finance_tracker/classes/periodic_transactions/Domiciliation.dart';
import 'package:mira_finance_tracker/classes/periodic_transactions/PeriodicIncome.dart';
import 'package:mira_finance_tracker/classes/bank_account/BankAccount.dart';

/// Class used to define specifically a bank account,
/// extending the [BankAccount] provided class
class CurrentAccount extends BankAccount{
  /* defining attributes */
  late Set<Domiciliation> _domiciliations;
  late Set<PeriodicIncome> _periodicIncomes;

  /// Constructor method to build a current account
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
  /// * [domiciliations] list of domiciliations
  /// * [periodicIncomes] list of periodic incomes (such as the salary)
  CurrentAccount(String name, FinancialInstitute bank, DateTime subscriptionDate, 
    {int id=-1, double availableBalance = 0.0, String? IBAN, double interest = 0, bool active = true, DateTime? endingDate, PeriodicAccountDuration? interestTime,
    List<BankFee>? fees, List<Cashback>? cashbacks, List<BankTransaction>? transactions,
    List<Domiciliation>? domiciliations, List<PeriodicIncome>? periodicIncomes}) :
    super(name, bank, subscriptionDate, id: id, availableBalance: availableBalance, IBAN: IBAN, interest: interest,
    active: active, endingDate: endingDate, interestTime: interestTime,
    fees: fees, cashbacks: cashbacks, transactions: transactions){
      /* initializing the sets */
      _domiciliations = domiciliations?.toSet() ?? {};
      _periodicIncomes = periodicIncomes?.toSet() ?? {};
  }

  /* *** GETTER METHODS *** */
  List<Domiciliation> get domiciliations {
    List<Domiciliation> list = [];
    for(Domiciliation singleDomiciliation in _domiciliations){
      list.add(singleDomiciliation.clone());
    }
    return list;
  }
  List<PeriodicIncome> get periodicIncomes{
    List<PeriodicIncome> list = [];
    for(PeriodicIncome periodicIncome in _periodicIncomes){
      list.add(periodicIncome.clone());
    }
    return list;
  }

  /* *** CRUD METHODS *** 
  for the list created inside the current account */
  void addDomiciliation(Domiciliation domiciliation){
    _domiciliations.add(domiciliation);
  }
  void removeDomiciliation(Domiciliation domiciliation){
    _domiciliations.remove(domiciliation);
  }
  void replaceDomiciliation(Domiciliation domiciliation){
    _domiciliations.remove(domiciliation);
    _domiciliations.add(domiciliation);
  }

  void addPeriodicIncome(PeriodicIncome periodicIncome){
    _periodicIncomes.add(periodicIncome);
  }
  void removePeriodicIncome(PeriodicIncome periodicIncome){
    _periodicIncomes.remove(periodicIncome);
  }
  void replacePeriodicIncome(PeriodicIncome periodicIncome){
    _periodicIncomes.remove(periodicIncome);
    _periodicIncomes.add(periodicIncome);
  }

  /// Function to check periodic transactions to be done
  /// override of the method in super class [BankAccount]
  @override
  void check(){
    super.check(); // check the basic functions of the bank account
    
    /* then check domiciliations
    and periodic incomes */
    _checkDomiciliations();
    _checkPeriodicIncomes();
  }

  /* function to check if it's time 
  to calculate domiciliations */
  void _checkDomiciliations(){
    for(Domiciliation singleDomiciliation in _domiciliations){
      addTransactions(singleDomiciliation.checkAndExecute());
    }
  }
  /* function to check if it's time 
  to calculate periodic incomes */
  void _checkPeriodicIncomes(){
    for(PeriodicIncome periodicIncome in _periodicIncomes){
      addTransactions(periodicIncome.checkAndExecute());
    }
  }

  /// Clone method overriding the one in the
  /// superclass [BankAccount]
  @override
  CurrentAccount clone(){
    return CurrentAccount(super.name, super.bank, super.subscriptionDate, id: super.id, availableBalance: super.availableBalance,
                          IBAN: super.IBAN, interest: super.interest, active: super.isActive, endingDate: super.endingDate, interestTime: super.interestTime.clone(),
                          fees: super.fees, cashbacks: super.cashbacks, transactions: super.transactions,
                          domiciliations: domiciliations, periodicIncomes: periodicIncomes);
  }

  /// Method to convert a map object into a 
  /// Current Account instance
  /// * [map] map object from database
  /// * [fees] list of fees
  /// * [cashbacks] list of cashbacks
  /// * [transactions] list of transactions
  /// * [domiciliations] list of domiciliations
  /// * [periodicIncomes] list of periodic incomes
  /// * [financialInstitute] institute offering the bank account service
  /// 
  /// All the arguments except for the map comes from other tables,
  /// so they have to be already converted. 
  factory CurrentAccount.fromMap(Map<String, dynamic> map, List<BankFee> fees, List<Cashback> cashbacks, List<BankTransaction> transactions, 
                                  List<Domiciliation> domiciliations, List<PeriodicIncome> periodicIncomes, FinancialInstitute financialInstitute){
    final accountMap = Map<String, dynamic>.from(map);

    return CurrentAccount(
      accountMap.remove('name'),
      financialInstitute,
      DateTime.parse(accountMap.remove('subscriptionDate')),
      id: accountMap.remove('id'),
      availableBalance: accountMap.remove('availableBalance'),
      IBAN: accountMap.remove('IBAN'),
      interest: accountMap.remove('interest'),
      active: accountMap.remove('active') == 1,
      endingDate: DateTime.tryParse((accountMap.remove('endingDate') as String?) ?? ''),
      interestTime: PeriodicAccountDuration.fromMap(accountMap),
      fees: fees,
      cashbacks: cashbacks,
      transactions: transactions,
      domiciliations: domiciliations,
      periodicIncomes: periodicIncomes
    );
  }
}