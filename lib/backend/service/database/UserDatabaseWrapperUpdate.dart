part of 'UserDatabaseWrapper.dart';

extension UserDatabaseWrapperUpdate on UserDatabaseWrapper{
  /// Function to update all the attributes connected to 
  /// a counterparty object
  /// * [counterParty] object to be updated
  /// * [close] flag to close the database
  Future<void> updateConterparty(CounterParty counterParty, {bool close = false}) async {
    await appDatabase.executeWithMap(sql: 'UPDATE CounterParty SET name=:name, IBAN=:IBAN WHERE id = :id',
            parameters: {...counterParty.toMap()});

    if(close){
      await appDatabase.close();
    }
  }

   /// Function to update all the attributes connected to 
  /// a financial institute object
  /// * [institute] object to be updated
  /// * [close] flag to close the database
  Future<void> updateFinancialInstitute(FinancialInstitute institute, {bool close = false}) async {
    await appDatabase.executeWithMap(sql: '''UPDATE FinancialInstitute SET email=:email, phoneNumber=:phoneNumber, site=:site
            WHERE id=:id''',
            parameters: {...institute.toMap()});

    if(close){
      await appDatabase.close();
    }
  }

  /// Function to save specifically the new balance
  /// of a bank account, including the ledger balance 
  /// for a savings account
  Future<void> updateBankAccountBalance(BankAccount account, {bool close = false}) async {
    await appDatabase.execute(sql: 'UPDATE BankAccount SET availableBalance=? WHERE id=?', 
      arguments: [account.availableBalance, account.id]);
    
    /* if the account is a savings one 
    update also the ledger balance */
    if(account is SavingsAccount){
      await appDatabase.execute(sql: 'UPDATE SavingsAccount SET ledgerBalance=? WHERE id=?',
        arguments: [account.ledgerBalance, account.id]);
    }

    if(close){
      await appDatabase.close();
    }
  }

  /// Function to update time deposit model inside the database
  /// * [model] model to update
  /// * [close] flag to close the database
  Future<void> updateTimeDepositModel(TimeDepositModel model, {bool close = false}) async {
    await appDatabase.executeWithMap(sql: '''UPDATE TimeDepositModel SET description = :description, taxRate = :taxRate,
      interestRate = :interestRate, isCashable = :isCashable, earlyWithdrawalInterestRate = :earlyWithdrawalInterestRate,
      duration = :duration, payoutFrequency = :payoutFrequency WHERE id = :id''',
      parameters: model.toMap());

    if(close){
      await appDatabase.close();
    }
  }

  /// Function to update bond model inside the database
  /// * [model] model to update
  /// * [close] flag to close the database
  Future<void> updateBondModel(BondModel model, {bool close = false}) async {
    await appDatabase.executeWithMap(sql: '''UPDATE BondModel SET description = :description, taxRate = :taxRate,
      duration = :duration, payoutFrequency = :payoutFrequency, interestType = :interestType WHERE id = :id''',
      parameters: model.toMap());
    
    /* to update the step interests
    delete the previous ones and add them again */
    await appDatabase.query(sql: 'DELETE FROM StepInterestModel WHERE bond = ?', arguments: [model.id]);
    for(StepInterest singleInterest in model.interests){
      await appDatabase.executeWithMap(sql: '''INSERT INTO StepInterestModel (position, bond, interestRate, duration)
        VALUES (:position, :bond, :interestRate, :duration)''',
        parameters: {'bond': model.id, ...singleInterest.toMap()});
    }

    if(close){
      await appDatabase.close();
    }
  }

  /// Function to update [account] services
  /// after checking the values inside 
  /// the background activities
  /// * [close] flag to close the database
  Future<void> updateAccountServices(BankAccount account, {bool close = false}) async {
    await _updatePeriodicAccountBillings(account); // first update things common to all bank accounts

    /* then update services based on the 
    bank account type */
    if(account is CurrentAccount){
      await _updateCurrentAccountPeriodicTransactions(account);
    }else if(account is SavingsAccount){
      await _updateSavingsAccountFinancialInstruments(account);
    }

    if(close){
      await appDatabase.close();
    }
  }

