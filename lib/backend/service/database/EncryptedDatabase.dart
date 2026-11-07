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

  /* serializes opens, closes, and deletion for each database path */
  static final Map<String, Future<void>> _connectionOperations = {};

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
  /// * [onUpgrade] optional callback executed when upgrading the database schema
  Future<void> openAppDatabase({
    required String dbName,
    required String password,
    int version = 1,
    FutureOr<void> Function(Database, int)? onCreate,
    FutureOr<void> Function(Database, int, int)? onUpgrade,
    bool extensionAdded = false,
  }) async {
    if (!extensionAdded && !dbName.endsWith(_DATABASEEXTENSION)) {
      dbName += _DATABASEEXTENSION;
    }

    final String path = await _resolvePath(dbName);
    await _withConnectionOperation(path, () async {
      if (isOpen) {
        if (_connectionPath != path) {
          throw StateError(
            'This database wrapper already has another database open.',
          );
        }
        return;
      }

      _database = await _acquireConnection(
        path: path,
        password: password,
        version: version,
        onCreate: onCreate,
        onUpgrade: onUpgrade,
      );
      _connectionPath = path;
    });
  }

  /// Changes the encryption key of the open SQLCipher database in place.
  ///
  /// This operation is supported on Android and iOS, where the database is
  /// encrypted with SQLCipher. The current connection remains open.
  Future<void> rekey(String newPassword) async {
    if (!isOpen) {
      throw StateError('Cannot rekey a database that is not open.');
    }
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError(
        'Changing the database encryption key is supported only on mobile.',
      );
    }
    if (newPassword.isEmpty) {
      throw ArgumentError.value(newPassword, 'newPassword', 'Cannot be empty.');
    }

    final escapedPassword = newPassword.replaceAll("'", "''");
    await _database!.rawQuery("PRAGMA rekey = '$escapedPassword'");
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
    await _withConnectionOperation(path, () async {
      final database = _database;
      if (database == null || _connectionPath != path) {
        return;
      }

      /* Ignore stale wrappers left behind by a forced close or deletion. */
      if (!identical(_sharedConnections[path], database)) {
        _database = null;
        _connectionPath = null;
        return;
      }

      final int remaining = (_referenceCounters[path] ?? 1) - 1;
      _database = null;
      _connectionPath = null;

      if (remaining <= 0) {
        _sharedConnections.remove(path);
        _referenceCounters.remove(path);
        if (database.isOpen) {
          await database.close();
        }
      } else {
        _referenceCounters[path] = remaining;
      }
    });
  }

  /// Function to close all the instances of the database
  Future<void> forcedClosure() async {
    if (_database == null || _connectionPath == null) {
      return;
    }
    final String path = _connectionPath!;
    await _withConnectionOperation(path, () async {
      final database = _database;
      if (database == null || _connectionPath != path) {
        return;
      }

      _database = null;
      _connectionPath = null;
      if (identical(_sharedConnections[path], database)) {
        _sharedConnections.remove(path);
        _referenceCounters.remove(path);
      }
      if (database.isOpen) {
        await database.close();
      }
    });
  }

  /* *** QUERY EXECUTION METHODS *** */

  /// Executes a custom read query (SELECT) on the database
  /// * [sql] custom SQL query string
  /// * [arguments] optional list of positional parameters for query sanitization
  Future<dynamic> query({required String sql, List<dynamic>? arguments}) async {
    /* verify database connection state before executing query */
    _checkDbOpen();
    return await _database!.rawQuery(sql, arguments);
  }

  /// Executes a write operation (INSERT, UPDATE, DELETE) or schema definition statement
  /// * [sql] custom SQL statement string
  /// * [arguments] optional list of positional parameters
  Future<int> execute({required String sql, List<dynamic>? arguments}) async {
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
    if (!dbName.endsWith(_DATABASEEXTENSION)) {
      dbName += _DATABASEEXTENSION;
    }

    /* 1. get the path to the databases directory, resolved the same way
    openAppDatabase does it, so it matches the registry key exactly */
    final String fullPath = await _resolvePath(dbName);

    await _withConnectionOperation(fullPath, () async {
      /* Close and unregister any live connection before deleting the file. */
      final staleConnection = _sharedConnections.remove(fullPath);
      _referenceCounters.remove(fullPath);
      if (staleConnection != null && staleConnection.isOpen) {
        await staleConnection.close();
      }

      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        await sqldesktop.databaseFactoryFfi.deleteDatabase(fullPath);
      } else {
        await deleteDatabase(fullPath);
      }
    });
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
  the per-path operation lock so two physical connections are never created for
  the same database */
  Future<Database> _acquireConnection({
    required String path,
    required String password,
    required int version,
    FutureOr<void> Function(Database, int)? onCreate,
    FutureOr<void> Function(Database, int, int)? onUpgrade,
  }) async {
    final existing = _sharedConnections[path];
    if (existing != null) {
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

    final Database database = await _openPhysicalConnection(
      path: path,
      password: password,
      version: version,
      onCreate: onCreate,
      onUpgrade: onUpgrade,
    );
    _sharedConnections[path] = database;
    _referenceCounters[path] = 1;
    return database;
  }

  Future<T> _withConnectionOperation<T>(
    String path,
    Future<T> Function() operation,
  ) async {
    final previous = _connectionOperations[path] ?? Future<void>.value();
    final completer = Completer<void>();
    final operationTail = previous.then((_) => completer.future);
    _connectionOperations[path] = operationTail;

    await previous;
    try {
      return await operation();
    } finally {
      completer.complete();
      if (identical(_connectionOperations[path], operationTail)) {
        unawaited(_connectionOperations.remove(path));
      }
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
    FutureOr<void> Function(Database, int, int)? onUpgrade,
  }) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return await sqldesktop.databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: version,
          onCreate: onCreate,
          onUpgrade: onUpgrade,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
        ),
      );
    } else {
      return await openDatabase(
        path,
        password: password,
        version: version,
        onCreate: onCreate,
        onUpgrade: onUpgrade,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
      );
    }
  }

  _ConvertedSqlResult _convertNamedParameters(
    String sql,
    Map<String, dynamic>? parameters,
  ) {
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
