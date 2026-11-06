part of 'UserDatabaseWrapper.dart';

extension UserDatabaseWrapperExport on UserDatabaseWrapper {
  /// Function to get the list of counterParties to export
  /// * [close] flag to close the database
  Future<Map<String, dynamic>> exportCounterparties({bool close = false}) async {
    /* call the database to find all 
    the contacts inside the database */
    List<Map<String, dynamic>> result = await appDatabase.query(sql: 'SELECT id,name,IBAN FROM CounterParty');

    if(close) await appDatabase.close();

    return {
      "table": "CounterParty",
      "content": result
    };
  }

  /// Function to get the list of financial institutes to export
  /// * [close] flag to close the database
  Future<Map<String, dynamic>> exportFinancialInstitutes({bool close = false}) async {
    List<Map<String, dynamic>> result = await appDatabase.query(sql: 'SELECT id, name, email, phoneNumber, site FROM FinancialInstitute');
    
    if(close) await appDatabase.close();

    return {
      "table": "FinancialInstitute",
      "content": result
    };
  }

  /// Function to get the list of bank accounts to export
  /// limited by a [yearLimit] time
  /// * [close] flag to close the database
  Future<Map<String, dynamic>> exportCurrentAccounts(int yearLimit, {bool close = false}) async {
    DateTime currentDate = DateTime.now();
    DateTime limitDate = DateTime(currentDate.year-yearLimit, currentDate.month, currentDate.day);

    List<Map<String, dynamic>> result =  await appDatabase.query(sql: ''' SELECT CurrentAccount.id, CurrentAccount.name, 
            financialInstitute, subscriptionDate, interest, endingDate, availableBalance, active, 
            startingDate, includeStart, timeFrequency, dayOfMonth, monthOfYear, lastDateActivity
            FROM CurrentAccount JOIN BankAccount ON CurrentAccount.id = BankAccount.id WHERE endingDate IS NULL OR endingDate >= ?''',
            arguments: [limitDate.toIso8601String()]);

    if(close) await appDatabase.close();

    return {
      "table": "CurrentAccount",
      "content": result
    };
  }

   /// Function to get the list of bank accounts to export
  /// limited by a [yearLimit] time
  /// * [close] flag to close the database
  Future<Map<String, dynamic>> exportSavingsAccounts(int yearLimit, {bool close = false}) async {
    DateTime currentDate = DateTime.now();
    DateTime limitDate = DateTime(currentDate.year-yearLimit, currentDate.month, currentDate.day);

    List<Map<String, dynamic>> result =  await appDatabase.query(sql: ''' SELECT SavingsAccount.id, SavingsAccount.name, ledgerBalance,
            financialInstitute, subscriptionDate, interest, endingDate, availableBalance, active, 
            startingDate, includeStart, timeFrequency, dayOfMonth, monthOfYear, lastDateActivity
            FROM SavingsAccount JOIN BankAccount ON SavingsAccount.id = BankAccount.id WHERE endingDate IS NULL OR endingDate >= ?''',
            arguments: [limitDate.toIso8601String()]);

    if(close) await appDatabase.close();

    return {
      "table": "SavingsAccount",
      "content": result
    };
  }

   /// Function to get the list of bank accounts to export
  /// limited by a [yearLimit] time
  /// * [close] flag to close the database
  Future<Map<String, dynamic>> exportCardAccounts(int yearLimit, {bool close = false}) async {
    DateTime currentDate = DateTime.now();
    DateTime limitDate = DateTime(currentDate.year-yearLimit, currentDate.month, currentDate.day);

    List<Map<String, dynamic>> result =  await appDatabase.query(sql: ''' SELECT Card.id, Card.name,
            financialInstitute, subscriptionDate, interest, endingDate, availableBalance, active, 
            startingDate, includeStart, timeFrequency, dayOfMonth, monthOfYear, lastDateActivity,
            cardType, dayOfMonthCredit, lastDateActivityCredit
            FROM Card JOIN BankAccount ON Card.id = BankAccount.id WHERE endingDate IS NULL OR endingDate >= ?''',
            arguments: [limitDate.toIso8601String()]);

    if(close) await appDatabase.close();

    return {
      "table": "Card",
      "content": result
    };
  }

