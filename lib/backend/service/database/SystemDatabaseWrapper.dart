import 'package:meta/meta.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:bcrypt/bcrypt.dart';

import 'package:mira_finance_tracker/backend/service/database/EncryptedDatabase.dart';
import 'package:mira_finance_tracker/backend/service/KeyManager.dart';

import 'package:mira_finance_tracker/classes/account/User.dart';
import 'package:mira_finance_tracker/backend/cloud/authentication/GoogleAccount.dart';

/// Class which wrapps the secure database class 
/// in order to manage the most common system functionalities,
/// which works not depending on the user connected
class SystemDatabaseWrapper{
  /* define static attributes for
  info about the database to follow */
  static final String _DATABASENAME = "system_database";
  static final String USERDATABASEPREFIX = "user_";

  /* attributes definition */
  @protected
  EncryptedDatabase database;
  @protected
  KeyManager systemKeyManager;

  /// Constructor of the database wrapper for system functionalities
  /// in order to manage custom functions
  SystemDatabaseWrapper() 
    :  systemKeyManager = KeyManager(), database = EncryptedDatabase();
  
  /// Function to initialize the databse
  /// for system purposes
  Future<void> init() async{
    await systemKeyManager.init();
    String? key = await systemKeyManager.stringKey;
    if (key == null) {
      throw Exception('Unable to initialize system database: encryption key unavailable');
    }
    await database.openAppDatabase(dbName: _DATABASENAME, password: key, onCreate: defineTables);
  }

  /// Method used to define tables of the database
  /// for system functionalities
  /// [db] input database
  /// [version] version of the database
  @protected
  Future<void> defineTables(Database db, int version) async{
    /* the only operation to do is to 
    dedicate a database only for user accounting */
    await db.execute('''
      CREATE TABLE IF NOT EXISTS User(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        surname TEXT,
        password TEXT,
        email TEXT
      )
    ''');

    /* after google account integration, add one more table
    to save the account tokens */
    await db.execute('''
      CREATE TABLE IF NOT EXISTS GoogleAuthSession(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT NOT NULL UNIQUE,
        display_name TEXT,
        access_token TEXT,
        refresh_token TEXT,
        server_auth_code TEXT,
        updated_at DATETIME
      )
    '''); 
  }

  /// Function to check if the user who tries
  /// to log in exists and return it back
  /// * [username] input username
  /// * [password] input clear password
  /// * [close] optional flag to close the database after the operation
  Future<User?> userLogin(String username, String password, {close = false}) async {
    /* check inside the database
    if the user is present */
    Map<String, dynamic> result = {};
    try{
      result = (await database.query(sql: 'SELECT id,username,name,surname,email,password FROM User WHERE username = ?',
                    arguments: [username])).first;
    }on StateError{
      return null;
    }

    /* compare the password with the one given, otherwise 
    return null */
    if(!BCrypt.checkpw(password, result['password'])){
      return null;
    }

    if(close){
      database.close();
    }

    return User.fromMap(result);
  }

  /// Function to add a new user checking
  /// the hash of the password and if it already exists
  /// * [user] user to be added
  /// * [passwordHashed] flag to indicate if the password has already been hashed
  /// * [close] flag to indicate if the database has to be closed at the end of the operation
  /// 
  /// The function returns the new id of the user, which has already been set in the object
  /// which was passed as argument
  Future<int> addUser(User user, {bool passwordHashed = false, bool close = false}) async{
    /* if the password is not hashed just hash it 
    before being saved into the database */
    if(!passwordHashed){
      user.hashCurrentPassword();
    }

    int newId;
    try{
      // Ensure argument order matches the INSERT column order
      final args = [user.username, user.name, user.surname, user.password, user.email];
      newId = await database.execute(
        sql: '''INSERT INTO User (username,name,surname,password,email) 
                            VALUES(?,?,?,?,?)''',
        arguments: args,
      );
      user.id = newId; // set the id returned by rawInsert
    } on DatabaseException catch (e) {
      final message = e.toString();
      if (message.contains('UNIQUE') || message.contains('unique') || message.contains('UNIQUE constraint failed')) {
        throw Exception('USERNAME_ALREADY_EXISTS');
      }
      rethrow;
    } catch (e) {
      throw Exception(e);
    } finally{
      if(close){
        database.close();
      }
    }
    return newId; // return it anyway
  }

  /// Function to remove the data of the user inside the 
  /// system and the personal database
  /// * [user] user to be removed
  /// * [close] flag to indicated if the database has to be closed after the operation
  Future<void> removeUser(User user, {bool close = false}) async{
    try{
      await database.execute(sql: 'DELETE FROM User WHERE username = ?', arguments: [user.username]);
      /* delete also the database 
      dedicated to the user operations. 
      if this one was not created, make the operation non fatal */
      try{
        await database.deleteAppDatabase('$USERDATABASEPREFIX${user.username}');
      }catch(_){}
    } on DatabaseException{
      rethrow;
    }catch(e){
      throw Exception(e);
    }finally{
      if(close){
        database.close();
      }
    }
  }