  /* function to update periodic account billings 
  related to a bank account */
  Future<void> _updatePeriodicAccountBillings(BankAccount account) async {
    for(Cashback cashback in account.cashbacks){
      await updateAccountCashback(cashback);
    }

    for(BankFee bankFee in account.fees){
      await updateAccountFee(bankFee);
    }
  }

  /* function to update periodic transactions
  related to a bank account */
  Future<void> _updateCurrentAccountPeriodicTransactions(CurrentAccount account) async {
    for(PeriodicIncome income in account.periodicIncomes){
      await updateCurrentAccountPeriodicIncome(income);
    }

    for(Domiciliation domiciliation in account.domiciliations){
      await updateCurrentAccountDomiciliation(domiciliation);
    }
  }

  /* function to update financial instrument services of all types
  related to a savings account */
  Future<void> _updateSavingsAccountFinancialInstruments(SavingsAccount account) async {
    for(FinancialInstrument service in account.financialServices){
      if(service is TimeDeposit) {
        await updateSavingsAccountTimeDeposit(service);
      }
      else if(service is Bond) {
        await updateSavingsAccountBondSimple(service);
      }else{
        await updateSavingsAccountStock(service as Stock);
      }
    }
  }

  /// Function to update [cashback] related to a specific bank account
  /// * [close] flag to close the database
  Future<void> updateAccountCashback(Cashback cashback, {bool close = false}) async {
    await appDatabase.executeWithMap(sql: '''UPDATE Cashback SET description = :description, amount = :amount,
      startingDate = :startingDate, includeStart = :includeStart, timeFrequency = :timeFrequency, 
      dayOfMonth = :dayOfMonth, monthOfYear = :monthOfYear, lastDateActivity = :lastDateActivity 
      WHERE id = :id''', parameters: cashback.toMap());

    if(close){
      await appDatabase.close();
    }
  }

  /// Function to update [fee] related to a specific bank account
  /// * [close] flag to close the database
  Future<void> updateAccountFee(BankFee fee, {bool close = false}) async {
    await appDatabase.executeWithMap(sql: '''UPDATE BankFee SET description = :description, amount = :amount,
      startingDate = :startingDate, includeStart = :includeStart, timeFrequency = :timeFrequency, 
      dayOfMonth = :dayOfMonth, monthOfYear = :monthOfYear, lastDateActivity = :lastDateActivity 
      WHERE id = :id''', parameters: fee.toMap());

    if(close){
      await appDatabase.close();
    }
  }

  /// Function to update [domiciliation] related to a specific current account
  /// * [close] flag to close the database
  Future<void> updateCurrentAccountDomiciliation(Domiciliation domiciliation, {bool close = false}) async {
    await appDatabase.executeWithMap(sql: '''UPDATE Domiciliation SET description = :description, amount = :amount,
      counterParty = :counterParty, fee = :fee, startingDate = :startingDate, includeStart = :includeStart, 
      timeFrequency = :timeFrequency, dayOfMonth = :dayOfMonth, monthOfYear = :monthOfYear, lastDateActivity = :lastDateActivity 
      WHERE id = :id''', parameters: domiciliation.toMap());

    if(close){
      await appDatabase.close();
    }
  }

  /// Function to update periodic [income] related to a specific current account
  /// * [close] flag to close the database
  Future<void> updateCurrentAccountPeriodicIncome(PeriodicIncome income, {bool close = false}) async {
    await appDatabase.executeWithMap(sql: '''UPDATE PeriodicIncome SET description = :description, amount = :amount,
      counterParty = :counterParty, startingDate = :startingDate, includeStart = :includeStart, 
      timeFrequency = :timeFrequency, dayOfMonth = :dayOfMonth, monthOfYear = :monthOfYear, lastDateActivity = :lastDateActivity 
      WHERE id = :id''', parameters: income.toMap());

    if(close){
      await appDatabase.close();
    }
  }

