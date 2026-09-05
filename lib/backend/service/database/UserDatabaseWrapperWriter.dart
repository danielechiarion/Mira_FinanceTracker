part of 'UserDatabaseWrapper.dart';

extension UserDatabaseWrapperWriter on UserDatabaseWrapper{
  /// Function to save user preferences inside the database
  /// * [preferences] preferences to be saved
  /// * [close] flag to indicated if the database has to be closed at the end of the operations
  Future<void> saveUserPreferences(List<SinglePreference> preferences, {bool close = false}) async {
    /* because we don't know if some elements previously saved
    have been removed from the list, clear the table */
    await appDatabase.execute(sql: 'DELETE FROM application_preferences');

    /* then add the single preferences 
    inside the database */
    for(SinglePreference preference in preferences){
      await appDatabase.execute(sql: 'INSERT INTO application_preferences (name, value) VALUES (?,?)',
                              arguments: [preference.name, preference.toMapEntry().value]);
    }
  }

  /// Function to save transactions inside a bank account
  /// * [account] bank account to save the transactions
  /// * [transactions] list of transactions to save
  /// * [close] flag to indicate if the database should be closed at the end of the operations
  Future<void> saveTransactions(BankAccount account, List<BankTransaction> transactions, {bool close = false}) async {
    /* cycle all the transactions and update the 
    ID while doing the operations */
    int id;
    for(BankTransaction singleTransaction in transactions){
      if(singleTransaction is Income){
        id = await appDatabase.executeWithMap(
          sql: '''INSERT INTO Income (bankAccount, reference, counterParty, amount, executionDate, accountingDate, category)
                  VALUES (:bankAccount, :reference, :counterParty, :amount, :executionDate, :accountingDate, :category)''',
          parameters: {'bankAccount': account.id, ...singleTransaction.toMap()}
        );
      }else{
        id = await appDatabase.executeWithMap(
          sql: '''INSERT INTO Outcome (bankAccount, reference, counterParty, amount, executionDate, accountingDate, category)
                  VALUES (:bankAccount, :reference, :counterParty, :amount, :executionDate, :accountingDate, :category)''',
          parameters: {'bankAccount': account.id, ...singleTransaction.toMap()}
        );
      }
      singleTransaction.id = id;
    }

    if(close){
      await appDatabase.close();
    }
  }

  /// Function to save the counterparty inside the database
  /// * [counterParty] object to save
  /// * [close] flag to indicate when to close the database
  Future<void> saveCounterparty(CounterParty counterParty, {bool close = false}) async {
    await appDatabase.executeWithMap(sql: 'INSERT INTO CounterParty (name, IBAN) VALUES (:name, :IBAN)',
            parameters: {...counterParty.toMap()});

    if(close){
      await appDatabase.close();
    }
  }

  /// Function to delete the counterparty inside the database
  /// * [counterParty] object to be removed
  /// * [close] flag to indicate whether to close the database
  Future<void> deleteCounterparty(CounterParty counterParty, {bool close = false}) async {
    await appDatabase.execute(sql: 'DELETE FROM CounterParty WHERE name=?', arguments: [counterParty.name]);
    if(close){
      await appDatabase.close();
    }
  }

  /// Function to save a financial institute inside a database
  /// * [institute] institute to be saved
  /// * [close] flag to indicate if the database has to be closed
  Future<void> saveFinancialInstitute(FinancialInstitute institute, {bool close = false}) async {
    await appDatabase.executeWithMap(sql: ''' INSERT INTO FinancialInstitute (name, email, phoneNumber, site) 
            VALUES (:name, :email, :phoneNumber, :site)''', 
            parameters: {...institute.toMap()});

    if(close){
      await appDatabase.close();
    }
  }

  /// Function to delete a financial institute inside a database
  /// * [institute] institute to be deleted
  /// * [close] flag to indicate if the database has to be closed
  Future<void> deleteFinancialInstitute(FinancialInstitute institute, {bool close = false}) async {
    await appDatabase.execute(sql: 'DELETE FROM FinancialInstitute WHERE name = ?', arguments: [institute.name]);
    if(close){
      await appDatabase.close();
    }
  } 

