part of 'UserDatabaseWrapper.dart';

extension UserDatabaseWrapperImport on UserDatabaseWrapper{
  /// Function writing inside the database the counterparties 
  /// given from a specific file [content]
  /// * [close] flag to close the database
  Future<void> importCounterparties(Map<String, dynamic> content, {bool close = false}) async {
    for(Map<String, dynamic> counterParty in content['content']) {
      await appDatabase.executeWithMap(sql: '''INSERT OR REPLACE INTO CounterParty (id, name, IBAN) VALUES (:id, :name, :IBAN)''',
        parameters: counterParty);
    }

    if(close) await appDatabase.close();
  }

  /// Function writing inside the database the financial institutes
  /// given from a specific file [content]
  /// * [close] flag to close the database
  Future<void> importFinancialInstitutes(Map<String, dynamic> content, {bool close = false}) async {
    for(Map<String, dynamic> financialInstitute in content['content']){
      await appDatabase.executeWithMap(sql: '''INSERT OR REPLACE INTO FinancialInstitute (id, name, email, phoneNumber, site) 
        VALUES (:id, :name, :email, :phoneNumber, :site)''',
        parameters: financialInstitute);
    }

    if(close) await appDatabase.close();
  }

  /// Function to update inside database current accounts
  /// coming from a specific file [content]
  /// * [close] flag to close database
  Future<void> importCurrentAccounts(Map<String, dynamic> content, {bool close = false}) async {
    for(Map<String, dynamic> bankAccount in content['content']) {
      await appDatabase.executeWithMap(sql: '''INSERT OR REPLACE INTO BankAccount (id,
            financialInstitute, subscriptionDate, interest, endingDate, availableBalance, active, 
            startingDate, includeStart, timeFrequency, dayOfMonth, monthOfYear, lastDateActivity) 
            VALUES (:id, :financialInstitute, :subscriptionDate, :interest, :endingDate, 
            :availableBalance, :active, :startingDate, :includeStart, :timeFrequency, :dayOfMonth, :monthOfYear, 
            :lastDateActivity)''', parameters: bankAccount);
      await appDatabase.executeWithMap(sql: '''INSERT OR REPLACE INTO CurrentAccount
            (id, name) VALUES (:id, :name)''', parameters: bankAccount);
    }

    if(close) await appDatabase.close();
  }

  /// Function to update inside database savings accounts
  /// coming from a specific file [content]
  /// * [close] flag to close database
  Future<void> importSavingsAccounts(Map<String, dynamic> content, {bool close = false}) async {
    for(Map<String, dynamic> bankAccount in content['content']) {
      await appDatabase.executeWithMap(sql: '''INSERT OR REPLACE INTO BankAccount (id,
            subscriptionDate, interest, endingDate, availableBalance, active, 
            startingDate, includeStart, timeFrequency, dayOfMonth, monthOfYear, lastDateActivity,
            financialInstitute) VALUES (:id, :financialInstitute, :subscriptionDate, :interest, :endingDate, 
            :availableBalance, :active, :startingDate, :includeStart, :timeFrequency, :dayOfMonth, :monthOfYear, 
            :lastDateActivity,)''', parameters: bankAccount);
      await appDatabase.executeWithMap(sql: '''INSERT OR REPLACE INTO SavingsAccount
            (id, name, ledgerBalance) VALUES (:id, :name, :ledgerBalance)''', parameters: bankAccount);
    }

    if(close) await appDatabase.close();
  }

  /// Function to update inside database cards
  /// coming from a specific file [content]
  /// * [close] flag to close database
  Future<void> importCardAccounts(Map<String, dynamic> content, {bool close = false}) async {
    for(Map<String, dynamic> bankAccount in content['content']) {
      await appDatabase.executeWithMap(sql: '''INSERT OR REPLACE INTO Card (id,
            financialInstitute, subscriptionDate, interest, endingDate, availableBalance, active, 
            startingDate, includeStart, timeFrequency, dayOfMonth, monthOfYear, lastDateActivity) 
            VALUES (:id, :name, :financialInstitute, :subscriptionDate, :interest, :endingDate, 
            :availableBalance, :active, :startingDate, :includeStart, :timeFrequency, :dayOfMonth, :monthOfYear, :lastDateActivity)''', 
            parameters: bankAccount);
      await appDatabase.executeWithMap(sql: '''INSERT OR REPLACE INTO Card
            (id, name, cardType, dayOfMonthCredit, lastDateActivityCredit) 
            VALUES (:id, :name, :cardType, :dayOfMonthCredit, :lastDateActivityCredit)''', parameters: bankAccount);
    }

    if(close) await appDatabase.close();
  }

