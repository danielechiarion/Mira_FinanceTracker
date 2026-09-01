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
      duration = :duration, payoutFrequency = :payoutFrequency''',
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
      duration = :duration, payoutFrequency = :payoutFrequency, interestType = :interestType''',
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
}