  /* function to save information throughout all bank accounts
  in the common database in order to track unique IDs,
  which will be returned by the function */
  Future<int> _saveBankAccountInformation(BankAccount account) async {
    return await appDatabase.executeWithMap(sql: '''INSERT INTO BankAccount 
      (financialInstitute, subscriptionDate, interest, endingDate, availableBalance, active, IBAN,
      startingDate, includeStart, timeFrequency, dayOfMonth, monthOfYear, lastDateActivity)
      VALUES (:financialInstitute, :subscriptionDate, :interest, :endingDate, :availableBalance, :active, 
      :IBAN, :startingDate, :includeStart, :timeFrequency, :dayOfMonth, :monthOfYear, :lastDateActivity)''',
      parameters: account.toMap());
  }

  /// Function to save inside the database a
  /// current account not saving the entities connected to them. 
  /// For that ones call other functions. 
  /// * [account] current account to save
  /// * [close] flag to close the database
  Future<void> saveCurrentAccount(CurrentAccount account, {bool close = false}) async {
    /* first save information into general
    bank account database */
    int newId = await _saveBankAccountInformation(account);
    
    /* check the id, 
    if it's wrong return an exception in that case */
    if(newId < 0){
      throw Exception("DATABASE ERROR: CurrentAccount save didn't end well");
    }

    /* then save the information inside the 
    specific database of the current account */
    await appDatabase.execute(sql: 'INSERT INTO CurrentAccount (id, name) VALUES (?, ?)', 
      arguments: [newId, account.name]);

    if(close){
      await appDatabase.close();
    }
  }

  /// Function to save inside the database a
  /// savings account not saving the entities connected to them. 
  /// For that ones call other functions. 
  /// * [account] savings account to save
  /// * [close] flag to close the database
  Future<void> saveSavingsAccount(SavingsAccount account, {bool close = false}) async {
    /* first save information into general
    bank account database */
    int newId = await _saveBankAccountInformation(account);
    
    /* check the id, 
    if it's wrong return an exception in that case */
    if(newId < 0){
      throw Exception("DATABASE ERROR: Savings account save didn't end well");
    }

    /* then save the information inside the 
    specific database of the savings account */
    await appDatabase.execute(sql: 'INSERT INTO SavingsAccount (id, name, ledgerBalance) VALUES (?, ?, ?)', 
      arguments: [newId, account.name, account.ledgerBalance]);

    if(close){
      await appDatabase.close();
    }
  }

  /// Function to save inside the database a
  /// card account not saving the entities connected to them. 
  /// For that ones call other functions. 
  /// * [account] savings account to save
  /// * [close] flag to close the database
  Future<void> saveCardAccount(Card account, {bool close = false}) async {
    /* first save information into general
    bank account database */
    int newId = await _saveBankAccountInformation(account);
    
    /* check the id, 
    if it's wrong return an exception in that case */
    if(newId < 0){
      throw Exception("DATABASE ERROR: Savings account save didn't end well");
    }

    /* then save the information inside the 
    specific database of the savings account */
    await appDatabase.execute(sql: 'INSERT INTO Card (id, name, cardType, dayOfMonthCredit, lastDateActivityCredit) VALUES (?, ?, ?, ?, ?)', 
      arguments: [newId, account.name, account.cardType.index, account.creditTime?.dayOfMonth, account.creditTime?.lastDateActivity?.toIso8601String()]);

    if(close){
      await appDatabase.close();
    }
  }

  /// Function to save a cashback inside the bank account
  /// connected to it
  /// * [account] bank account connected to the billing
  /// * [cashback] cashback to save
  /// * [close] flag to close the database
  Future<void> saveAccountCashback(BankAccount account, Cashback cashback, {bool close = false}) async {
    await appDatabase.executeWithMap(sql: '''INSERT INTO Cashback (name, description, amount, startingDate, includeStart, timeFrequency, dayOfMonth, monthOfYear, lastDateActivity, bankAccount)
      VALUES (:name, :description, :amount, :startingDate, :includeStart, :timeFrequency, :dayOfMonth, :monthOfYear, :lastDateActivity, :bankAccount)''',
      parameters: {...cashback.toMap(), 'bankAccount': account.id});

    if(close){
      await appDatabase.close();
    }
  }

  /// Function to save a fee inside the bank account
  /// connected to it
  /// * [account] bank account connected to the billing
  /// * [fee] fee to save
  /// * [close] flag to close the database
  Future<void> saveAccountFee(BankAccount account, BankFee fee, {bool close = false}) async {
    await appDatabase.executeWithMap(sql: '''INSERT INTO BankFee (name, description, amount, startingDate, includeStart, timeFrequency, dayOfMonth, monthOfYear, lastDateActivity, bankAccount)
      VALUES (:name, :description, :amount, :startingDate, :includeStart, :timeFrequency, :dayOfMonth, :monthOfYear, :lastDateActivity, :bankAccount)''',
      parameters: {...fee.toMap(), 'bankAccount': account.id});

    if(close){
      await appDatabase.close();
    }
  }

