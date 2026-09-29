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

  /* static registry used to turn EncryptedDatabase into a singleton
  per database file: every instance pointing to the same physical path
  shares the same underlying connection instead of opening a new one */
  static final Map<String, Database> _sharedConnections = {};

  /* reference counter tied to each shared connection, increased every time
  an instance starts using it and decreased on close(); the physical
  connection is only closed for real once the counter reaches zero */
  static final Map<String, int> _referenceCounters = {};

  /* tracks opening operations still in progress for a given path, so that
  concurrent calls on the same database file wait for the same connection
  instead of racing to open two different physical connections */
  static final Map<String, Future<Database>> _pendingOpenings = {};

  /* attributes definition */
  Database? _database;

  /* path of the shared connection currently used by this instance,
  needed to release the correct reference when close() is called */
  String? _connectionPath;

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
  /// If another instance already holds an open connection towards the same
  /// database file, that connection is reused instead of opening a new one.
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

      /* resolve the physical path first: it is the key used to look up
      or register the shared connection in the static registry */
      final String path = await _resolvePath(dbName);

      _database = await _acquireConnection(
        path: path,
        password: password,
        version: version,
        onCreate: onCreate,
      );

      print("User Database path: $path");
      _connectionPath = path;
    } catch (e) {
      rethrow;
    }
  }

  /// Closes the active database connection.
  /// Since the underlying connection can be shared with other instances
  /// pointing to the same database file, it is only closed for real once
  /// every instance referencing it has released it.
  Future<void> close() async {
    if (_database == null || _connectionPath == null) {
      return;
    }

    final String path = _connectionPath!;
    final int remaining = (_referenceCounters[path] ?? 1) - 1;

    if (remaining <= 0) {
      /* no other instance is using this connection anymore: close it for real */
      if (_database!.isOpen) {
        await _database!.close();
      }
      _sharedConnections.remove(path);
      _referenceCounters.remove(path);
    } else {
      _referenceCounters[path] = remaining;
    }

    _database = null;
    _connectionPath = null;
  }

  /// Function to close all the instances of the database
  Future<void> forcedClosure() async {
    if(_database == null || _connectionPath == null){
      return;
    }
    await _database!.close();

    /* reset all the registers
    about the database */
    _sharedConnections.remove(_connectionPath);
    _referenceCounters[_connectionPath!] = (_referenceCounters[_connectionPath] ?? 1) - 1;
    
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
    /* 1. get the path to the databases directory, resolved the same way
    openAppDatabase does it, so it matches the registry key exactly */
    final String fullPath = await _resolvePath(dbName);

    /* 2. if a shared connection towards this file is still registered,
    close it and drop it from the registry before deleting the file:
    otherwise the delete could fail, or leave a stale entry behind.
    note that any other instance still referencing this connection will
    find it closed on its next operation, just like when a file is deleted
    while still in use */
    if (_sharedConnections.containsKey(fullPath)) {
      final Database staleConnection = _sharedConnections[fullPath]!;
      if (staleConnection.isOpen) {
        await staleConnection.close();
      }
      _sharedConnections.remove(fullPath);
      _referenceCounters.remove(fullPath);
    }

    /* 3. delete the database file */
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

  /* resolves the platform-specific full path of a database file. used
  consistently by openAppDatabase and deleteAppDatabase so the singleton
  registry is always indexed with the same key for the same database */
  Future<String> _resolvePath(String dbName) async {
    final String fullPath;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final dbFolder = await getApplicationSupportDirectory();
      fullPath = join(dbFolder.path, dbName);
    } else {
      final dbFolder = await getDatabasesPath();
      fullPath = join(dbFolder, dbName);
    }

    return fullPath;
  }

  /* returns the shared connection for the given path, opening it only if
  no other instance already opened it (or is currently opening it);
  concurrent requests for the same path are serialized through
  _pendingOpenings so two physical connections are never created for
  the same database */
  Future<Database> _acquireConnection({
    required String path,
    required String password,
    required int version,
    FutureOr<void> Function(Database, int)? onCreate,
  }) async {
    if (_sharedConnections.containsKey(path)) {
      final Database existing = _sharedConnections[path]!;
      if (existing.isOpen) {
        _referenceCounters[path] = (_referenceCounters[path] ?? 0) + 1;
        return existing;
      }
      /* stale entry: the connection was closed outside of the normal
      close() flow (e.g. through deleteAppDatabase), clean it up
      and fall through to open a brand new one below */
      _sharedConnections.remove(path);
      _referenceCounters.remove(path);
    }

    if (_pendingOpenings.containsKey(path)) {
      final Database db = await _pendingOpenings[path]!;
      _referenceCounters[path] = (_referenceCounters[path] ?? 0) + 1;
      return db;
    }

    final Future<Database> openingFuture = _openPhysicalConnection(
      path: path,
      password: password,
      version: version,
      onCreate: onCreate
    );
    _pendingOpenings[path] = openingFuture;

    try {
      final Database db = await openingFuture;
      _sharedConnections[path] = db;
      _referenceCounters[path] = 1;
      return db;
    } finally {
      _pendingOpenings.remove(path);
    }
  }

  /* opens the actual physical connection using FFI on desktop platforms
  and sqlcipher on mobile, exactly as it was done before the singleton
  registry was introduced */
  Future<Database> _openPhysicalConnection({
    required String path,
    required String password,
    required int version,
    FutureOr<void> Function(Database, int)? onCreate,
  }) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return await sqldesktop.databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: version,
          onCreate: onCreate,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          }
        ),
      );
    } else {
      return await openDatabase(
        path,
        password: password,
        version: version,
        onCreate: onCreate,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        }
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