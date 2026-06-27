import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'notification_helper.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

class FcmService {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');

        if (message.notification != null) {
          debugPrint('Message also contained a notification: ${message.notification}');
          final notification = message.notification!;
          final isReport = message.data['type'] == 'daily_report' || 
                           (notification.title ?? '').contains('Briefing') || 
                           (notification.body ?? '').contains('briefing');
          
          if (isReport) {
            NotificationHelper.showReportNotification(
              title: notification.title ?? "Today's Briefing is ready ✨",
              body: notification.body ?? 'Tap to view your daily report.',
            );
          } else {
            NotificationHelper.showNotification(
              id: message.messageId.hashCode,
              title: notification.title ?? 'Briefly',
              body: notification.body ?? '',
              payload: message.data['type'] == 'floats' ? 'floats' : message.data['payload'],
            );
          }
        }
      });

      // Handle notification clicks when app is in background but not terminated
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('App opened from background via FCM notification click!');
        _handleNotificationData(message.data);
      });

      // Listen for token refreshes
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        debugPrint('FCM Token refreshed: $newToken');
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('user_id') ?? '';
        if (userId.isNotEmpty) {
          await _uploadTokenToServer(userId, newToken);
        }
      });

      _initialized = true;
    } catch (e) {
      debugPrint('Failed to initialize FcmService: $e');
    }
  }

  /// Check if the app was launched from a terminated state via an FCM notification
  static Future<void> handleColdStart() async {
    try {
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('App opened from terminated state via FCM notification click!');
        _handleNotificationData(initialMessage.data);
      }
    } catch (e) {
      debugPrint('Failed to handle FCM cold start: $e');
    }
  }

  static void _handleNotificationData(Map<String, dynamic> data) {
    final type = data['type'] ?? '';
    if (type == 'daily_report' || type == 'floats' || data['click_action'] == 'FLUTTER_NOTIFICATION_CLICK') {
      if (NotificationHelper.onNotificationTap != null) {
        NotificationHelper.onNotificationTap!(type.isNotEmpty ? type : 'daily_report');
      }
    }
  }

  /// Request permissions for iOS and Android 13+
  static Future<void> requestPermissions() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('User notification permission status: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('Failed to request FCM notification permissions: $e');
    }
  }

  /// Retrieve the current FCM token and upload it to the backend server
  static Future<void> registerDevice(String userId) async {
    try {
      await init();
      await requestPermissions();
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        debugPrint('FCM Token retrieved: $token');
        await _uploadTokenToServer(userId, token);
      }
    } catch (e) {
      debugPrint('Failed to register FCM device: $e');
    }
  }

  /// Unregister device token when logging out or deleting account
  static Future<void> unregisterDevice(String userId) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        final url = Uri.parse('${AppConfig.backendUrl}/api/v1/users/$userId/fcm-token');
        final response = await http.delete(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'token': token}),
        );
        if (response.statusCode == 200) {
          debugPrint('FCM token removed from server successfully.');
        } else {
          debugPrint('Failed to remove FCM token from server: ${response.statusCode}');
        }
      }
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('Failed to unregister FCM device: $e');
    }
  }

  static Future<void> _uploadTokenToServer(String userId, String token) async {
    try {
      final url = Uri.parse('${AppConfig.backendUrl}/api/v1/users/$userId/fcm-token');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token}),
      );
      if (response.statusCode == 200) {
        debugPrint('FCM token uploaded to server successfully.');
      } else {
        debugPrint('Failed to upload FCM token to server: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Error uploading FCM token: $e');
    }
  }
}