  /// Function to catch general bank accounts and save them
  /// inside each database coming from a file [content]
  /// * [close] flag to close the database
  Future<void> importBankAccounts(Map<String, dynamic> content, {bool close = false}) async {
    /* distribute the content of the file inside
    the respective tables of the database */
    await importCurrentAccounts(content['currentAccounts']);
    await importSavingsAccounts(content['savingsAccounts']);
    await importCardAccounts(content['cardAccounts']);

    if(close) await appDatabase.close();
  }

  /// Function to save incomes or update them inside the database
  /// from a specific file [content] given
  /// * [close] flag to close the database
  Future<void> importIncomes(Map<String, dynamic> content, {bool close = false}) async {
    for(Map<String, dynamic> transaction in content['content']){
      await appDatabase.executeWithMap(sql: '''INSERT INTO OR REPLACE INTO Income 
        (Income.id, reference, amount, executionDate, accountingDate, category, bankAccount, counterParty)
        VALUES (:id, :reference, :amount, :executionDate, :accountingDate, :category, :bankAccount, :counterParty)''',
        parameters: transaction);
    }

    if(close) await appDatabase.close();
  }

  /// Function to save outcomes or update them inside the database
  /// from a specific file [content] given
  /// * [close] flag to close the database
  Future<void> importOutcomes(Map<String, dynamic> content, {bool close = false}) async {
    for(Map<String, dynamic> transaction in content['content']){
      await appDatabase.executeWithMap(sql: '''INSERT INTO OR REPLACE INTO Outcome
        (id, reference, amount, executionDate, accountingDate, category, bankAccount, counterParty)
        VALUES (:id, :reference, :amount, :executionDate, :accountingDate, :category, :bankAccount, :counterParty)''',
        parameters: transaction);
    }

    if(close) await appDatabase.close();
  }

  /// Function to catch general transactions from a specific file [content]
  /// and save or update them inside the database
  /// * [close] flag to close the database
  Future<void> importTransactions(Map<String, dynamic> content, {bool close = false}) async {
    /* call the single functions to save 
    incomes and outcomes coming from cloud */
    await importIncomes(content['incomes']);
    await importOutcomes(content['outcomes']);

    if(close) await appDatabase.close();
  }

  /// Function to import cashbacks coming from a specific file [content]
  /// updating or saving them into the database
  /// * [close] flag to close the database
  Future<void> importCashbacks(Map<String, dynamic> content, {bool close = false}) async {
    for(Map<String, dynamic> billing in content['content']){
      await appDatabase.executeWithMap(sql: '''INSERT OR REPLACE INTO Cashback (id, name, description, amount, 
        startingDate, includeStart, timeFrequency, dayOfMonth, monthOfYear, lastDateActivity, bankAccount)
        VALUES (:id, :name, :description, :amount, :startingDate, :includeStart, :timeFrequency, :dayOfMonth,
        :monthOfYear, :lastDateActivity, :bankAccount)''', parameters: billing);
    }

    if(close) await appDatabase.close();
  }

  /// Function to import bank fees coming from a specific file [content]
  /// updating or saving them into the database
  /// * [close] flag to close the database
  Future<void> importBankFees(Map<String, dynamic> content, {bool close = false}) async {
    for(Map<String, dynamic> billing in content['content']){
      await appDatabase.executeWithMap(sql: '''INSERT OR REPLACE INTO BankFee (id, name, description, amount, 
        startingDate, includeStart, timeFrequency, dayOfMonth, monthOfYear, lastDateActivity, bankAccount)
        VALUES (:id, :name, :description, :amount, :startingDate, :includeStart, :timeFrequency, :dayOfMonth,
        :monthOfYear, :lastDateActivity, :bankAccount)''', parameters: billing);
    }

    if(close) await appDatabase.close();
  }

  /// Function to import periodic account billings coming from a file [content]
  /// and update the records of their specific tables in the database
  /// * [close] flag to close the database
  Future<void> importPeriodicAccountBillings(Map<String, dynamic> content, {bool close = false}) async {
    /* separate the the import of cashbacks from 
    the import of bank fees */
    await importCashbacks(content['cashbacks']);
    await importBankFees(content['bankFees']);

    if(close) await appDatabase.close();
  }