  /// Function to save a periodic income 
  /// inside a current account in the database
  /// * [account] current account where to save the periodic income
  /// * [periodicIncome] entity to save
  /// * [close] flag to close the database
  Future<void> saveAccountPeriodicIncome(CurrentAccount account, PeriodicIncome periodicIncome, {bool close = false}) async {
    await appDatabase.executeWithMap(sql: '''INSERT INTO PeriodicIncome (name, description, amount, bankAccount,
      counterParty, includeStart, timeFrequency, startingDate, dayOfMonth, monthOfYear, lastDateActivity)
      VALUES (:name, :description, :amount, :bankAccount, :counterParty, :includeStart, :timeFrequency, :startingDate, :dayOfMonth, :monthOfYear, :lastDateActivity)''',
      parameters: {...periodicIncome.toMap(), 'bankAccount': account.id});

    if(close){
      await appDatabase.close();
    }
  }

  /// Function to save a domiciliation
  /// inside a current account in the database
  /// * [account] current account where to save the domiciliation
  /// * [domiciliation] entity to save
  /// * [close] flag to close the database
  Future<void> saveAccountDomiciliation(CurrentAccount account, Domiciliation domiciliation, {bool close = false}) async {
    await appDatabase.executeWithMap(sql: '''INSERT INTO Domiciliation (name, description, amount, bankAccount, fee,
      counterParty, includeStart, timeFrequency, startingDate, dayOfMonth, monthOfYear, lastDateActivity)
      VALUES (:name, :description, :amount, :bankAccount, :fee, :counterParty, :includeStart, :timeFrequency, :startingDate, :dayOfMonth, :monthOfYear, :lastDateActivity)''',
      parameters: {...domiciliation.toMap(), 'bankAccount': account.id});

    if(close){
      await appDatabase.close();
    }
  }

  /// Function to delete a time deposit model
  /// from database, without the control of related entities,
  /// which exists and has to be done before.
  /// * [model] model to delete
  /// * [close] flag to close the database
  Future<void> deleteTimeDepositModel(TimeDepositModel model, {bool close = false}) async {
    await appDatabase.execute(sql: 'DELETE FROM TimeDepositModel WHERE name = ?', arguments: [model.name]);

    if(close){
      await appDatabase.close();
    }
  }

  /// Function to delete a bond model
  /// from database, without the control of related entities,
  /// which exists and has to be done before.
  /// * [model] model to delete
  /// * [close] flag to close the database
  Future<void> deleteBondModel(BondModel model, {bool close = false}) async {
    await appDatabase.execute(sql: 'DELETE FROM BondModel WHERE name = ?', arguments: [model.name]);

    if(close){
      await appDatabase.close();
    }
  }

  /// Function to save time deposit model 
  /// inside the database
  /// * [model] model to save
  /// * [close] flag to close database
  Future<void> saveTimeDepositModel(TimeDepositModel model, {bool close = false}) async {
    await appDatabase.executeWithMap(sql: '''INSERT INTO TimeDepositModel (name, provider, providerType, 
      payoutFrequency, description, duration, taxRate, interestRate, earlyWithdrawalInterestRate, isCashable)
      VALUES (:name, :provider, :providerType, :payoutFrequency, :description, :duration, :taxRate, :interestRate,
      :earlyWithdrawalInterestRate, :isCashable)''',
      parameters: model.toMap());

    if(close){
      await appDatabase.close();
    }
  }

  /// Function to save bond model 
  /// inside the database and
  /// its related step interests
  /// * [model] model to save
  /// * [close] flag to close database
  Future<void> saveBondModel(BondModel model, {bool close = false}) async {
    final int insertedId = await appDatabase.executeWithMap(sql: '''INSERT INTO BondModel (name, provider, providerType, 
      payoutFrequency, description, duration, taxRate, interestType)
      VALUES (:name, :provider, :providerType, :payoutFrequency, :description, :duration, :taxRate, :interestType)''',
      parameters: model.toMap());
    model.id = insertedId;

    /* for each step interest
    save them into the database */
    for(StepInterest singleInterest in model.interests){
      await appDatabase.executeWithMap(sql: '''INSERT INTO StepInterestModel (position, bond, interestRate, duration)
        VALUES (:position, :bond, :interestRate, :duration)''',
        parameters: {'bond': model.id, ...singleInterest.toMap()});
    }

    if(close){
      await appDatabase.close();
    }
  }

