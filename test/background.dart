import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mira_finance_tracker/background/activity/BackgroundControl.dart';
import 'package:mira_finance_tracker/backend/service/notification/NotificationManager.dart';

class MockNotificationManager extends Mock implements NotificationManager {}

void main() {
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