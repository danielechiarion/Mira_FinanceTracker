import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:intl/intl.dart';

import 'package:mira_finance_tracker/backend/service/KeyManager.dart';
import 'package:mira_finance_tracker/backend/service/database/SystemDatabaseWrapper.dart';
import 'package:mira_finance_tracker/backend/service/database/EncryptedDatabase.dart';

import 'package:mira_finance_tracker/classes/account/User.dart';
import 'package:mira_finance_tracker/classes/bank_account/BankAccount.dart';
import 'package:mira_finance_tracker/classes/transaction/BankTransaction.dart';
import 'package:mira_finance_tracker/classes/transaction/Income.dart';
import 'package:mira_finance_tracker/classes/bank_account/Card.dart';
import 'package:mira_finance_tracker/classes/bank_account/CurrentAccount.dart';
import 'package:mira_finance_tracker/classes/bank_account/SavingsAccount.dart';
import 'package:mira_finance_tracker/classes/subjects/FinancialInstitute.dart';
import 'package:mira_finance_tracker/classes/subjects/CounterParty.dart';

import 'package:mira_finance_tracker/backend/service/preference/SinglePreference.dart';
import 'package:mira_finance_tracker/backend/operation/chart/ChartElements.dart';

part 'UserDatabaseWrapperReader.dart';
part 'UserDatabaseWrapperWriter.dart';
part 'UserDatabaseWrapperUpdate.dart';

/// Class to handle personal database belonging to 
/// the user registered inside the application. 
/// Extending class of [SystemDatabaseWrapper].
class UserDatabaseWrapper extends SystemDatabaseWrapper{
  /* define attributes */
  User _user;
  
  /// Constructor of the user database wrapper 
  /// starting from user information 
  /// * [user] user owner of the database
  UserDatabaseWrapper(User user): _user = user,
    super(keyManagerInput: KeyManager(user: user, search: false));

  /// Function to initialize the database 
  /// defining the tables. 
  /// Defining also the system database if it has not done before. 
  @override
  Future<void> init() async {
    await super.init(); // first start to initialize the system database
    /* then try to add the user, 
    if it has not been done before */
    try{
      await super.addUser(_user);
    }on Exception{}
    finally{
      await database.close(); // close system database after finishing operations
    }

    /* get the secret key of the user
    researching it */
    await super.keyManager.init();
    // Ensure we attempt to recover the user key explicitly
    try {
      await super.keyManager.recoverKey();
    } catch (e) {
      // If recoverKey fails, rethrow a clearer exception for callers
      throw Exception('Impossibile recuperare la chiave utente: $e');
    }

    /* now open the database for the
    user and initialize it if necessary */
    final String? key = await super.keyManager.stringKey;
    if (key == null) {
      throw Exception('Chiave di cifratura utente non disponibile per ${_user.username}');
    }
    await database.openAppDatabase(dbName: '${SystemDatabaseWrapper.USERDATABASEPREFIX}${_user.username}', password: key, onCreate: defineTables);
  }

  /* *** GETTER METHODS *** */
  @protected
  EncryptedDatabase get appDatabase => database;

  @protected
  @override
  Future<void> defineTables(Database db, int version) async{
    /* call all the private methods used
    to define tables of a single user database */
    await _defineSubjects(db);
    await _defineBankAccounts(db);
    await _defineTransactions(db);
    await _definePeriodicAccountBillings(db);
    await _definePeriodicTransactions(db);
    await _defineFinancialInstrumentModels(db);
    await _defineFinancialInstruments(db);
    await _defineInterests(db);
    await _definePreferences(db);
  }

  /* function to define subjects
  inside the banking application */
  Future<void> _defineSubjects(Database db) async{
    /* define counterparty member */
    await db.execute('''CREATE TABLE IF NOT EXISTS CounterParty(
                        id INTEGER PRIMARY KEY AUTOINCREMENT, 
                        name TEXT NOT NULL UNIQUE,
                        IBAN TEXT)''');
    /* define financial institute member */
    await db.execute('''CREATE TABLE IF NOT EXISTS FinancialInstitute(
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        name TEXT NOT NULL UNIQUE,
                        email TEXT,
                        phoneNumber TEXT,
                        site TEXT)''');
  }

