import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mira_finance_tracker/backend/service/database/EncryptedDatabase.dart';
import 'package:mira_finance_tracker/backend/service/database/UserDatabaseWrapper.dart';
import 'package:mira_finance_tracker/classes/account/User.dart';
import 'package:mira_finance_tracker/classes/financial_instruments/service/FinancialInstrument.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sqldesktop;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory temporaryDirectory;
  late EncryptedDatabase encryptedDatabase;
  late _SyncTestDatabaseWrapper userDatabase;

  setUpAll(sqldesktop.sqfliteFfiInit);

  setUp(() async {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'mira_cloud_financial_sync_',
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
      dbName: 'cloud_financial_sync',
      password: '',
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE BankAccount(
            id INTEGER PRIMARY KEY,
            financialInstitute INTEGER,
            subscriptionDate TEXT,
            interest REAL,
            endingDate TEXT,
            availableBalance REAL,
            active INTEGER,
            startingDate TEXT,
            includeStart INTEGER,
            timeFrequency INTEGER,
            dayOfMonth INTEGER,
            monthOfYear INTEGER,
            lastDateActivity TEXT
          )
        ''');
        await database.execute('''
          CREATE TABLE SavingsAccount(
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL UNIQUE,
            ledgerBalance REAL NOT NULL,
            FOREIGN KEY (id) REFERENCES BankAccount(id) ON DELETE CASCADE
          )
        ''');
        await database.execute('''
          CREATE TABLE TimeDeposit(
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            provider INTEGER,
            providerType INTEGER,
            instrumentUsed TEXT,
            initialValue REAL,
            currentValue REAL,
            taxRate REAL,
            status INTEGER NOT NULL,
            interestRate REAL,
            earlyWithdrawalInterestRate REAL,
            isCashable INTEGER,
            startingDate TEXT,
            includeStart INTEGER,
            timeFrequency INTEGER,
            dayOfMonth INTEGER,
            monthOfYear INTEGER,
            lastDateActivity TEXT,
            endingDate TEXT,
            includeEnd INTEGER,
            bankAccount INTEGER NOT NULL,
            FOREIGN KEY (bankAccount) REFERENCES BankAccount(id) ON DELETE CASCADE
          )
        ''');
        await database.execute('''
          INSERT INTO BankAccount (id, availableBalance) VALUES (1, 200)
        ''');
        await database.execute('''
          INSERT INTO SavingsAccount (id, name, ledgerBalance)
          VALUES (1, 'Risparmi', 1000)
        ''');
        await database.execute('''
          INSERT INTO TimeDeposit (id, name, status, bankAccount)
          VALUES (1, 'Deposito attivo', 0, 1)
        ''');
      },
    );
    userDatabase = _SyncTestDatabaseWrapper(encryptedDatabase);
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
    'account import preserves existing dependent financial instruments',
    () async {
      await userDatabase.importSavingsAccounts({
        'content': [
          {
            'id': 1,
            'financialInstitute': null,
            'subscriptionDate': '2026-01-01T00:00:00.000',
            'interest': 0.0,
            'endingDate': null,
            'availableBalance': 250.0,
            'active': 1,
            'startingDate': '2026-01-01T00:00:00.000',
            'includeStart': 0,
            'timeFrequency': 0,
            'dayOfMonth': 1,
            'monthOfYear': null,
            'lastDateActivity': null,
            'name': 'Risparmi',
            'ledgerBalance': 1000.0,
          },
        ],
      });

      final deposits =
          await encryptedDatabase.query(
                sql: 'SELECT id FROM TimeDeposit WHERE bankAccount = ?',
                arguments: [1],
              )
              as List<Map<String, Object?>>;
      final account =
          await encryptedDatabase.query(
                sql: 'SELECT availableBalance FROM BankAccount WHERE id = ?',
                arguments: [1],
              )
              as List<Map<String, Object?>>;

      expect(deposits, hasLength(1));
      expect(account.single['availableBalance'], 250.0);
    },
  );

  test('export retains active deposits past the backup time window', () async {
    final oldEndingDate = DateTime.now()
        .subtract(const Duration(days: 3 * 365))
        .toIso8601String();
    await encryptedDatabase.execute(
      sql:
          '''INSERT INTO TimeDeposit (id, name, status, endingDate, bankAccount)
          VALUES (?, ?, ?, ?, ?)''',
      arguments: [
        2,
        'Attivo oltre scadenza',
        FinancialInstrumentStatus.ongoing.index,
        oldEndingDate,
        1,
      ],
    );
    await encryptedDatabase.execute(
      sql:
          '''INSERT INTO TimeDeposit (id, name, status, endingDate, bankAccount)
          VALUES (?, ?, ?, ?, ?)''',
      arguments: [
        3,
        'Storico fuori finestra',
        FinancialInstrumentStatus.ended.index,
        oldEndingDate,
        1,
      ],
    );
    await encryptedDatabase.execute(
      sql:
          '''INSERT INTO TimeDeposit (id, name, status, endingDate, bankAccount)
          VALUES (?, ?, ?, ?, ?)''',
      arguments: [
        4,
        'Deposito ridotto ancora attivo',
        FinancialInstrumentStatus.reduced.index,
        oldEndingDate,
        1,
      ],
    );

    final exported = await userDatabase.exportTimeDeposits(1);
    final deposits = (exported['content'] as List).cast<Map<String, dynamic>>();

    expect(
      deposits.map((deposit) => deposit['name']),
      contains('Attivo oltre scadenza'),
    );
    expect(
      deposits.map((deposit) => deposit['name']),
      contains('Deposito ridotto ancora attivo'),
    );
    expect(
      deposits.map((deposit) => deposit['name']),
      isNot(contains('Storico fuori finestra')),
    );
  });
}

class _SyncTestDatabaseWrapper extends UserDatabaseWrapper {
  _SyncTestDatabaseWrapper(this._testDatabase)
    : super(User('cloud-sync-test', '', 'Test'));

  final EncryptedDatabase _testDatabase;

  @override
  EncryptedDatabase get appDatabase => _testDatabase;
}