  /// Function to import domiciliation coming from a file [content]
  /// and update the records of the database
  /// * [close] flag to close the database
  Future<void> importPeriodicIncomes(Map<String, dynamic> content, {bool close = false}) async {
    for(Map<String, dynamic> periodicIncome in content['content']){
      await appDatabase.executeWithMap(sql: '''INSERT OR REPLACE INTO PeriodicIncome (id, name, description, amount,
        startingDate, includeStart, timeFrequency, dayOfMonth, monthOfYear, lastDateActivity, bankAccount, counterParty)
        VALUES (:id, :name, :description, :amount, :startingDate, :includeStart, :timeFrequency, :dayOfMonth, :monthOfYear,
        :lastDateActivity, :bankAccount, :counterParty)''', parameters: periodicIncome);
    }

    if(close) await appDatabase.close();
  }

  /// Function to import periodic income coming from a file [content]
  /// and update the records of the database
  /// * [close] flag to close the database
  Future<void> importDomiciliations(Map<String, dynamic> content, {bool close = false}) async {
    for(Map<String, dynamic> domiciliation in content['content']){
      await appDatabase.executeWithMap(sql: '''INSERT OR REPLACE INTO Domiciliation (Domiciliation.id, Domiciliation.name, description, amount, fee,
        startingDate, includeStart, timeFrequency, dayOfMonth, monthOfYear, lastDateActivity, bankAccount, counterParty)
        VALUES (:id, :name, :description, :amount, :fee, :startingDate, :includeStart, :timeFrequency, :dayOfMonth, :monthOfYear,
        :lastDateActivity, :bankAccount, :counterParty)''', parameters: domiciliation);
    }

    if(close) await appDatabase.close();
  }

  /// Function to import periodic transactions coming from a file [content].
  /// Then the records are saved inside the specific table of the database.
  /// * [close] flag to close the database
  Future<void> importPeriodicTransactions(Map<String, dynamic> content, {bool close = false}) async {
    /* separate the periodic transactions
    into domiciliations and periodic incomes */
    await importDomiciliations(content['domiciliations']);
    await importPeriodicIncomes(content['periodicIncomes']);

    if(close) await appDatabase.close();
  }

  /// Function to import bond models coming from specific file [content]
  /// and update records inside the dabase.
  /// * [close] flag to close database
  Future<void> importBondModels(Map<String, dynamic> content, {bool close = false}) async {
    for(Map<String, dynamic> bondModel in content['content']){
      await appDatabase.queryWithMap(sql: '''INSERT OR REPLACE INTO BondModel (BondModel.id, BondModel.name,
        provider, providerType, payoutFrequency, description, duration, taxRate, interestType)
        VALUES (:id, :name, :provider, :providerType, :payoutFrequency, :description, :duration, :taxRate, :interestType)''',
        parameters: bondModel);
    }

    if(close) await appDatabase.close();
  }

  /// Function to import time deposit models coming from specific file [content]
  /// and update records inside the dabase.
  /// * [close] flag to close database
  Future<void> importTimeDepositModels(Map<String, dynamic> content, {bool close = false}) async {
    for(Map<String, dynamic> timeDepositModel in content['content']){
      await appDatabase.queryWithMap(sql: '''INSERT OR REPLACE INTO TimeDepositModel (id, name,
        provider, providerType, payoutFrequency, description, duration, taxRate, 
        interestRate, earlyWithdrawalInterestRate, isCashable)
        VALUES (:id, :name, :provider, :providerType, :payoutFrequency, :description, :duration, :taxRate,
        :interestRate, :earlyWithdrawalInterestRate, :isCashable)''',
        parameters: timeDepositModel);
    }

    if(close) await appDatabase.close();
  }

  /// Function to import general financial instrument models 
  /// coming from a specific file [content] and save them 
  /// inside their specific tables inside the database.
  /// * [close] flag to close the database
  Future<void> importFinancialInstrumentModels(Map<String, dynamic> content, {bool close = false}) async {
    /* separate bond models from time deposit models
    and call the respective functions */
    await importTimeDepositModels(content['timeDepositModels']);
    await importBondModels(content['bondModels']);

    if(close) await appDatabase.close();
  }

