import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Callback set by main.dart after app is running so tap events reach the UI
  static void Function(String payload)? onNotificationTap;

  static Future<void> init() async {
    if (kIsWeb || !Platform.isAndroid) return;
    const androidSettings = AndroidInitializationSettings('ic_notification');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload ?? '';
        if (onNotificationTap != null && payload.isNotEmpty) {
          onNotificationTap!(payload);
        }
      },
    );
  }

  static Future<void> requestPermissions() async {
    if (kIsWeb || !Platform.isAndroid) return;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();
  }

  /// Generic notification (used by Floats)
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
    const androidDetails = AndroidNotificationDetails(
      'briefly_channel_id',
      'Briefly Notifications',
      channelDescription: 'Notification channel for Briefly reports and floats',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }

  /// Report-specific notification — tapping it opens the report screen
  static Future<void> showReportNotification({
    required String title,
    required String body,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
    const androidDetails = AndroidNotificationDetails(
      'briefly_report_channel',
      'Daily Report',
      channelDescription: 'Daily briefing report notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      styleInformation: BigTextStyleInformation(''),
    );
    await _plugin.show(
      100,
      title,
      body,
      const NotificationDetails(android: androidDetails),
      payload: 'daily_report',
    );
  }

  /// Call on app launch — returns payload of the notification that launched the app
  static Future<String?> getAppLaunchPayload() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp == true) {
      return details?.notificationResponse?.payload;
    }
    return null;
  }

  static Future<void> handleColdStart() async {
    if (kIsWeb || !Platform.isAndroid) return;
    final payload = await getAppLaunchPayload();
    if (payload != null && payload.isNotEmpty && onNotificationTap != null) {
      onNotificationTap!(payload);
    }
  }
}
