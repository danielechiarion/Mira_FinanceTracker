import 'package:meta/meta.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:bcrypt/bcrypt.dart';

import 'package:mira_finance_tracker/backend/service/database/EncryptedDatabase.dart';
import 'package:mira_finance_tracker/backend/service/KeyManager.dart';

import 'package:mira_finance_tracker/classes/account/User.dart';

/// Class which wrapps the secure database class 
/// in order to manage the most common system functionalities,
/// which works not depending on the user connected
class SystemDatabaseWrapper{
  /* define static attributes for
  info about the database to follow */
  static final String _DATABASENAME = "system_database";

  /* attributes definition */
  @protected
  EncryptedDatabase database;
  @protected
  KeyManager keyManager;

  /// Constructor of the database wrapper for system functionalities
  /// in order to manage custom functions
  /// [keyManagerInput] keymanager provided by the program which is suggested to be done only by the extended classes
  SystemDatabaseWrapper({KeyManager? keyManagerInput}) 
    : keyManager = keyManagerInput ?? KeyManager(), database = EncryptedDatabase();
  
  /// Function to initialize the databse
  /// for system purposes
  Future<void> init() async{
    String key = (await keyManager.stringKey)!; // get the string key
    database.openAppDatabase(dbName: _DATABASENAME, password: key, onCreate: defineTables);
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
      result = (await database.query(sql: 'SELECT id,username,name,surname,email,password INTO User WHERE username = ?',
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

  Future<void> addUser(User user) async{
    try{
      database.query(sql: '''INSERT INTO User (id,username,name,surname,password,email) 
                            VALUES(?,?,?,?,?,?)''');
    }
  }
}