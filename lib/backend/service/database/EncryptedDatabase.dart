import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sqldesktop;
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Class used to manage the encrypted database instance
/// and perform raw or custom SQL queries
class EncryptedDatabase {
  /* define static attributes to use 
  for database creation */
  static const String _DATABASEEXTENSION = ".db";

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
    bool extensionAdded = false
  }) async {
    /* check if database is already opened */
    if (isOpen) {
      return;
    }

    try {
      if(!extensionAdded && !dbName.endsWith(_DATABASEEXTENSION)) {
        dbName += _DATABASEEXTENSION;
      }
      
      /* open database using FFI on desktop platforms and sqlcipher on mobile */
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final dbFolder = await getApplicationSupportDirectory();
        final path = join(dbFolder.path, dbName);

        _database = await sqldesktop.databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: version,
            onCreate: onCreate,
          ),
        );
      } else {
        final dbFolder = await getDatabasesPath();
        final path = join(dbFolder, dbName);

        _database = await openDatabase(
          path,
          password: password,
          version: version,
          onCreate: onCreate,
        );
      }
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
  Future<dynamic> query({
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

  /// Executes a write operation with named parameters.
  /// Example: sql = 'INSERT INTO table (name, value) VALUES (:name, :value)'
  ///          parameters = {'name': 'foo', 'value': 42}
  Future<int> executeWithMap({
    required String sql,
    Map<String, dynamic>? parameters,
  }) async {
    _checkDbOpen();
    final converted = _convertNamedParameters(sql, parameters);
    return await _database!.rawInsert(converted.sql, converted.arguments);
  }

  /// Executes a custom read query with named parameters.
  /// Example: sql = 'SELECT * FROM table WHERE id = :id'
  ///          parameters = {'id': 123}
  Future<dynamic> queryWithMap({
    required String sql,
    Map<String, dynamic>? parameters,
  }) async {
    _checkDbOpen();
    final converted = _convertNamedParameters(sql, parameters);
    return await _database!.rawQuery(converted.sql, converted.arguments);
  }

  /// Executes a set of operations wrapped inside a database transaction
  /// * [action] closure function containing transactional operations
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    /* verify database connection state before starting transaction */
    _checkDbOpen();
    return await _database!.transaction(action);
  }

  /// Deletes the specified database file from local device storage
  /// * [dbName] name of the database file to remove (e.g., 'app_database.db')
  Future<void> deleteAppDatabase(String dbName) async {
    /* 1. get the path to the databases directory */
    final String dbPath = await getDatabasesPath();
    final String fullPath = join(dbPath, dbName);

    /* 2. delete the database file */
    await deleteDatabase(fullPath);
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

  _ConvertedSqlResult _convertNamedParameters(
      String sql, Map<String, dynamic>? parameters) {
    if (parameters == null || parameters.isEmpty) {
      return _ConvertedSqlResult(sql, null);
    }

    final arguments = <dynamic>[];
    final regex = RegExp(r':([a-zA-Z_][a-zA-Z0-9_]*)');
    final convertedSql = sql.replaceAllMapped(regex, (match) {
      final name = match.group(1)!;
      if (!parameters.containsKey(name)) {
        throw ArgumentError('Missing named parameter: $name');
      }
      arguments.add(parameters[name]);
      return '?';
    });

    return _ConvertedSqlResult(convertedSql, arguments);
  }
}

class _ConvertedSqlResult {
  final String sql;
  final List<dynamic>? arguments;

  _ConvertedSqlResult(this.sql, this.arguments);
}