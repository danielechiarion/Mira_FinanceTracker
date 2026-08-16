part of 'UserDatabaseWrapper.dart';

extension UserDatabaseWrapperReader on UserDatabaseWrapper{
  /// Function to read user preferences and return
  /// them with the objects provided by the application
  /// 
  /// * [close] flag to indicate if the database has to be closed at the end of the operation
  Future<List<SinglePreference>> readUserPreferences({bool close = false}) async{
    List<Map<String, dynamic>> result = await appDatabase.query(sql: 'SELECT name,value FROM application_preferences');

    /* create the list and cycle all the results to
    get the list of preferences */
    List<SinglePreference> userPreferences = [];
    for(Map<String, dynamic> map in result){
      userPreferences.add(SinglePreference.fromSharedPreference(map['name'], map['value']));
    }

    if(close){
      await appDatabase.close();
    }

    return userPreferences;
  }

  /// Function to get all the bank accounts 
  /// owned by the user
  /// 
  /// * [close] flag to indicate if the database has to be closed at the end of the operation
  Future<List<BankAccount>> getBankAccounts({bool close = false}) async {
    List<BankAccount> accountList = [];

    /* call all the single functions
    to get the different types of bank accounts */
    accountList.addAll(await getCurrentAccounts());
    accountList.addAll(await getSavingsAccounts());
    accountList.addAll(await getCardAccounts());

    if(close){
      appDatabase.close();
    }

    return accountList;
  }

  /// Function to get the list of current accounts
  /// owned by the user
  /// * [close] flag to indicate if the database has to be closed at the end of the operation
  Future<List<CurrentAccount>> getCurrentAccounts({bool close = false}) async {
    List<CurrentAccount> currentAccounts = []; // create the list

    /* get the query for the bank accounts */
    List<Map<String, dynamic>> result =  await appDatabase.query(sql: ''' SELECT CurrentAccount.id, CurrentAccount.name, 
            financialInstitute, subscriptionDate, interest, endingDate, availableBalance, active, 
            startingDate, includeStart, timeFrequency, dayOfMonth, monthOfYear, lastDateActivity,
            FinancialInstitute.name AS institute_name, email, phoneNumber, site
            FROM CurrentAccount JOIN BankAccount on BankAccount.id = CurrentAccount.id 
            JOIN FinancialInstitute ON BankAccount.financialInstitute = FinancialInstitute.id''');

    for(Map<String, dynamic> singleResult in result){
      /* create the map for the financial
      institute object */
      Map<String, dynamic> financialInstituteRaw = {
        'name': singleResult['institute_name'],
        'email': singleResult['email'],
        'phoneNumber': singleResult['phoneNumber'],
        'site': singleResult['site']
      };

      currentAccounts.add(CurrentAccount.fromMap(singleResult, [], [], [], [], [], 
                            FinancialInstitute.fromMap(financialInstituteRaw)));
    }

    if(close){
      appDatabase.close();
    }

    return currentAccounts;
  }

  /// Function to get the list of savings accounts
  /// owned by the user
  /// * [close] flag to indicate if the database has to be closed at the end of the operation
  Future<List<SavingsAccount>> getSavingsAccounts({bool close = false}) async {
    List<SavingsAccount> savingsAccounts = []; // create the list

    /* get the query for the bank accounts */
    List<Map<String, dynamic>> result =  await appDatabase.query(sql: ''' SELECT SavingsAccount.id, SavingsAccount.name, ledgerBalance,
            financialInstitute, subscriptionDate, interest, endingDate, availableBalance, active, 
            startingDate, includeStart, timeFrequency, dayOfMonth, monthOfYear, lastDateActivity,
            FinancialInstitute.name AS institute_name, email, phoneNumber, site
            FROM SavingsAccount JOIN BankAccount on BankAccount.id = SavingsAccount.id
            JOIN FinancialInstitute ON BankAccount.financialInstitute = FinancialInstitute.id''');

    for(Map<String, dynamic> singleResult in result){
      /* create the map for the financial
      institute object */
      Map<String, dynamic> financialInstituteRaw = {
        'name': singleResult['institute_name'],
        'email': singleResult['email'],
        'phoneNumber': singleResult['phoneNumber'],
        'site': singleResult['site']
      };

      savingsAccounts.add(SavingsAccount.fromMap(singleResult, [], [], [], [], 
                            FinancialInstitute.fromMap(financialInstituteRaw)));
    }

    if(close){
      appDatabase.close();
    }

    return savingsAccounts;
  }

