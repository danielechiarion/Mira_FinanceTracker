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
}