  /* function to define tables for bank accounts */
  Future<void> _defineBankAccounts(Database db) async{
    /* create general table bank account, with all
    the tables for each extended class, in order
    to manage correctly common fields
    and common entity related such as incomes and outcomes */
    await db.execute('''CREATE TABLE IF NOT EXISTS BankAccount(
                        id INTEGER PRIMARY KEY AUTOINCREMENT
                        financialInstitute INTEGER,
                        subscriptionDate TEXT NOT NULL,
                        interest REAL NOT NULL,
                        endingDate TEXT,
                        availableBalance REAL NOT NULL,
                        active INTEGER NOT NULL,
                        IBAN TEXT,
                        startingDate TEXT NOT NULL,
                        includeStart INTEGER NOT NULL,
                        timeFrequency INTEGER NOT NULL,
                        dayOfMonth INTEGER NOT NULL,
                        monthOfYear INTEGER,
                        lastDateActivity TEXT
                        
                        FOREIGN KEY (financialInstitute) REFERENCES FinancialInstitute(id)
                          ON DELETE RESTRICT
                      )''');

    /* defining current account table */
    await db.execute('''CREATE TABLE IF NOT EXISTS CurrentAccount(
                        id INTEGER PRIMARY KEY,
                        name TEXT NOT NULL UNIQUE,

                        FOREIGN KEY (id) REFERENCES BankAccount(id) 
                          ON DELETE CASCADE 
                        )''');
    
    /* define table for savings account */
    await db.execute('''CREATE TABLE IF NOT EXISTS SavingsAccount(
                        id INTEGER PRIMARY KEY,
                        name TEXT NOT NULL UNIQUE,
                        ledgerBalance REAL NOT NULL,

                        FOREIGN KEY (id) REFERENCES BankAccount(id) 
                          ON DELETE CASCADE 
                        )''');
    
    /* define table for cards */
    await db.execute('''CREATE TABLE IF NOT EXISTS Card(
                        id INTEGER PRIMARY KEY,
                        name TEXT NOT NULL UNIQUE,
                        cardType INTEGER NOT NULL,

                        FOREIGN KEY (id) REFERENCES BankAccount(id) 
                          ON DELETE CASCADE 
                        )''');
  }

  /* function to define table for basic 
  transactions through every kind of bank account */
  Future<void> _defineTransactions(Database db) async {
    /* define incomes and outcomes,
    which contains the same fields */
    await db.execute('''CREATE TABLE IF NOT EXISTS Income(
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        bankAccount INTEGER NOT NULL,
                        reference TEXT NOT NULL,
                        counterParty INTEGER,
                        amount REAL NOT NULL,
                        executionDate TEXT NOT NULL,
                        accountingDate TEXT,
                        category INTEGER NOT NULL

                        FOREIGN KEY (bankAccount) REFERENCES BankAccount(id)
                          ON DELETE CASCADE,
                        FOREIGN KEY (counterParty) REFERENCES CounterParty(id)
                          ON DELETE RESTRICT
                        )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS Outcome(
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        bankAccount INTEGER NOT NULL,
                        reference TEXT NOT NULL,
                        counterParty INTEGER,
                        amount REAL NOT NULL,
                        executionDate TEXT NOT NULL,
                        accountingDate TEXT,
                        category INTEGER NOT NULL

                        FOREIGN KEY (bankAccount) REFERENCES BankAccount(id)
                          ON DELETE CASCADE,
                        FOREIGN KEY (counterParty) REFERENCES CounterParty(id)
                          ON DELETE RESTRICT
                        )''');
  }