  /// Function to update the data of the user
  /// * [user] user to be updated
  /// * [close] flag to indicated if the database has to be closed after the operation
  Future<void> updateUser(User user, {bool close = false}) async { 
    try{
      await database.execute(sql: ''' UPDATE User
                                    SET name = ?, surname = ?, email = ?, password = ?
                                    WHERE username = ? ''',
                          arguments: [user.name, user.surname, user.email, user.password, user.username]);
    } on DatabaseException {
      rethrow;
    }catch(e){
      throw Exception(e);
    }finally{
      if(close){
        database.close();
      }
    }
  }

  /// Function to return the list of users 
  /// registered inside the database
  /// * [close] flag to indicated if the database has to be closed after the operation
  Future<List<User>> userList({bool close = false}) async{
    try{
      List<Map<String, dynamic>> mapList = await database.query(sql: 'SELECT id,username,name,surname,password,email FROM User');
      /* now convert all the map
      into user objects */
      List<User> userList = [];
      for(Map<String, dynamic> singleMap in mapList){
        userList.add(User.fromMap(singleMap));
      }
      return userList;
    } on DatabaseException{
      rethrow;
    }catch(e){
      throw Exception(e);
    }finally{
      if(close){
        await database.close();
      }
    }
  }

  /// Function to add or replace a google [account] inside the database,
  /// in order to save the tokens
  /// * [close] flag to close the database
  Future<void> addGoogleAccount(GoogleAccount account, {bool close = false}) async {
    await database.executeWithMap(sql: '''INSERT OR REPLACE INTO GoogleAuthSession
      (email, display_name, access_token, refresh_token, server_auth_code, updated_at) 
      VALUES (:email, :display_name, :access_token, :refresh_token, :server_auth_code, :updated_at)''',
      parameters: account.toMap());

    if(close){
      await database.close();
    }
  }

  /// Function to get the google account by its [email]
  /// * [close] flag to close the database
  Future<GoogleAccount?> getGoogleAccountByEmail(String email, {bool close = false}) async {
    final result = await database.query(sql: '''
      SELECT id, email, display_name, access_token, refresh_token, server_auth_code, updated_at
      FROM GoogleAuthSession WHERE email = ?''', arguments: [email]);

    if(result.isEmpty){
      return null;
    }
    final account = GoogleAccount.fromMap(result.first);

    if(close){
      await database.close();
    }

    return account;
  }

  /// Function to remove a google account from the database
  /// * [close] flag to close the database
  Future<void> removeGoogleAccount(String email, {bool close = false}) async {
    await database.execute(sql: 'DELETE FROM GoogleAuthSession WHERE email = ?', arguments: [email]);

    if(close){
      await database.close();
    }
  }

  /// Function to get all google accounts from the database
  /// * [close] flag to close the database
  Future<List<GoogleAccount>> getAllGoogleAccounts({bool close = false}) async {
    final result = await database.query(sql: '''SELECT 
      id, email, display_name, access_token, refresh_token, server_auth_code, updated_at
      FROM GoogleAuthSession ORDER BY updated_at DESC''');

    if(close){
      await database.close();
    }

    return result.map((map) => GoogleAccount.fromMap(map)).toList();
  }

  /// Method to check the user validity
  /// in order to add it correctly inside the database
  /// * [username] username to be checked
  Future<bool> userValidity(String username) async{
    /* the only check to pass
    is to have a user which username has
    not been added before */
    final result = await database.query(
      sql: 'SELECT EXISTS(SELECT 1 FROM User WHERE username = ?) AS user_exists',
      arguments: [username],
    );

    /* The query returns a list with a single Map: [{'user_exists': 1}] or [{'user_exists': 0}] */
    if (result.isNotEmpty) {
      return result.first['user_exists'] != 1;
    }

    return false;
  }

  /// Function to update user on general table
  /// saving email connected to the google account
  Future<void> updateUserEmail(User user, String email) async {
    await database.execute(sql: '''UPDATE User SET email=? WHERE username=?''',
      arguments: [email, user.username]);
  }

  /// Function to remove user email 
  /// connected to the cloud settings
  Future<void> removeUserEmail(User user) async {
    await database.execute(sql: '''UPDATE User SET email=? WHERE username=?''',
      arguments: [null, user.username]);
  }

  /// Function to close definitely the database
  Future<void> closeDatabase() async{
    await database.close();
  }

  /// Method to close the current session
  /// and all the other which were left open,
  /// to be sure nothing is connected anymore
  Future<void> closeCompletelyDatabase() async {
    await database.forcedClosure();
  }
}