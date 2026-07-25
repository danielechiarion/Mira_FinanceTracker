import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Class used to manage the encrypted database instance
/// and perform raw or custom SQL queries
class EncryptedDatabase {
  /* attributes definition */
  Database? _database;

  /// Constructor method to build the database manager
  EncryptedDatabase();

  /* *** GETTER METHODS *** */

  /// Returns the current database instance
  Database? get database => _database;

  /// Checks if the database connection is currently open
  bool get isOpen => _database != null && _database!.isOpen;

  /* *** DATABASE MANAGEMENT METHODS *** */

  /// Opens the encrypted database using the provided password key.
  /// Creates the database file and executes initial setup if it doesn't exist yet.
  /// * [dbName] file name of the SQLite database
  /// * [password] secret key used for encryption/decryption (AES-256)
  /// * [version] target schema version of the database
  /// * [onCreate] optional callback executed when creating the database for the first time
  Future<void> openAppDatabase({
    required String dbName,
    required String password,
    int version = 1,
    FutureOr<void> Function(Database, int)? onCreate,
  }) async {
    /* check if database is already opened */
    if (isOpen) {
      return;
    }

    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, dbName);

      _database = await openDatabase(
        path,
        password: password,
        version: version,
        onCreate: onCreate,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Closes the active database connection
  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }

  /* *** QUERY EXECUTION METHODS *** */

  /// Executes a custom read query (SELECT) on the database
  /// * [sql] custom SQL query string
  /// * [arguments] optional list of positional parameters for query sanitization
  Future<List<Map<String, dynamic>>> query({
    required String sql,
    List<dynamic>? arguments,
  }) async {
    /* verify database connection state before executing query */
    _checkDbOpen();
    return await _database!.rawQuery(sql, arguments);
  }

  /// Executes a write operation (INSERT, UPDATE, DELETE) or schema definition statement
  /// * [sql] custom SQL statement string
  /// * [arguments] optional list of positional parameters
  Future<int> execute({
    required String sql,
    List<dynamic>? arguments,
  }) async {
    /* verify database connection state before executing statement */
    _checkDbOpen();
    return await _database!.rawInsert(sql, arguments);
  }

  /// Executes a set of operations wrapped inside a database transaction
  /// * [action] closure function containing transactional operations
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    /* verify database connection state before starting transaction */
    _checkDbOpen();
    return await _database!.transaction(action);
  }

  /* *** PRIVATE HELPER METHODS *** */

  /* internal helper method to ensure the database instance is open before any operation */
  void _checkDbOpen() {
    if (!isOpen) {
      throw Exception(
        "The database is not open. Call openAppDatabase() first.",
      );
    }
  }
}