  /// Function to export bank accounts that are active within a [yearLimit] expressed
  /// * [close] flag to close the database
  Future<Map<String, dynamic>> exportBankAccounts(int yearLimit, {bool close = false}) async {
    Map<String, dynamic> output = {
      "table": "BankAccount",
      "currentAccounts": await exportCurrentAccounts(yearLimit),
      "savingsAccounts": await exportSavingsAccounts(yearLimit),
      "cards": await exportCardAccounts(yearLimit)
    };

    if(close) await appDatabase.close();

    return output;
  }

  /// Function to export incomes within a [yearLimit] expressed 
  /// * [close] flag to close the database
  Future<Map<String, dynamic>> exportIncomes(int yearLimit, {bool close = false}) async {
    DateTime currentDate = DateTime.now();
    DateTime limitDate = DateTime(currentDate.year-yearLimit, currentDate.month, currentDate.day);

    /* write the query to get incomes 
    within a year limit */
    List<Map<String, dynamic>> result = await appDatabase.query(sql: '''SELECT Income.id, reference, amount, executionDate, accountingDate, category, bankAccount, counterParty
      FROM Income WHERE accountingDate IS NULL OR accountingDate >= ?''', 
      arguments: [limitDate.toIso8601String()]);

    return {
      "table": "Income",
      "content": result
    };
  }

  /// Function to export outgoings within a [yearLimit] expressed
  /// * [close] flag to close the database
  Future<Map<String, dynamic>> exportOutcomes(int yearLimit, {bool close = false}) async {
    DateTime currentDate = DateTime.now();
    DateTime limitDate = DateTime(currentDate.year-yearLimit, currentDate.month, currentDate.day);

    /* write the query to get outgoings
    within a year limit */
    List<Map<String, dynamic>> result = await appDatabase.query(sql: '''SELECT Outgoing.id, reference, amount, executionDate, accountingDate, category, bankAccount, counterParty
      FROM Outgoing WHERE accountingDate IS NULL OR accountingDate >= ?''',
      arguments: [limitDate.toIso8601String()]);

    return {
      "table": "Outgoing",
      "content": result
    };
  }

  /// Function to export all the transactions registered within a [yearLimit] given
  /// * [close] flag to close database
  Future<Map<String, dynamic>> exportTransactions(int yearLimit, {bool close = false}) async {
    Map<String, dynamic> output =  {
      "superclass": "Transaction",
      "incomes": await exportIncomes(yearLimit),
      "outcomes": await exportOutcomes(yearLimit)
    };

    if(close) await appDatabase.close();

    return output;
  }

  /// Function to exports cashbacks related to a current account
  /// * [close] flag to close the database
  Future<Map<String, dynamic>> exportCashbacks({bool close = false}) async {
    List<Map<String, dynamic>> result = await appDatabase.query(sql: '''SELECT id, name, description, amount, startingDate, includeStart, timeFrequency,
      dayOfMonth, monthOfYear, lastDateActivity, bankAccount FROM Cashback''');

    return {
      "table": "Cashback",
      "content": result
    };
  }

  /// Function to exports fees related to a current account
  /// * [close] flag to close the database
  Future<Map<String, dynamic>> exportBankFees({bool close = false}) async {
    List<Map<String, dynamic>> result = await appDatabase.query(sql: '''SELECT id, name, description, amount, startingDate, includeStart, timeFrequency,
      dayOfMonth, monthOfYear, lastDateActivity, bankAccount FROM BankFee''');

    return {
      "table": "BankFee",
      "content": result
    };
  }

  /// Function to return periodic account billings related to each bank account
  /// * [close] flag to close database
  Future<Map<String, dynamic>> exportPeriodicAccountBillings({bool close = false}) async {
    Map<String, dynamic> output = {
      "superclass": "PeriodicAccountBilling",
      "cashbacks": await exportCashbacks(),
      "bankFees": await exportBankFees()
    };

    if(close) await appDatabase.close();

    return output;
  }