  /// Function to get the list of cards
  /// owned by the user
  /// * [close] flag to indicate if the database has to be closed at the end of the operation
  Future<List<Card>> getCardAccounts({bool close = false}) async {
    List<Card> cardAccounts = []; // create the list

    /* get the query for the bank accounts */
    List<Map<String, dynamic>> result =  await appDatabase.query(sql: ''' SELECT Card.id, Card.name, cardType,
            financialInstitute, subscriptionDate, interest, endingDate, availableBalance, active, 
            startingDate, includeStart, timeFrequency, dayOfMonth, monthOfYear, lastDateActivity,
            FinancialInstitute.name AS institute_name, email, phoneNumber, site
            FROM Card JOIN BankAccount on BankAccount.id = Card.id
            JOIN FinancialInstitute ON BankAccount.financialInstitute = FinancialInstitute.id''');

    for(Map<String, dynamic> singleResult in result){
      /* create the map for the financial
      institute object */
      Map<String, dynamic> financialInstituteRaw = {
        'name': singleResult['institute_name'],
        'email': singleResult['email'],
        'phoneNumber': singleResult['phoneNumber'],
        'site': singleResult['site']
      };

      cardAccounts.add(Card.fromMap(singleResult, [], [], [], 
                            FinancialInstitute.fromMap(financialInstituteRaw)));
    }

    if(close){
      appDatabase.close();
    }

    return cardAccounts;
  }

  /// Function to get the latest transactions throughout all the 
  /// bank accounts looking for the date interval given
  /// * [startingDate] date to start the interval
  /// * [endingDate] date to end the interval
  /// * [limit] limit of the transactions to filter, automatically set to 50
  /// 
  /// * [close] flag to indicate if the database has to be closed at the end of the operation
  Future<List<BankTransaction>> getLatestTransactions({DateTime? startingDate, DateTime? endingDate, int limit = 50, bool close = false}) async {
    /* get the start date and end one
    if no input was provided */
    endingDate = endingDate ?? DateTime.now();
    startingDate = startingDate ?? endingDate.subtract(Duration(days: 365)); // go automatically to one-year time gap

    List<BankTransaction> transactions = []; // create the list

    /* first search inside the incomes, than
    do the same with the outcomes */
    List<Map<String, dynamic>> incomeResults = await appDatabase.query(sql: '''SELECT Income.id, reference, amount, executionDate, accountingDate, category,
          Counterparty.id AS counter_id, name AS counter_name, IBAN AS counter_IBAN
          FROM Income LEFT JOIN CounterParty ON Income.counterParty = CounterParty.id
          WHERE accountingDate >= ? AND executionDate <= ? LIMIT ?''', arguments: [startingDate.toIso8601String(), endingDate.toIso8601String(), limit]);
    for(Map<String, dynamic> singleIncome in incomeResults){
      transactions.add(Income.fromMap(singleIncome, counterParty: _getCounterPartyFromMap(singleIncome)));
    }

    List<Map<String, dynamic>> outcomeResults = await appDatabase.query(sql: '''SELECT Outcome.id, reference, amount, executionDate, accountingDate, category,
          Counterparty.id AS counter_id, name AS counter_name, IBAN AS counter_IBAN
          FROM Outcome LEFT JOIN CounterParty ON Outcome.counterParty = CounterParty.id
          WHERE accountingDate >= ? AND executionDate <= ? LIMIT ?''', arguments: [startingDate.toIso8601String(), endingDate.toIso8601String(), limit]);
    for(Map<String, dynamic> singleOutcome in outcomeResults){
      transactions.add(Income.fromMap(singleOutcome, counterParty: _getCounterPartyFromMap(singleOutcome)));
    }
    
    if(close){
      appDatabase.close();
    }
    
    transactions.sort(); // sort the transactions before sending them
    return transactions;
  }

