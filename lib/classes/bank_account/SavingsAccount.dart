import 'package:mira_finance_tracker/classes/subjects/FinancialInstitute.dart';
import 'package:mira_finance_tracker/classes/periodic_transactions/BankFee.dart';
import 'package:mira_finance_tracker/classes/periodic_transactions/Cashback.dart';
import 'package:mira_finance_tracker/classes/time_management/PeriodicAccountDuration.dart';
import 'package:mira_finance_tracker/classes/transaction/BankTransaction.dart';
import 'package:mira_finance_tracker/classes/transaction/Income.dart';
import 'package:mira_finance_tracker/classes/transaction/Outcome.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/service/FinancialInstrument.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/model/FinancialInstrumentModel.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/service/Bond.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/service/Stock.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/service/TimeDeposit.dart';
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

    
  }
}