  /// Function to import time deposits coming from a file [content]
  /// and update records inside the database
  /// * [close] flag to close the database
  Future<void> importTimeDeposits(Map<String, dynamic> content, {bool close = false}) async {
    for(Map<String, dynamic> timeDeposit in content['content']){
      await appDatabase.executeWithMap(sql: '''INSERT OR REPLACE INTO TimeDeposit (TimeDeposit.id, TimeDeposit.name,
        provider, providerType, instrumentUsed, initialValue, currentValue, taxRate, status, interestRate, earlyWithdrawalInterestRate, isCashable,
        startingDate, includeStart, timeFrequency, dayOfMonth, monthOfYear, lastDateActivity, endingDate, includeEnd, bankAccount)
        VALUES (:id, :name, :provider, :providerType, :instrumentUsed, :initialValue, :currentValue, :taxRate, :status, 
        :interestRate, :earlyWithdrawalInterestRate, :isCashable, :startingDate, :includeStart, :timeFrequency, :dayOfMonth,
        :monthOfYear, :lastDateActivity, :endingDate, :includeEnd, :bankAccount)''', parameters: timeDeposit);
    }

    if(close) await appDatabase.close();
  }

  /// Function to import bonds coming from a file [content]
  /// and update records inside the database
  /// * [close] flag to close the database
  Future<void> importBonds(Map<String, dynamic> content, {bool close = false}) async {
    for(Map<String, dynamic> bond in content['content']){
      await appDatabase.executeWithMap(sql: '''INSERT OR REPLACE INTO Bond (id, name,
        provider, providerType, instrumentUsed, initialValue, currentValue, taxRate, status, purchasePrice, interestType, minimumDenomination,
        startingDate, includeStart, timeFrequency, dayOfMonth, monthOfYear, lastDateActivity, endingDate, includeEnd, bankAccount)
        VALUES (:id, :name, :provider, :providerType, :instrumentUsed, :initialValue, :currentValue, :taxRate, :status, 
        :purchasePrice, :interestType, :minimumDenomination, :startingDate, :includeStart, :timeFrequency, :dayOfMonth,
        :monthOfYear, :lastDateActivity, :endingDate, :includeEnd, :bankAccount)''', parameters: bond);
    }

    if(close) await appDatabase.close();
  }

  /// Function to import stocks coming from a file [content]
  /// and update records inside the database
  /// * [close] flag to close the database
  Future<void> importStocks(Map<String, dynamic> content, {bool close = false}) async {
    for(Map<String, dynamic> stock in content['content']){
      await appDatabase.executeWithMap(sql: '''INSERT OR REPLACE INTO Stock (id, name,
        provider, providerType, instrumentUsed, initialValue, currentValue, taxRate, status, ticker, totalShares, 
        averagePurchasePrice, currency, totalDividends, startingDate, endingDate, bankAccount)
        VALUES (:id, :name, :provider, :providerType, :instrumentUsed, :initialValue, :currentValue, :taxRate, :status, 
        :ticker, :totalShares, :averagePurchasePrice, :currency, :totalDividends, :startingDate, :endingDate, :bankAccount)''', 
        parameters: stock);
    }

    if(close) await appDatabase.close();
  }

  /// Function to import general financial instruments coming from a file [content]
  /// and saving the records in the specific database
  /// * [close] flag to close the database
  Future<void> importFinancialInstruments(Map<String, dynamic> content, {bool close = false}) async {
    /* separate the financial instruments
    in time deposit, bonds and stocks
    with their own methods */
    await importTimeDeposits(content['timeDeposits']);
    await importBonds(content['bonds']);
    await importStocks(content['stocks']);

    if(close) await appDatabase.close();
  }

  /// Function to import step interests coming from a file [content]
  /// and save them in their own tables inside the database
  /// * [notModels] flag to indicate there is not interest on importing step interest related to bond models
  /// * [close] flag to close the database
  Future<void> importStepInterests(Map<String, dynamic> content, {bool notModels = false, bool close = false}) async {
    /* the first interests to save are the one
    related to bond models */
    for(Map<String, dynamic> interest in content['bondModels']){
      await appDatabase.executeWithMap(sql: '''INSERT OR REPLACE INTO StepInterestModel (position, interestRate, duration, bond)
        VALUES (:position, :interestRate, :duration, :bond)''', parameters: interest);
    }

    /* then do the same for the ones related to bonds */
    if(!notModels) {
      for(Map<String, dynamic> interest in content['bonds']){
        await appDatabase.executeWithMap(sql: '''INSERT OR REPLACE INTO StepInterest (position, interestRate, duration, bond)
          VALUES (:position, :interestRate, :duration, :bond)''', parameters: interest);
      }
    }

    if(close) await appDatabase.close();
  }
}