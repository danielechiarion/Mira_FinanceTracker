import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mira_finance_tracker/backend/service/database/EncryptedDatabase.dart';
import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';
import 'package:mira_finance_tracker/classes/account/User.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sqldesktop;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory temporaryDirectory;
  late EncryptedDatabase encryptedDatabase;
  late _ImportTestDatabaseWrapper userDatabase;

  setUpAll(sqldesktop.sqfliteFfiInit);

  setUp(() async {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'mira_financial_institute_import_',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          if (call.method == 'getApplicationSupportDirectory') {
            return temporaryDirectory.path;
          }
          return null;
        });

    encryptedDatabase = EncryptedDatabase();
    await encryptedDatabase.openAppDatabase(
      dbName: 'financial_institute_import',
      password: '',
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE FinancialInstitute(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            email TEXT,
            phoneNumber TEXT,
            site TEXT
          )
        ''');
        await database.execute('''
          CREATE TABLE BankAccount(
            id INTEGER PRIMARY KEY,
            financialInstitute INTEGER,
            FOREIGN KEY (financialInstitute) REFERENCES FinancialInstitute(id)
              ON DELETE RESTRICT
          )
        ''');
        await database.insert('FinancialInstitute', {
          'id': 1,
          'name': 'Poste Italiane',
          'email': '',
          'phoneNumber': '',
          'site': '',
        });
        await database.insert('BankAccount', {
          'id': 1,
          'financialInstitute': 1,
        });
      },
    );
    userDatabase = _ImportTestDatabaseWrapper(encryptedDatabase);
  });

  tearDown(() async {
    await encryptedDatabase.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    if (temporaryDirectory.existsSync()) {
      temporaryDirectory.deleteSync(recursive: true);
    }
  });

  test(
    'updates an imported institute without deleting referenced rows',
    () async {
      await userDatabase.importFinancialInstitutes({
        'content': [
          {
            'id': 1,
            'name': 'Poste Italiane',
            'email': 'support@example.com',
            'phoneNumber': '',
            'site': '',
          },
        ],
      });

      final institutes =
          await encryptedDatabase.query(
                sql: 'SELECT id, email FROM FinancialInstitute WHERE id = ?',
                arguments: [1],
              )
              as List<Map<String, Object?>>;
      final accounts =
          await encryptedDatabase.query(
                sql: 'SELECT financialInstitute FROM BankAccount WHERE id = ?',
                arguments: [1],
              )
              as List<Map<String, Object?>>;

      expect(institutes.single['email'], 'support@example.com');
      expect(accounts.single['financialInstitute'], 1);
    },
  );
}

class _ImportTestDatabaseWrapper extends UserDatabaseWrapper {
  _ImportTestDatabaseWrapper(this._testDatabase)
    : super(User('import-test', '', 'Test'));

  final EncryptedDatabase _testDatabase;

  @override
  EncryptedDatabase get appDatabase => _testDatabase;
}
