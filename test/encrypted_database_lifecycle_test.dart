import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mira_finance_tracker/backend/service/database/EncryptedDatabase.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sqldesktop;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory temporaryDirectory;

  setUpAll(sqldesktop.sqfliteFfiInit);

  setUp(() {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'mira_database_lifecycle_',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          if (call.method == 'getApplicationSupportDirectory') {
            return temporaryDirectory.path;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    if (temporaryDirectory.existsSync()) {
      temporaryDirectory.deleteSync(recursive: true);
    }
  });

  test(
    'reopening waits until the previous shared connection is closed',
    () async {
      final closingDatabase = EncryptedDatabase();
      await closingDatabase.openAppDatabase(
        dbName: 'close_reopen_race',
        password: '',
        onCreate: (database, version) async {
          await database.execute('CREATE TABLE lifecycle_test (value INTEGER)');
        },
      );

      final closeFuture = closingDatabase.close();
      final reopenedDatabase = EncryptedDatabase();
      try {
        await reopenedDatabase.openAppDatabase(
          dbName: 'close_reopen_race',
          password: '',
        );
        await closeFuture;

        expect(reopenedDatabase.isOpen, isTrue);
        expect(
          await reopenedDatabase.query(sql: 'SELECT value FROM lifecycle_test'),
          isEmpty,
        );
      } finally {
        await closeFuture;
        await reopenedDatabase.close();
      }
    },
  );

  test(
    'concurrent wrappers keep the shared connection open until last close',
    () async {
      final wrappers = List.generate(8, (_) => EncryptedDatabase());
      await Future.wait(
        wrappers.map(
          (wrapper) => wrapper.openAppDatabase(
            dbName: 'shared_connection_refs',
            password: '',
            onCreate: (database, version) async {
              await database.execute(
                'CREATE TABLE lifecycle_test (value INTEGER)',
              );
            },
          ),
        ),
      );

      await Future.wait(wrappers.take(7).map((wrapper) => wrapper.close()));

      expect(wrappers.last.isOpen, isTrue);
      expect(
        await wrappers.last.query(sql: 'SELECT value FROM lifecycle_test'),
        isEmpty,
      );
      await wrappers.last.close();
    },
  );
}