  /* function to define periodic account billings
  for every kind of bank account */
  Future<void> _definePeriodicAccountBillings(Database db) async{
    /* first define cashbacks, 
    the bank fee will follow the same format */
    await db.execute('''CREATE TABLE IF NOT EXISTS Cashback(
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        bankAccount INTEGER NOT NULL,
                        name TEXT NOT NULL UNIQUE,
                        description TEXT,
                        amount REAL NOT NULL,
                        startingDate TEXT NOT NULL,
                        includeStart INTEGER NOT NULL,
                        timeFrequency INTEGER NOT NULL,
                        dayOfMonth INTEGER NOT NULL,
                        monthOfYear INTEGER,
                        lastDateActivity TEXT,

                        FOREIGN KEY (bankAccount) REFERENCES BankAccount(id)
                          ON DELETE CASCADE
                        )''');

    await db.execute('''CREATE TABLE IF NOT EXISTS BankFee(
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        bankAccount INTEGER NOT NULL,
                        name TEXT NOT NULL UNIQUE,
                        description TEXT,
                        amount REAL NOT NULL,
                        startingDate TEXT NOT NULL,
                        includeStart INTEGER NOT NULL,
                        timeFrequency INTEGER NOT NULL,
                        dayOfMonth INTEGER NOT NULL,
                        monthOfYear INTEGER,
                        lastDateActivity TEXT,

                        FOREIGN KEY (bankAccount) REFERENCES BankAccount(id)
                          ON DELETE CASCADE
                        )''');
  }

  /* function to define periodic transactions 
  registered inside the current account */
  Future<void> _definePeriodicTransactions(Database db) async {
    /* first define periodic income, 
    which has lighter structure */
    await db.execute('''CREATE TABLE IF NOT EXISTS PeriodicIncome(
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        bankAccount INTEGER NOT NULL,
                        name TEXT NOT NULL UNIQUE,
                        description TEXT,
                        amount REAL NOT NULL,
                        counterParty INTEGER NOT NULL,
                        startingDate TEXT NOT NULL,
                        includeStart INTEGER NOT NULL,
                        timeFrequency INTEGER NOT NULL,
                        dayOfMonth INTEGER NOT NULL,
                        monthOfYear INTEGER,
                        lastDateActivity TEXT,

                        FOREIGN KEY (bankAccount) REFERENCES BankAccount(id)
                          ON DELETE CASCADE,
                        FOREIGN KEY (counterParty) REFERENCES CounterParty(id)
                          ON DELETE RESTRICT
                        )''');

    /* the domiciliation has the fee 
    as additional field to add */
    await db.execute('''CREATE TABLE IF NOT EXISTS Domiciliation(
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        bankAccount INTEGER NOT NULL,
                        name TEXT NOT NULL UNIQUE,
                        description TEXT,
                        amount REAL NOT NULL,
                        counterParty INTEGER NOT NULL,
                        fee REAL NOT NULL,
                        startingDate TEXT NOT NULL,
                        includeStart INTEGER NOT NULL,
                        timeFrequency INTEGER NOT NULL,
                        dayOfMonth INTEGER NOT NULL,
                        monthOfYear INTEGER,
                        lastDateActivity TEXT,

                        FOREIGN KEY (bankAccount) REFERENCES BankAccount(id)
                          ON DELETE CASCADE,
                        FOREIGN KEY (counterParty) REFERENCES CounterParty(id)
                          ON DELETE RESTRICT
                        )''');
  }