  /// Function to save a time deposit related to the
  /// savings account selected inside the database
  /// * [account] savings account connected to the time deposit
  /// * [timeDeposit] service to save
  /// * [close] flag to close the database
  Future<void> saveAccountTimeDeposit(SavingsAccount account, TimeDeposit timeDeposit, {bool close = false}) async {
    await appDatabase.executeWithMap(sql: '''INSERT INTO TimeDeposit (name, provider, providerType, instrumentUsed,
      currentValue, initialValue, taxRate, status, interestRate, earlyWithdrawalInterestRate, isCashable, 
      startingDate, timeFrequency, includeStart, dayOfMonth, monthOfYear, lastDateActivity, endingDate, includeEnd,
      bankAccount) VALUES (:name, :provider, :providerType, :instrumentUsed,
      :currentValue, :initialValue, :taxRate, :status, :interestRate, :earlyWithdrawalInterestRate, :isCashable, 
      :startingDate, :timeFrequency, :includeStart, :dayOfMonth, :monthOfYear, :lastDateActivity, :endingDate, :includeEnd,
      :bankAccount)''', parameters: {...timeDeposit.toMap(), 'bankAccount': account.id});

    if(close){
      await appDatabase.close();
    }
  }

  /// Function to save a bond related to the
  /// savings account selected inside the database
  /// * [account] savings account connected to the bond
  /// * [bond] bond to save
  /// * [close] flag to close the database
  Future<void> saveAccountBond(SavingsAccount account, Bond bond, {bool close = false}) async {
    await appDatabase.transaction((transaction) async {
      final bondMap = bond.toMap();
      final insertedId = await transaction.rawInsert('''INSERT INTO Bond (name, provider, providerType, instrumentUsed,
        currentValue, initialValue, taxRate, status, purchasePrice, interestType, minimumDenomination,
        startingDate, timeFrequency, includeStart, dayOfMonth, monthOfYear, lastDateActivity, endingDate, includeEnd,
        bankAccount) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''', [
        bondMap['name'],
        bondMap['provider'],
        bondMap['providerType'],
        bondMap['instrumentUsed'],
        bondMap['currentValue'],
        bondMap['initialValue'],
        bondMap['taxRate'],
        bondMap['status'],
        bondMap['purchasePrice'],
        bondMap['interestType'],
        bondMap['minimumDenomination'],
        bondMap['startingDate'],
        bondMap['timeFrequency'],
        bondMap['includeStart'],
        bondMap['dayOfMonth'],
        bondMap['monthOfYear'],
        bondMap['lastDateActivity'],
        bondMap['endingDate'],
        bondMap['includeEnd'],
        account.id,
      ]);
      bond.id = insertedId;

      for (final singleInterest in bond.couponSchedule) {
        await transaction.rawInsert('''INSERT INTO StepInterest (position, bond, interestRate, duration)
          VALUES (?, ?, ?, ?)''', [
          singleInterest.position,
          bond.id,
          singleInterest.interestRate,
          singleInterest.duration.toString(),
        ]);
      }
    });

    if(close){
      await appDatabase.close();
    }
  }

  /// Function to save the stock related to the savings account
  /// inside the database
  /// * [account] savings account connected to the stock
  /// * [stock] stock to save
  /// * [close] flag to close the database
  Future<void> saveAccountStock(SavingsAccount account, Stock stock, {bool close = false}) async {
    await appDatabase.executeWithMap(sql: '''INSERT INTO STOCK (name, bankAccount, provider, providerType,
      instrumentUsed, initialValue, currentValue, taxRate, status, totalShares, averagePurchasePrice, currency,
      totalDividends, startingDate, endingDate, ticker)
      VALUES (:name, :bankAccount, :provider, :providerType, :instrumentUsed, :initialValue, :currentValue, 
      :taxRate, :status, :totalShares, :averagePurchasePrice, :currency, :totalDividends, :startingDate, :endingDate, :ticker)''',
      parameters: {...stock.toMap(), 'bankAccount': account.id});

    if(close){
      await appDatabase.close();
    }
  }
}