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
        'id': singleResult['financialInstitute'],
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
        'id': singleResult['financialInstitute'],
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
    List<Map<String, dynamic>> result =  await appDatabase.query(sql: ''' SELECT Card.id, Card.name,
            financialInstitute, subscriptionDate, interest, endingDate, availableBalance, active, 
            startingDate, includeStart, timeFrequency, dayOfMonth, monthOfYear, lastDateActivity,
            FinancialInstitute.name AS institute_name, email, phoneNumber, site,
            cardType, dayOfMonthCredit, lastDateActivityCredit
            FROM Card JOIN BankAccount on BankAccount.id = Card.id
            JOIN FinancialInstitute ON BankAccount.financialInstitute = FinancialInstitute.id''');

    for(Map<String, dynamic> singleResult in result){
      /* create the map for the financial
      institute object */
      Map<String, dynamic> financialInstituteRaw = {
        'id': singleResult['financialInstitute'],
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
      transactions.add(Outcome.fromMap(singleOutcome, counterParty: _getCounterPartyFromMap(singleOutcome)));
    }
    
    if(close){
      await appDatabase.close();
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
    /* Build each interval independently so months with different lengths
    do not shift the end date into the following month. */
    DateTime currentDate = DateTime.now();

    List<MonthlyFlow> results = []; // create list to return results

    for(int i=0; i<=monthTimeWindow; i++){
      final startingDate = DateTime(currentDate.year, currentDate.month - monthTimeWindow + i, 1);
      final endingDate = DateTime(startingDate.year, startingDate.month + 1, 1);

      /* get the sum of incomes and outcomes and 
      get the result.
      Exclude the internal transfers in order not to add more money
      to the counter */
      List<Map<String, dynamic>> incomeResult = await appDatabase.query(
        sql: 'SELECT SUM(amount) AS sum FROM Income WHERE accountingDate >= ? AND accountingDate < ? AND category != ?',
        arguments: [startingDate.toIso8601String(), endingDate.toIso8601String(), IncomeCategory.internal_transfer.index]
      );
      List<Map<String, dynamic>> outcomeResult = await appDatabase.query(
        sql: 'SELECT SUM(amount) AS sum FROM Outcome WHERE accountingDate >= ? AND accountingDate < ? AND category != ?',
        arguments: [startingDate.toIso8601String(), endingDate.toIso8601String(), OutcomeCategory.internal_transfer.index]
      );

      Map<String, dynamic> incomeSum = incomeResult.isNotEmpty ? incomeResult.first : {'sum': 0};
      Map<String, dynamic> outcomeSum = outcomeResult.isNotEmpty ? outcomeResult.first : {'sum': 0};

      /* add the result to the list 
      with the name of the corresponding month */
      results.add(MonthlyFlow(monthLabel: DateFormat('MMM', 'it_IT').format(startingDate), income: incomeSum['sum'] ?? 0, outcome: outcomeSum['sum'] ?? 0));
    }

    if(close){
      await appDatabase.close();
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
      distribution.add(AccountShare(label: bankAccounts[i].name, amount: bankAccounts[i] is SavingsAccount ? (bankAccounts[i] as SavingsAccount).ledgerBalance : bankAccounts[i].availableBalance, index: i));
    }

    return distribution; // return the distribution
  }

  /// Function to return the complete list of counterparties
  /// registered inside the database
  Future<List<CounterParty>> getCounterParties({bool close = false}) async {
    List<CounterParty> contacts = [];

    /* call the database to find all 
    the contacts inside the database */
    List<Map<String, dynamic>> result = await appDatabase.query(sql: 'SELECT id,name,IBAN FROM CounterParty');

    /* then fetch all the results and 
    return the list of contacts */
    for(Map<String, dynamic> map in result){
      contacts.add(CounterParty.fromMap(map));
    }

    if(close){
      await appDatabase.close();
    }

    return contacts;
  }

  /// Function to check if the counterparty name is available to
  /// be chosen among the one already inserted
  /// * [name] name to be inserted
  Future<bool> checkCounterpartyAvailability(String name) async {
    /* check the result coming
    from the database */
    final result = await appDatabase.query(
      sql: 'SELECT EXISTS(SELECT 1 FROM CounterParty WHERE name = ?) AS counter_exists',
      arguments: [name],
    );

    if (result.isNotEmpty) {
      return result.first['counter_exists'] != 1;
    }

    return false;
  }

  /// Function to get the complete list of financial institutes
  /// coming from the database
  /// * [close] flag to indicate if the database has to be closed
  Future<List<FinancialInstitute>> getFinancialInstitutes({bool close = false}) async {
    List<FinancialInstitute> institutes = [];

    /* call the database to find
    all the financial institutes occurencies */
    List<Map<String, dynamic>> result = await appDatabase.query(sql: 'SELECT id, name, email, phoneNumber, site FROM FinancialInstitute');

    /* convert all the maps into
    a list of financial institutes */
    for(Map<String, dynamic> map in result){
      institutes.add(FinancialInstitute.fromMap(map));
    }

    if(close){
      await appDatabase.close();
    }

    return institutes;
  }

  /// Function to check if the financial institute name 
  /// is available and return a boolean result
  /// * [name] name to be checked
  /// * [close] flag to indicate if the database has to be closed
  Future<bool> checkFinancialInstituteAvailability(String name, {bool close = false}) async {
    /* check the result coming
    from the database */
    final result = await appDatabase.query(
      sql: 'SELECT EXISTS(SELECT 1 FROM FinancialInstitute WHERE name = ?) AS institute_exists',
      arguments: [name],
    );

    if (result.isNotEmpty) {
      return result.first['institute_exists'] != 1;
    }

    return false;
  }

  /// Function to check if a counterparty object can be deleted.
  /// That means that there is no other entity which is related to it,
  /// otherwise it wouldn't be possible to delete it, because that data could be orphan
  /// * [counterParty] object to check
  /// * [close] flag to close the database
  Future<bool> checkCounterPartyDeletion(CounterParty counterParty, {bool close = false}) async {
    List<Map<String, dynamic>> result;
    
    /* first control inside 
    incomes and outcomes. 
    If anywhere compares the counterparty signal it's not possible 
    to erase it */
    result = await appDatabase.query(sql: 'SELECT COUNT(id) AS counter FROM Income WHERE counterParty = ?',
                      arguments: [counterParty.identifier]);
    if(_checkCounterField(result, 'counter')){
      return false;
    }
    result = await appDatabase.query(sql: 'SELECT COUNT(id) AS counter FROM Outcome WHERE counterParty = ?',
                      arguments: [counterParty.identifier]);
    if(_checkCounterField(result, 'counter')){
      return false;
    }

    /* then check among periodic income and 
    domiciliation, to make sure nothing 
    is related to the counterparty */
    result = await appDatabase.query(sql: 'SELECT COUNT(id) AS counter FROM PeriodicIncome WHERE counterParty = ?',
                      arguments: [counterParty.identifier]);
    if(_checkCounterField(result, 'counter')){
      return false;
    }
    result = await appDatabase.query(sql: 'SELECT COUNT(id) AS counter FROM Domiciliation WHERE counterParty = ?',
                      arguments: [counterParty.identifier]);
    if(_checkCounterField(result, 'counter')){
      return false;
    }

    if(close){
      await appDatabase.close();
    }

    return true;
  }

  /// Function to check if a financial institute object can be deleted.
  /// That means that there is no other entity which is related to it,
  /// otherwise it wouldn't be possible to delete it, because that data could be orphan
  /// * [financialInstitute] object to check
  /// * [close] flag to close the database
  Future<bool> checkFinancialInstituteDeletion(FinancialInstitute financialInstitute, {bool close = false}) async {
    List<Map<String, dynamic>> result;

    /* first check if there is something registered
    into the bank accounts */
    result = await appDatabase.query(sql: 'SELECT COUNT(id) AS counter FROM BankAccount WHERE financialInstitute = ?',
                      arguments: [financialInstitute.id]);
    if(_checkCounterField(result, 'counter')){
      return false;
    }

    /* then check among the 
    financial instrument models
    registered by the user */
    result = await appDatabase.query(sql: 'SELECT COUNT(id) AS counter FROM TimeDepositModel WHERE provider = ?',
                      arguments: [financialInstitute.id]);
    if(_checkCounterField(result, 'counter')){
      return false;
    }
    result = await appDatabase.query(sql: 'SELECT COUNT(id) AS counter FROM BondModel WHERE provider = ?',
                      arguments: [financialInstitute.id]);
    if(_checkCounterField(result, 'counter')){
      return false;
    }

    /* then check between the actual
    financial instruments and services 
    purchased by the user */
    result = await appDatabase.query(sql: 'SELECT COUNT(id) AS counter FROM TimeDeposit WHERE provider = ?',
                      arguments: [financialInstitute.id]);
    if(_checkCounterField(result, 'counter')){
      return false;
    }
    result = await appDatabase.query(sql: 'SELECT COUNT(id) AS counter FROM Bond WHERE provider = ?',
                      arguments: [financialInstitute.id]);
    if(_checkCounterField(result, 'counter')){
      return false;
    }

    return true;
  }

  /* function to check if the counter
  is positive, so elements have been found */
  bool _checkCounterField(List<Map<String, dynamic>> map, String counterFieldName){
    return map[0][counterFieldName] != 0;
  }

  /// Function to get the list of fees
  /// connected to a bank account
  /// * [account] bank account selected
  /// * [close] flag to close database
  Future<List<BankFee>> getAccountFees(BankAccount account, {bool close = false}) async {
    List<Map<String, dynamic>> result = [];

    /* get the query to get the account fees
    from the database */
    result = await appDatabase.query(sql: '''SELECT id, name, description, amount, startingDate, includeStart, timeFrequency, dayOfMonth, monthOfYear, lastDateActivity
      FROM BankFee WHERE bankAccount = ?''',
      arguments: [account.id]);

    /* parse all the data and generate
    the list of bank fees */
    List<BankFee> fees = [];
    for(Map<String, dynamic> singleResult in result){
      fees.add(BankFee.fromMap(singleResult));
    }

    if(close){
      await appDatabase.close();
    }

    return fees;
  }

  /// Function to get the list of cashbacks
  /// connected to a bank account
  /// * [account] bank account selected
  /// * [close] flag to close database
  Future<List<Cashback>> getAccountCashbacks(BankAccount account, {bool close = false}) async {
    List<Map<String, dynamic>> result = [];

    /* get the query to get the account cashbacks
    from the database */
    result = await appDatabase.query(sql: '''SELECT id, name, description, amount, startingDate, includeStart, timeFrequency, dayOfMonth, monthOfYear, lastDateActivity
      FROM Cashback WHERE bankAccount = ?''',
      arguments: [account.id]);

    /* parse all the data and generate
    the list of bank cashbacks */
    List<Cashback> fees = [];
    for(Map<String, dynamic> singleResult in result){
      fees.add(Cashback.fromMap(singleResult));
    }

    if(close){
      await appDatabase.close();
    }

    return fees;
  }

  /// Function to get the periodic incomes from the database
  /// with all the entities connected to them
  /// * [account] current account where to extract periodic incomes
  Future<List<PeriodicIncome>> getAccountPeriodicIncomes(CurrentAccount account, {bool close = false}) async {
    List<PeriodicIncome> periodicIncomes = [];
    /* get the list of periodic incomes
    from the database with related entities */
    List<Map<String, dynamic>> result = await appDatabase.query(sql: '''
      SELECT PeriodicIncome.id, PeriodicIncome.name, description, amount, 
      startingDate, includeStart, timeFrequency, dayOfMonth, monthOfYear, lastDateActivity,
      Counterparty.id AS counter_id, CounterParty.name AS counter_name, IBAN AS counter_IBAN
      FROM PeriodicIncome JOIN CounterParty ON CounterParty.id = PeriodicIncome.counterParty
      WHERE bankAccount = ? ''', arguments: [account.id]);
    
    for(Map<String, dynamic> singleResult in result){
      periodicIncomes.add(PeriodicIncome.fromMap(singleResult, _getCounterPartyFromMap(singleResult)!));
    }

    if(close){
      await appDatabase.close();
    }

    return periodicIncomes;
  }

  /// Function to get the domiciliations from the database
  /// with all the entities connected to them
  /// * [account] current account where to extract domiciliations
  Future<List<Domiciliation>> getAccountDomiciliations(CurrentAccount account, {bool close = false}) async {
    List<Domiciliation> domiciliations = [];
    /* get the list of periodic incomes
    from the database with related entities */
    List<Map<String, dynamic>> result = await appDatabase.query(sql: '''
      SELECT Domiciliation.id, Domiciliation.name, description, amount, fee,
      startingDate, includeStart, timeFrequency, dayOfMonth, monthOfYear, lastDateActivity,
      Counterparty.id AS counter_id, CounterParty.name AS counter_name, IBAN AS counter_IBAN
      FROM Domiciliation JOIN CounterParty ON CounterParty.id = Domiciliation.counterParty
      WHERE bankAccount = ? ''', arguments: [account.id]);
    
    for(Map<String, dynamic> singleResult in result){
      domiciliations.add(Domiciliation.fromMap(singleResult, _getCounterPartyFromMap(singleResult)!));
    }

    if(close){
      await appDatabase.close();
    }

    return domiciliations;
  }

  /// Function to get time deposit models saved inside the database
  /// * [close] flag to close the database
  Future<List<TimeDepositModel>> getTimeDepositModels({bool close = false}) async {
    /* get the elements using database query */
    List<Map<String, dynamic>> result = await appDatabase.query(sql: '''SELECT TimeDepositModel.id, TimeDepositModel.name,
      provider, providerType, payoutFrequency, description, duration, taxRate, interestRate, earlyWithdrawalInterestRate, isCashable,
      FinancialInstitute.name AS institute_name, email, phoneNumber, site
      FROM TimeDepositModel LEFT JOIN FinancialInstitute ON TimeDepositModel.provider = FinancialInstitute.id''');

    List<TimeDepositModel> timeDepositModels = [];
    for(Map<String, dynamic> singleResult in result){
      /* create the map for the financial
      institute object only if there is a connection */
      FinancialInstitute? provider;
      if(singleResult['provider'] != null){
        Map<String, dynamic> financialInstituteRaw = {
          'id': singleResult['provider'],
          'name': singleResult['institute_name'],
          'email': singleResult['email'],
          'phoneNumber': singleResult['phoneNumber'],
          'site': singleResult['site']
        };
        provider = FinancialInstitute.fromMap(financialInstituteRaw);
      }

      timeDepositModels.add(TimeDepositModel.fromMap(singleResult, provider));
    }

    if(close){
      await appDatabase.close();
    }

    return timeDepositModels;
  }

  /// Function to get bond models saved inside the database
  /// * [close] flag to close the database
  Future<List<BondModel>> getBondModels({bool close = false}) async {
    /* database query to get only the bond model object */
    List<Map<String, dynamic>> result = await appDatabase.query(sql: '''SELECT BondModel.id, BondModel.name,
      provider, providerType, payoutFrequency, description, duration, taxRate, interestType,
      FinancialInstitute.name AS institute_name, email, phoneNumber, site
      FROM BondModel LEFT JOIN FinancialInstitute ON BondModel.provider = FinancialInstitute.id''');

    List<BondModel> bondModels = [];

    for(Map<String, dynamic> singleResult in result){
      /* create the map for the financial
      institute object only if there is a connection */
      FinancialInstitute? provider;
      if(singleResult['provider'] != null){
        Map<String, dynamic> financialInstituteRaw = {
          'id': singleResult['provider'],
          'name': singleResult['institute_name'],
          'email': singleResult['email'],
          'phoneNumber': singleResult['phoneNumber'],
          'site': singleResult['site']
        };
        provider = FinancialInstitute.fromMap(financialInstituteRaw);
      }

      /* now for each bond model
      gets its interests */
      List<StepInterest> interests = [];
      List<Map<String, dynamic>> rawInterests = await appDatabase.query(sql: '''SELECT position, interestRate, duration
        FROM StepInterestModel WHERE bond = ?''', arguments: [singleResult['id']]);
      for(Map<String, dynamic> singleInterest in rawInterests){
        interests.add(StepInterest.fromMap(singleInterest));
      }

      /* now, with all the required elements
      it's possible to finally add the bond model
      to the corresponding list */
      interests.sort();
      bondModels.add(BondModel.fromMap(singleResult, provider, interests.toSet()));
    }

    if(close){
      await appDatabase.close();
    }

    return bondModels;
  }

  /// Function to check if the name is available
  /// inside the list of time deposit models
  /// saved inside the database
  /// * [name] name to check
  Future<bool> checkTimeDepositModelNameAvailability(String name) async{
    /* get the query from the database */
    List<Map<String, dynamic>> result = await appDatabase.query(
      sql: 'SELECT EXISTS(SELECT 1 FROM TimeDepositModel WHERE name = ?) AS model_exists',
      arguments: [name],
    );

    if(result.isNotEmpty){
      return result.first['model_exists'] != 1;
    }

    return false;
  }

  /// Function to check if the name is available
  /// inside the list of bond models
  /// saved inside the database
  /// * [name] name to check
  Future<bool> checkBondModelNameAvailability(String name) async{
    /* get the query from the database */
    List<Map<String, dynamic>> result = await appDatabase.query(
      sql: 'SELECT EXISTS(SELECT 1 FROM BondModel WHERE name = ?) AS model_exists',
      arguments: [name],
    );

    if(result.isNotEmpty){
      return result.first['model_exists'] != 1;
    }

    return false;
  }

  /// Function to check if the name is available
  /// inside the list of time deposits saved in the database
  /// * [name] name to check
  Future<bool> checkTimeDepositNameAvailability(String name) async{
    List<Map<String, dynamic>> result = await appDatabase.query(
      sql: 'SELECT EXISTS(SELECT 1 FROM TimeDeposit WHERE LOWER(name) = LOWER(?)) AS deposit_exists',
      arguments: [name],
    );

    if(result.isNotEmpty){
      return result.first['deposit_exists'] != 1;
    }

    return false;
  }

  /// Function to check if the name is available
  /// inside the list of bonds saved in the database
  /// * [name] name to check
  Future<bool> checkBondNameAvailability(String name) async{
    List<Map<String, dynamic>> result = await appDatabase.query(
      sql: 'SELECT EXISTS(SELECT 1 FROM Bond WHERE LOWER(name) = LOWER(?)) AS bond_exists',
      arguments: [name],
    );

    if(result.isNotEmpty){
      return result.first['bond_exists'] != 1;
    }

    return false;
  }

  /// Function to check if a time deposit model can be deleted,
  /// which means that has no entities connected to it
  /// * [model] model to control
  Future<bool> checkTimeDepositModelDeletion(TimeDepositModel model) async {
    /* make the query to count how many entities are
    connected to the model */
    List<Map<String, dynamic>> result = await appDatabase.query(sql: '''SELECT COUNT(id) AS counter
      FROM TimeDeposit WHERE instrumentUsed = ?''',
      arguments: [model.name]);

    return !_checkCounterField(result, 'counter');
  }

  /// Function to check if a bond model can be deleted,
  /// which means that has no entities connected to it
  /// * [model] model to control
  Future<bool> checkBondModelDeletion(BondModel model) async {
    /* make the query to count how many entities are
    connected to the model */
    List<Map<String, dynamic>> result = await appDatabase.query(sql: '''SELECT COUNT(id) AS counter
      FROM Bond WHERE instrumentUsed = ?''',
      arguments: [model.name]);

    return !_checkCounterField(result, 'counter');
  }

  /// Function to get the list of time deposits 
  /// connected to the specified savings account
  /// * [account] savings account selected
  /// * [close] flag to close the database
  Future<List<TimeDeposit>> getAccountTimeDeposits(SavingsAccount account, {bool close = false}) async {
    List<TimeDeposit> timeDeposits = [];
    /* get the list of time deposits 
    from the database connected to their 
    financial institutes */
    List<Map<String, dynamic>> result = await appDatabase.query(sql: '''SELECT TimeDeposit.id, TimeDeposit.name,
      provider, providerType, instrumentUsed, initialValue, currentValue, taxRate, status, interestRate, earlyWithdrawalInterestRate, isCashable,
      startingDate, includeStart, timeFrequency, dayOfMonth, monthOfYear, lastDateActivity, endingDate, includeEnd,
      FinancialInstitute.name AS institute_name, email, phoneNumber, site
      FROM TimeDeposit LEFT JOIN FinancialInstitute ON TimeDeposit.provider = FinancialInstitute.id
      WHERE bankAccount = ?''', arguments: [account.id]);

    /* cycle all the queries found and 
    get the corresponding time deposit */
    for(Map<String, dynamic> deposit in result){
      /* create the map for the financial
      institute object only if there is a connection */
      FinancialInstitute? provider;
      if(deposit['provider'] != null){
        Map<String, dynamic> financialInstituteRaw = {
          'id': deposit['provider'],
          'name': deposit['institute_name'],
          'email': deposit['email'],
          'phoneNumber': deposit['phoneNumber'],
          'site': deposit['site']
        };
        provider = FinancialInstitute.fromMap(financialInstituteRaw);
      }

      timeDeposits.add(TimeDeposit.fromMap(deposit, provider));
    }

    return timeDeposits;
  }
}