  /* function to define financial instrument models
  to use inside a savings account */
  Future<void> _defineFinancialInstrumentModels(Database db) async {
    /* first define the time deposit model */
    await db.execute('''CREATE TABLE IF NOT EXISTS TimeDepositModel(
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        provider INTEGER,
                        providerType INTEGER NOT NULL,
                        name TEXT NOT NULL UNIQUE,
                        payoutFrequency INTEGER NOT NULL,
                        description TEXT,
                        duration TEXT NOT NULL,
                        taxRate REAL NOT NULL,
                        interestRate REAL NOT NULL,
                        earlyWithdrawalInterestRate REAL NOT NULL,
                        isCashable INTEGER NOT NULL,

                        FOREIGN KEY (provider) REFERENCES FinancialInstitute(id)
                          ON DELETE RESTRICT
                        )''');

    /* then define the bond model
    for savings account */
    await db.execute('''CREATE TABLE IF NOT EXISTS BondModel(
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        provider INTEGER,
                        providerType INTEGER NOT NULL,
                        name TEXT NOT NULL UNIQUE,
                        payoutFrequency INTEGER NOT NULL,
                        description TEXT,
                        duration TEXT NOT NULL,
                        taxRate REAL NOT NULL,
                        interestType INTEGER NOT NULL,

                        FOREIGN KEY (provider) REFERENCES FinancialInstitute(id)
                          ON DELETE RESTRICT
                        )''');
  }

  /* function to define the financial instruments
  that has been activated inside the savings account */
  Future<void> _defineFinancialInstruments(Database db) async {
    /* define time deposit */
    await db.execute('''CREATE TABLE IF NOT EXISTS TimeDeposit(
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        bankAccount INTEGER NOT NULL,
                        name TEXT NOT NULL UNIQUE,
                        provider INTEGER,
                        providerType INTEGER NOT NULL,
                        instrumentUsed TEXT,
                        initialValue REAL NOT NULL,
                        currentValue REAL NOT NULL,
                        taxRate REAL NOT NULL,
                        status INTEGER NOT NULL,
                        interestRate REAL NOT NULL,
                        earlyWithdrawalInterestRate REAL NOT NULL,
                        isCashable INTEGER NOT NULL,
                        
                        startingDate TEXT NOT NULL,
                        includeStart INTEGER NOT NULL,
                        timeFrequency INTEGER NOT NULL,
                        dayOfMonth INTEGER NOT NULL,
                        monthOfYear INTEGER,
                        lastDateActivity TEXT,
                        endingDate TEXT,
                        includeEnd INTEGER NOT NULL,

                        FOREIGN KEY (bankAccount) REFERENCES BankAccount(id)
                          ON DELETE CASCADE,
                        FOREIGN KEY (provider) REFERENCES FinancialInstitute(id)
                          ON DELETE RESTRICT,
                        FOREIGN KEY (instrumentUsed) REFERENCES TimeDepositModel(name)
                          ON DELETE RESTRICT
                          ON UPDATE CASCADE
                        )''');

    /* define bond */
    await db.execute('''CREATE TABLE IF NOT EXISTS Bond(
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        bankAccount INTEGER NOT NULL,
                        name TEXT NOT NULL UNIQUE,
                        provider INTEGER,
                        providerType INTEGER NOT NULL,
                        instrumentUsed TEXT,
                        initialValue REAL NOT NULL,
                        currentValue REAL NOT NULL,
                        taxRate REAL NOT NULL,
                        status INTEGER NOT NULL,
                        purchasePrice REAL NOT NULL,
                        interestType INTEGER NOT NULL,
                        minimumDenomination REAL NOT NULL,
                        
                        startingDate TEXT NOT NULL,
                        includeStart INTEGER NOT NULL,
                        timeFrequency INTEGER NOT NULL,
                        dayOfMonth INTEGER NOT NULL,
                        monthOfYear INTEGER,
                        lastDateActivity TEXT,
                        endingDate TEXT,
                        includeEnd INTEGER NOT NULL,

                        FOREIGN KEY (bankAccount) REFERENCES BankAccount(id)
                          ON DELETE CASCADE,
                        FOREIGN KEY (provider) REFERENCES FinancialInstitute(id)
                          ON DELETE RESTRICT,
                        FOREIGN KEY (instrumentUsed) REFERENCES BondModel(name)
                          ON DELETE RESTRICT
                          ON UPDATE CASCADE
                        )''');
    
    /* define stock */
    await db.execute('''CREATE TABLE IF NOT EXISTS Stock(
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        bankAccount INTEGER NOT NULL,
                        name TEXT NOT NULL UNIQUE,
                        provider INTEGER,
                        providerType INTEGER NOT NULL,
                        instrumentUsed TEXT,
                        initialValue REAL NOT NULL,
                        currentValue REAL NOT NULL,
                        taxRate REAL NOT NULL,
                        status INTEGER NOT NULL,
                        ticker TEXT,
                        totalShares REAL NOT NULL,
                        averagePurchasePrice REAL NOT NULL,
                        currency INTEGER NOT NULL,
                        totalDividends REAL NOT NULL,
                        startingDate TEXT NOT NULL,
                        endingDate TEXT,

                        FOREIGN KEY (bankAccount) REFERENCES BankAccount(id)
                          ON DELETE CASCADE,
                        FOREIGN KEY (provider) REFERENCES FinancialInstitute(id)
                          ON DELETE RESTRICT,
                        FOREIGN KEY (instrumentUsed) REFERENCES BondModel(name)
                          ON DELETE RESTRICT
                          ON UPDATE CASCADE
                        )''');
  }

