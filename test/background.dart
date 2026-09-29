import 'dart:io';
import 'package:mocktail/mocktail.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mira_finance_tracker/background/activity/BackgroundControl.dart';
import 'package:mira_finance_tracker/backend/service/notification/NotificationManager.dart';

class MockNotificationManager extends Mock implements NotificationManager {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /* add mocking version of flutter secure storage */
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final Map<String, String> fakeSecureStorage = {};

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      switch (call.method) {
        case 'read':
          final key = call.arguments['key'] as String;
          return fakeSecureStorage[key];
        case 'write':
          final key = call.arguments['key'] as String;
          final value = call.arguments['value'] as String;
          fakeSecureStorage[key] = value;
          return null;
        case 'delete':
          final key = call.arguments['key'] as String;
          fakeSecureStorage.remove(key);
          return null;
        case 'readAll':
          return Map<String, String>.from(fakeSecureStorage);
        case 'deleteAll':
          fakeSecureStorage.clear();
          return null;
        case 'containsKey':
          final key = call.arguments['key'] as String;
          return fakeSecureStorage.containsKey(key);
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    fakeSecureStorage.clear();
  });

  /* mocking also path provider to
  avoid problems during test */
  const channelPath = MethodChannel('plugins.flutter.io/path_provider');
  final tempDir = Directory.systemTemp.createTempSync('mira_test_');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channelPath, (MethodCall call) async {
      switch (call.method) {
        case 'getApplicationSupportDirectory':
        case 'getApplicationDocumentsDirectory':
        case 'getTemporaryDirectory':
        case 'getLibraryDirectory':
        case 'getExternalStorageDirectory':
          return tempDir.path;
        case 'getApplicationCacheDirectory':
          return tempDir.path;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('Background control check', () async {
    /* mock notification to avoid errors of 
    instantiation on the specific devices. 
    This part only tests functions, not notifications */
    final mockNotification = MockNotificationManager();

    when(() => mockNotification.initialize()).thenAnswer((_) async {});
    when(() => mockNotification.showNotification(
      id: any(named: 'id'),
      title: any(named: 'title'),
      body: any(named: 'body'),
    )).thenAnswer((_) async {});

    BackgroundControl control = BackgroundControl(notificationManager: mockNotification);
    await control.init();
    await control.execute();
  });
}