  /// Function to update time [deposit] related to a savings account
  /// * [close] flag to close the database
  Future<void> updateSavingsAccountTimeDeposit(TimeDeposit deposit, {bool close = false}) async {
    await appDatabase.executeWithMap(sql: '''UPDATE TimeDeposit SET providerType = :providerType, provider = :provider,
      initialValue = :initialValue, currentValue = :currentValue, taxRate = :taxRate, status = :status, 
      interestRate = :interestRate, earlyWithrawalInterestRate = :earlyWithrawalInterestRate, isCashable= :isCashable,
      startingDate = :startingDate, includeStart = :includeStart, timeFrequency = :timeFrequency, dayOfMonth = :dayOfMonth, 
      monthOfYear = :monthOfYear, lastDateActivity = :lastDateActivity, endingDate = :endingDate, includeEnd = :includeEnd
      WHERE id = :id''', parameters: deposit.toMap());

    if(close){
      await appDatabase.close();
    }
  }

  /// Function to update [bond] related to a savings account
  /// without changing the step interest, that's why its called a simple update
  /// * [close] flag to close the database
  Future<void> updateSavingsAccountBondSimple(Bond bond, {bool close = false}) async {
    await appDatabase.executeWithMap(sql: '''UPDATE Bond SET providerType = :providerType, provider = :provider,
      initialValue = :initialValue, currentValue = :currentValue, taxRate = :taxRate, status = :status, 
      purchasePrice = :purchasePrice, interestType = :interestType, minimumDenomination = :minimumDenomination,
      startingDate = :startingDate, includeStart = :includeStart, timeFrequency = :timeFrequency, dayOfMonth = :dayOfMonth, 
      monthOfYear = :monthOfYear, lastDateActivity = :lastDateActivity, endingDate = :endingDate, includeEnd = :includeEnd
      WHERE id = :id''', parameters: bond.toMap());

    if(close){
      await appDatabase.close();
    }
  }

  /// Function to update data related to a [bond] saved in a bank account
  /// and the information related to it, such as the step interest
  /// * [close] flag to close the database
  Future<void> updateSavingsAccountBondComplete(Bond bond, {bool close = false}) async {
    await updateSavingsAccountBondSimple(bond); // first save essential information of bonds

    /* now update step interests. 
    Because we don't know if the number has increased or reduce before,
    or wheter the previous order of interests has changed, 
    we erase all the step interests related to the bond and we rewrite it */
    await appDatabase.execute(sql: 'DELETE FROM StepInterest WHERE bond = ?', arguments: [bond.id]);
    for (final singleInterest in bond.couponSchedule) {
      await appDatabase.execute(sql:'''INSERT INTO StepInterest (position, bond, interestRate, duration)
        VALUES (?, ?, ?, ?)''', arguments: [
        singleInterest.position,
        bond.id,
        singleInterest.interestRate,
        singleInterest.duration.toString(),
      ]);
    }
  }

  /// Function to update [stock] related to a savings account
  /// * [close] flag to close the database
  Future<void> updateSavingsAccountStock(Stock stock, {bool close = false}) async {
    await appDatabase.executeWithMap(sql: '''UPDATE TimeDeposit SET providerType = :providerType, provider = :provider,
      initialValue = :initialValue, currentValue = :currentValue, taxRate = :taxRate, status = :status, 
      ticker = :ticker, totalShares = :totalShares, averagePurchasePrice = :averagePurchasePrice,
      currency = :currency, totalDividends = :totalDividends, startingDate = :startingDate, endingDate = :endingDate
      WHERE id = :id''', parameters: stock.toMap());

    if(close){
      await appDatabase.close();
    }
  }

  /// Function to save changes made to a bank [account]
  /// permanently inside the database
  /// * [close] flag to close the database
  Future<void> updateAccountInformation(BankAccount account, {bool close = false}) async {
    await updateBankAccountBalance(account); // first update the balance 

    /* then update the other information 
    related to the bank account */
    await appDatabase.executeWithMap(sql: '''UPDATE BankAccount SET active = :active, IBAN = :IBAN, interest = :interest
      WHERE id = :id''', parameters: account.toMap());

    if(close){
      await appDatabase.close();
    }
  }
}