  /* function to define interest in bank accounts, 
  especially in bonds activated inside a savings account */
  Future<void> _defineInterests(Database db) async{
    /* define step interest for bonds */
    await db.execute('''CREATE TABLE IF NOT EXISTS StepInterest(
                          position INTEGER,
                          bond INTEGER,
                          interestRate REAL NOT NULL,
                          duration TEXT NOT NULL,

                          PRIMARY KEY (position, bond),

                          FOREIGN KEY (bond) REFERENCES Bond(id)
                            ON DELETE CASCADE
                        )''');

    /* create also step interest for bond models,
    which changes only the reference to the bond model table */
    await db.execute('''CREATE TABLE IF NOT EXISTS StepInterestModel(
                          position INTEGER,
                          bond INTEGER,
                          interestRate REAL NOT NULL,
                          duration TEXT NOT NULL,

                          PRIMARY KEY (position, bond),

                          FOREIGN KEY (bond) REFERENCES BondModel(id)
                            ON DELETE CASCADE
                        )''');
  }

  /* function to define tables 
  for the preferences of the user to be saved */
  Future<void> _definePreferences(Database db) async {
    /* use another format for the name to
    distinguish the type of tables,
    because this one is used to save personal system settings. */
    await db.execute('''CREATE TABLE IF NOT EXISTS application_preferences (
                        name TEXT PRIMARY KEY,
                        value TEXT NOT NULL
                        )''');
  }

  /* *** DEPRECATED METHODS ***
  Deprecate methods available only on the system database
  and not on the custom user one */
  @override
  @Deprecated("Method not supported for user database instance. Try system database one.")
  Future<int> addUser(User user, {bool passwordHashed = false, bool close = false}) async {
    throw UnimplementedError("Method not supported for user database instance. Try system database one.");
  }

  @override
  @Deprecated("Method not supported for user database instance. Try system database one.")
  Future<void> removeUser(User user, {bool close = false}) async {
    throw UnimplementedError("Method not supported for user database instance. Try system database one.");
  }

  @override
  @Deprecated("Method not supported for user database instance. Try system database one.")
  Future<void> updateUser(User user, {bool close = false}) async {
    throw UnimplementedError("Method not supported for user database instance. Try system database one.");
  }

  @override
  @Deprecated("Method not supported for user database instance. Try system database one.")
  Future<List<User>> userList({bool close = false}) async {
    throw UnimplementedError("Method not supported for user database instance. Try system database one.");
  }

  @override
  @Deprecated("Method not supported for user database instance. Try system database one.")
  Future<bool> userValidity(String username) async {
    throw UnimplementedError("Method not supported for user database instance. Try system database one.");
  }
}