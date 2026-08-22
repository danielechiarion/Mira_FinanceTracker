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
}