  /// Function to get the domiciliations related to the current accounts
  /// * [close] flag to close the database
  Future<Map<String, dynamic>> exportDomiciliations({bool close = false}) async {
    List<Map<String, dynamic>> result = await appDatabase.query(sql: '''SELECT Domiciliation.id, Domiciliation.name, description, amount, fee,
      startingDate, includeStart, timeFrequency, dayOfMonth, monthOfYear, lastDateActivity, bankAccount, counterParty FROM Domiciliation''');

    if(close) await appDatabase.close();

    return {
      "table": "Domiciliation",
      "content": result
    };
  }

  /// Function to get the periodic incomes related to the current accounts
  /// * [close] flag to close the database
  Future<Map<String, dynamic>> exportPeriodicIncomes({bool close = false}) async {
    List<Map<String, dynamic>> result = await appDatabase.query(sql: '''SELECT id, name, description, amount, 
      startingDate, includeStart, timeFrequency, dayOfMonth, monthOfYear, lastDateActivity, bankAccount, counterParty FROM PeriodicIncome''');

    if(close) await appDatabase.close();

    return {
      "table": "PeriodicIncome",
      "content": result
    };
  }

  /// Function to export all periodic transactions
  /// connected to current accounts together
  Future<Map<String, dynamic>> exportPeriodicTransactions({bool close = false}) async {
    Map<String, dynamic> output = {
      "superclass": "PeriodicTransaction",
      "periodicIncomes": await exportPeriodicIncomes(),
      "domiciliations": await exportDomiciliations()
    };

    if(close) await appDatabase.close();

    return output;
  }

  /// Function to export time deposit models
  /// * [close] flag to close the database
  Future<Map<String, dynamic>> exportTimeDepositModels({bool close = false}) async {
    List<Map<String, dynamic>> result = await appDatabase.query(sql: '''SELECT TimeDepositModel.id, TimeDepositModel.name,
      provider, providerType, payoutFrequency, description, duration, taxRate, interestRate, earlyWithdrawalInterestRate, isCashable FROM TimeDepositModel''');

    if(close) await appDatabase.close();

    return {
      "table": "TimeDepositModel",
      "content": result
    };
  }

  /// Function to export bond models
  /// * [close] flag to close the database
  Future<Map<String, dynamic>> exportBondModels({bool close = false}) async {
    List<Map<String, dynamic>> result = await appDatabase.query(sql: '''SELECT BondModel.id, BondModel.name,
      provider, providerType, payoutFrequency, description, duration, taxRate, interestType FROM BondModel''');

    if(close) await appDatabase.close();

    return {
      "table": "BondModel",
      "content": result
    };
  }

  /// Function to export all finacial instrument models registered inside the database 
  /// * [close] flag to close the database
  Future<Map<String, dynamic>> exportFinancialInstrumentModels({bool close = false}) async {
    Map<String, dynamic> output = {
      "superclass": "FinancialInstrumentModel",
      "timeDepositModels": await exportTimeDepositModels(),
      "bondModels": await exportBondModels()
    };

    if(close) await appDatabase.close();

    return output;
  }

  /// Function to export time deposits related to all savings account
  /// finished or running within a provided [yearLimit]
  /// * [close] flag to close the database
  Future<Map<String, dynamic>> exportTimeDeposits(int yearLimit, {bool close = false}) async {
    DateTime currentDate = DateTime.now();
    DateTime limitDate = DateTime(currentDate.year-yearLimit, currentDate.month, currentDate.day);

    List<Map<String, dynamic>> result = await appDatabase.query(sql: '''SELECT TimeDeposit.id, TimeDeposit.name,
      provider, providerType, instrumentUsed, initialValue, currentValue, taxRate, status, interestRate, earlyWithdrawalInterestRate, isCashable,
      startingDate, includeStart, timeFrequency, dayOfMonth, monthOfYear, lastDateActivity, endingDate, includeEnd, bankAccount
      FROM TimeDeposit WHERE endingDate IS NULL OR endingDate >= ?''', 
      arguments: [limitDate.toIso8601String()]);

    if(close) await appDatabase.close();

    return {
      "table": "TimeDeposit",
      "content": result
    };
  }

