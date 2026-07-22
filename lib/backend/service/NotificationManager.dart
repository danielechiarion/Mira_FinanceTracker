import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Class used to manage local notifications across multiple platforms
/// including creation, cancellation, updates, and custom deep-linking payloads
class NotificationManager {
  /* attributes definition */
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /* Stream controller used to handle notification payload clicks */
  final StreamController<String?> _onNotificationClick =
      StreamController<String?>.broadcast();

  /// Constructor method to build the notification manager
  NotificationManager();

  /* *** GETTER METHODS *** */

  /// Returns the stream for notification click events with custom application routes/payloads
  Stream<String?> get onNotificationClick => _onNotificationClick.stream;

  /* *** INITIALIZATION METHODS *** */

  /// Initializes notification plugin settings for all supported operating systems
  /// and sets up the tap handler callback
  Future<void> initialize() async {
    /* initialize timezone database for scheduled notifications */
    tz.initializeTimeZones();

    /* platform specific initialization settings */
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings darwinSettings =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const LinuxInitializationSettings linuxSettings =
        LinuxInitializationSettings(
      defaultActionName: 'Open notification',
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );

    /* initialize the plugin with tap callback */
    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          _onNotificationClick.add(response.payload);
        }
      },
    );
  }

  /// Requests notification permissions for iOS, macOS, and Android devices
  Future<bool?> requestPermissions() async {
    bool? granted = false;

    /* request permissions for Android (notifications and exact alarms) */
    final androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      /* request POST_NOTIFICATIONS permission for Android 13+ */
      granted = await androidImplementation.requestNotificationsPermission();
      /* request SCHEDULE_EXACT_ALARM permission for Android 14+ if needed */
      await androidImplementation.requestExactAlarmsPermission();
    }

    /* request permissions for iOS/macOS */
    final darwinImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    if (darwinImplementation != null) {
      granted = await darwinImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    return granted;
  }

  /* *** CRUD NOTIFICATION METHODS *** */

  /// Shows an immediate notification to the user or updates an existing one with the same ID
  /// * [id] unique identifier for the notification
  /// * [title] header text displayed in the notification
  /// * [body] detailed message content
  /// * [payload] optional internal app link or route string passed when clicked
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final NotificationDetails details = _getPlatformDetails();

    /* display or replace the notification with the given ID */
    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  /// Schedules a notification to be delivered at a specific date and time
  /// * [id] unique identifier for the notification
  /// * [title] header text displayed in the notification
  /// * [body] detailed message content
  /// * [scheduledDate] future datetime when the notification should fire
  /// * [payload] optional internal app link or route string passed when clicked
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    final NotificationDetails details = _getPlatformDetails();

    /* convert DateTime to TZDateTime */
    final tz.TZDateTime tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tzDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  /// Updates an existing scheduled or active notification
  /// * [id] existing notification identifier to update
  /// * [title] new header text
  /// * [body] new detailed message content
  /// * [payload] updated internal link or route
  Future<void> updateNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await showNotification(
      id: id,
      title: title,
      body: body,
      payload: payload,
    );
  }

  /// Cancels a specific active or scheduled notification by its ID
  /// * [id] unique notification identifier to cancel
  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id: id);
  }

  /// Cancels all active and pending scheduled notifications
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  /* *** PRIVATE HELPER METHODS *** */

  /* returns default notification configuration details for supported OS platforms */
  NotificationDetails _getPlatformDetails() {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'main_channel_id',
      'Main Notifications',
      channelDescription: 'Main notification channel for app updates',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails darwinDetails =
        DarwinNotificationDetails();

    const LinuxNotificationDetails linuxDetails = LinuxNotificationDetails();

    return const NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
      linux: linuxDetails,
    );
  }

  /// Closes active stream controllers when disposing the service
  void dispose() {
    _onNotificationClick.close();
  }
}