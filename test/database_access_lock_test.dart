import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mira_finance_tracker/backend/service/database/EncryptedDatabase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory temporaryDirectory;

  setUp(() {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'mira_database_access_lock_',
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

  test('serializes operations using independent lock handles', () async {
    var activeOperations = 0;
    var maximumConcurrentOperations = 0;

    Future<void> runOperation() {
      return DatabaseAccessLock.runExclusive(() async {
        activeOperations++;
        if (activeOperations > maximumConcurrentOperations) {
          maximumConcurrentOperations = activeOperations;
        }
        try {
          await Future<void>.delayed(const Duration(milliseconds: 30));
        } finally {
          activeOperations--;
        }
      });
    }

    await Future.wait([runOperation(), runOperation()]);

    expect(maximumConcurrentOperations, 1);
  });

  test('releases the lock when an operation fails', () async {
    await expectLater(
      DatabaseAccessLock.runExclusive<void>(() async {
        throw StateError('expected test failure');
      }),
      throwsA(isA<StateError>()),
    );

    await expectLater(
      DatabaseAccessLock.runExclusive(() async => true),
      completion(isTrue),
    );
  });
}