  /// Function to export bonds related to all savings account
  /// finished or running within a provided [yearLimit]
  /// * [close] flag to close the database
  Future<Map<String, dynamic>> exportBonds(int yearLimit, {bool close = false}) async {
    DateTime currentDate = DateTime.now();
    DateTime limitDate = DateTime(currentDate.year-yearLimit, currentDate.month, currentDate.day);

    List<Map<String, dynamic>> result = await appDatabase.query(sql: '''SELECT Bond.id, Bond.name,
      provider, providerType, instrumentUsed, initialValue, currentValue, taxRate, status, purchasePrice, interestType, minimumDenomination,
      startingDate, includeStart, timeFrequency, dayOfMonth, monthOfYear, lastDateActivity, endingDate, includeEnd, bankAccount
      FROM Bond WHERE endingDate IS NULL OR endingDate >= ?''', 
      arguments: [limitDate.toIso8601String()]);

    if(close) await appDatabase.close();

    return {
      "table": "Bond",
      "content": result
    };
  }

  /// Function to export stocks related to all savings account
  /// finished or running within a provided [yearLimit]
  /// * [close] flag to close the database
  Future<Map<String, dynamic>> exportStocks(int yearLimit, {bool close = false}) async {
    DateTime currentDate = DateTime.now();
    DateTime limitDate = DateTime(currentDate.year-yearLimit, currentDate.month, currentDate.day);

    List<Map<String, dynamic>> result = await appDatabase.query(sql: '''SELECT Stock.id, Stock.name,
      provider, providerType, instrumentUsed, initialValue, currentValue, taxRate, status, ticker, totalShares, 
      averagePurchasePrice, currency, totalDividends, startingDate, endingDate, bankAccount
      FROM Stock WHERE endingDate IS NULL OR endingDate >= ?''', 
      arguments: [limitDate.toIso8601String()]);

    if(close) await appDatabase.close();

    return {
      "table": "Stock",
      "content": result
    };
  }

  /// Function to export all financial instruments running 
  /// within a [yearLimit] window provided
  /// * [close] flag to close the database
  Future<Map<String, dynamic>> exportFinancialInstruments(int yearLimit, {bool close = false}) async {
    Map<String, dynamic> output = {
      "superclass": "FinancialInstruments",
      "timeDeposits": await exportTimeDeposits(yearLimit),
      "bonds": await exportBonds(yearLimit),
      "stocks": await exportStocks(yearLimit)
    };

    if(close) await appDatabase.close();
    
    return output;
  }

  /// Function to export step interests related to bonds and bond models
  /// running within a specific [yearLimit] windows
  /// * [close] flag to close database
  /// * [notModels] flag to indicate if there is not interest on exporting step interests related to bond models
  Future<Map<String, dynamic>> exportStepInterests(int yearLimit, {bool notModels = false, bool close = false}) async {
    /* first export step interests related to bond models. 
    In this case there is no year limit filter required */
    List<Map<String, dynamic>> bondModels = [];
    if(!notModels) {
      bondModels = await appDatabase.query(
        sql: '''SELECT position, interestRate, duration, bond FROM StepInterestModel''',
      );
    }

    /* in the case of bonds we have to export only step interests 
    which are related to current selected bond models */
    List<Map<String, dynamic>> selectedBonds = (await exportBonds(yearLimit))['content'];
    List<Map<String, dynamic>> secondResult = await appDatabase.query(sql: '''SELECT position, interestRate, duration, bond FROM StepInterest''');
    List<Map<String, dynamic>> bonds = secondResult.where((singleResult) => selectedBonds.any((singleBond) => singleBond['id'] == singleResult['bond'])).toList();

    if(close) await appDatabase.close();

    return {
      "superclass": "StepInterest",
      "bondModels": bondModels,
      "bonds": bonds
    };
  }
}