  /* function to get a counterparty which inside of other 
  maps result coming from database manipulation. 
  Mind carefully how to name the map entries of the counterparty, 
  because different names from the one provided inside the function
  won't work. */
  CounterParty? _getCounterPartyFromMap(Map<String, dynamic> map){
    /* first control if the counterparty exists
    inside the map or has a null corresponding */
    if(map['counter_id'] == null){
      return null;
    }

    /* create the map for the counterparty
    gathering all the necessary data */
    Map<String, dynamic> counterPartyMap = {
      'id': map['counter_id'],
      'name': map['counter_name'],
      'IBAN': map['counter_IBAN']
    };

    return CounterParty.fromMap(counterPartyMap); // get the counterParty from map
  }

  /// Function to get the trends in the last months provided
  /// by the [monthTimeWindow] highlighting incomes and outcomes
  /// 
  /// * [close] flag to indicate if the database has to be closed at the end of the operation
  Future<List<MonthlyFlow>> getMonthsTrend({int monthTimeWindow = 6, bool close = false}) async {
    /* get the the first month time window
    to start, so the farthest one */
    DateTime currentDate = DateTime.now();
    DateTime startingDate = DateTime(currentDate.year, currentDate.month - monthTimeWindow, 1);
    DateTime endingDate = DateTime(startingDate.year, startingDate.month + 1, 0);

    List<MonthlyFlow> results = []; // create list to return results

    /* now cycle all the months and calculate
    for each one the trend acquired */
    for(int i=0; i<=monthTimeWindow; i++){
      if(i!=0){
        startingDate = DateTime(startingDate.year, startingDate.month+i, startingDate.day);
        endingDate = DateTime(endingDate.year, endingDate.month+i, endingDate.day);
      }

      /* get the sum of incomes and outcomes and 
      get the result */
      List<Map<String, dynamic>> incomeResult = await appDatabase.query(
        sql: 'SELECT SUM(amount) AS sum FROM Income WHERE accountingDate >= ? AND accountingDate <= ?',
        arguments: [startingDate.toIso8601String(), endingDate.toIso8601String()]
      );
      List<Map<String, dynamic>> outcomeResult = await appDatabase.query(
        sql: 'SELECT SUM(amount) AS sum FROM Outcome WHERE accountingDate >= ? AND accountingDate <= ?',
        arguments: [startingDate.toIso8601String(), endingDate.toIso8601String()]
      );

      Map<String, dynamic> incomeSum = incomeResult.isNotEmpty ? incomeResult.first : {'sum': 0};
      Map<String, dynamic> outcomeSum = outcomeResult.isNotEmpty ? outcomeResult.first : {'sum': 0};

      /* add the result to the list 
      with the name of the corresponding month */
      results.add(MonthlyFlow(monthLabel: DateFormat('MMM', 'it_IT').format(startingDate), income: incomeSum['sum'] ?? 0, outcome: outcomeSum['sum'] ?? 0));
    }

    if(close){
      appDatabase.close();
    }

    return results;
  }

  /// Function to get the patrimony distribution
  /// calculating the balance among all the bank accounts
  /// owned by the user
  /// 
  /// * [close] flag to indicate if the database has to be closed at the end of the operation
  Future<List<AccountShare>> getPatrimonyDistribution({bool close = false}) async {
    List<BankAccount> bankAccounts = await getBankAccounts(); // get the bank accounts
    List<AccountShare> distribution = []; // create list for the distribution of the patrimony

    /* for each bank account
    create the account share to give 
    to the pie chart */
    for(int i=0;i<bankAccounts.length;i++){
      distribution.add(AccountShare(label: bankAccounts[i].name, amount: bankAccounts[i].availableBalance, index: i));
    }

    return distribution; // return the distribution
  }
}