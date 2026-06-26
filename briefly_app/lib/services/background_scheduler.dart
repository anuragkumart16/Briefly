import 'dart:convert';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import '../config.dart';
import 'notification_helper.dart';
import 'floats_sync_service.dart';

String _localDateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

// ─────────────────────────────────────────────────────────────────────────────
// Daily report alarm — runs in background isolate
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
void dailyReportAlarmCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _runDailyReportAlarm();
}

Future<void> _runDailyReportAlarm({
  bool bypassDailyGuard = false,
  bool markDailyNotification = true,
}) async {
  await NotificationHelper.init();

  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString('user_id') ?? '';

  if (userId.isEmpty) return;

  final now = DateTime.now();
  final todayKey = _localDateKey(now);
  final lastNotificationDate = prefs.getString('last_report_notification_date');

  if (!bypassDailyGuard && lastNotificationDate == todayKey) return;

  try {
    final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    final url = Uri.parse('${AppConfig.backendUrl}/api/v1/users/$userId/report')
        .replace(
          queryParameters: {
            'timeMin': todayStart.toUtc().toIso8601String(),
            'timeMax': todayEnd.toUtc().toIso8601String(),
          },
        );

    final response = await http.get(url).timeout(const Duration(seconds: 45));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['success'] == true && body['data'] != null) {
        // Persist the full report JSON so HomeBody can load it on next open
        await prefs.setString('cached_report', jsonEncode(body['data']));
        await prefs.setString('cached_report_date', now.toIso8601String());

        // Build a short preview from the summary field
        final data = body['data'] as Map<String, dynamic>;
        final preview =
            (data['summary'] as String? ?? 'Your daily briefing is ready.')
                .split('.')
                .first
                .trim();

        await NotificationHelper.showReportNotification(
          title: 'Today\'s Briefing is ready ✨',
          body: preview.isNotEmpty
              ? '$preview.'
              : 'Tap to view your daily report.',
        );
        if (markDailyNotification) {
          await prefs.setString('last_report_notification_date', todayKey);
        }
        return;
      }
    }

    await NotificationHelper.showReportNotification(
      title: 'Daily Report',
      body: 'Tap to open Briefly and fetch your report.',
    );
    if (markDailyNotification) {
      await prefs.setString('last_report_notification_date', todayKey);
    }
  } catch (e) {
    // Fail silently — don't crash the background isolate
    try {
      await NotificationHelper.showReportNotification(
        title: 'Daily Report',
        body: 'Your briefing is ready. Tap to view.',
      );
      if (markDailyNotification) {
        await prefs.setString('last_report_notification_date', todayKey);
      }
    } catch (_) {}
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Float alarm — runs in background isolate
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
void periodicFloatsAlarmCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationHelper.init();

  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString('user_id') ?? '';
  final floatsEnabled = prefs.getBool('floats_enabled') ?? true;
  final sendFloatsSilent = prefs.getBool('send_floats_silent') ?? true;

  if (userId.isEmpty || !floatsEnabled) return;

  // Check silent hours
  if (!sendFloatsSilent) {
    final silentStartHour = prefs.getInt('silent_start_hour') ?? 12;
    final silentStartMinute = prefs.getInt('silent_start_minute') ?? 0;
    final silentEndHour = prefs.getInt('silent_end_hour') ?? 6;
    final silentEndMinute = prefs.getInt('silent_end_minute') ?? 0;

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = silentStartHour * 60 + silentStartMinute;
    final endMinutes = silentEndHour * 60 + silentEndMinute;

    bool isSilent;
    if (startMinutes < endMinutes) {
      isSilent = currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    } else {
      isSilent = currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    }

    if (isSilent) return;
  }

  try {
    final response = await http
        .get(Uri.parse('${AppConfig.backendUrl}/api/v1/users/$userId/floats'))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['success'] == true && body['data'] != null) {
        final floatsData = body['data'] as List<dynamic>;
        final activeFloats = floatsData
            .where((j) => j['isActive'] == true)
            .map((j) => j['text'] as String)
            .toList();

        if (activeFloats.isNotEmpty) {
          final random = Random();
          final selectedFloat =
              activeFloats[random.nextInt(activeFloats.length)];
          await NotificationHelper.showNotification(
            id: 200 + random.nextInt(100),
            title: 'Briefly Floats 💡',
            body: selectedFloat,
          );
        }
      }
    }
  } catch (_) {}
}

// ─────────────────────────────────────────────────────────────────────────────
// Test alarm — runs in background isolate
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
void testSchedulerAlarmCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _runDailyReportAlarm(
    bypassDailyGuard: true,
    markDailyNotification: false,
  );
}
 
// ─────────────────────────────────────────────────────────────────────────────
// Sync Floats alarm — runs in background isolate every 15 minutes
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
void syncFloatsAlarmCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await FloatsSyncService.syncWithServer();
  } catch (_) {}
}

// ─────────────────────────────────────────────────────────────────────────────
// Scheduler API
// ─────────────────────────────────────────────────────────────────────────────
class BackgroundScheduler {
  static const int _dailyReportAlarmId = 100;
  static const int _periodicFloatsAlarmId = 200;
  static const int _testSchedulerAlarmId = 300;
  static const int _syncFloatsAlarmId = 400;
  static const int _defaultReportHour = 20;
  static const int _defaultReportMinute = 0;
  static const int _defaultFloatsFrequencyHours = 2;

  static Future<void> restoreSavedSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';

    if (userId.isEmpty) {
      await cancelAll();
      return;
    }

    final reportHour = prefs.getInt('report_hour') ?? _defaultReportHour;
    final reportMinute = prefs.getInt('report_minute') ?? _defaultReportMinute;
    final floatsEnabled = prefs.getBool('floats_enabled') ?? true;
    final floatsFrequencyHours =
        prefs.getInt('floats_frequency_hours') ?? _defaultFloatsFrequencyHours;

    await scheduleDailyReport(reportHour, reportMinute);
    await scheduleFloats(floatsFrequencyHours, floatsEnabled);
    await scheduleFloatsSync();
  }

  static Future<void> scheduleDailyReport(int hour, int minute) async {
    await AndroidAlarmManager.cancel(_dailyReportAlarmId);

    final now = DateTime.now();
    var scheduleTime = DateTime(now.year, now.month, now.day, hour, minute);
    final isCurrentMinute =
        scheduleTime.year == now.year &&
        scheduleTime.month == now.month &&
        scheduleTime.day == now.day &&
        scheduleTime.hour == now.hour &&
        scheduleTime.minute == now.minute;

    if (isCurrentMinute && !scheduleTime.isAfter(now)) {
      scheduleTime = now.add(const Duration(seconds: 10));
    } else if (scheduleTime.isBefore(now)) {
      scheduleTime = scheduleTime.add(const Duration(days: 1));
    }

    await AndroidAlarmManager.periodic(
      const Duration(hours: 24),
      _dailyReportAlarmId,
      dailyReportAlarmCallback,
      startAt: scheduleTime,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );
  }

  static Future<void> scheduleFloats(int frequencyHours, bool enabled) async {
    await AndroidAlarmManager.cancel(_periodicFloatsAlarmId);
    if (!enabled || frequencyHours <= 0) return;

    await AndroidAlarmManager.periodic(
      Duration(hours: frequencyHours),
      _periodicFloatsAlarmId,
      periodicFloatsAlarmCallback,
      exact: false,
      wakeup: true,
      rescheduleOnReboot: true,
    );
  }

  static Future<void> scheduleTestNotification() async {
    await AndroidAlarmManager.cancel(_testSchedulerAlarmId);
    await AndroidAlarmManager.oneShot(
      const Duration(minutes: 1),
      _testSchedulerAlarmId,
      testSchedulerAlarmCallback,
      exact: true,
      wakeup: true,
    );
  }

  static Future<void> scheduleFloatsSync() async {
    await AndroidAlarmManager.cancel(_syncFloatsAlarmId);
    await AndroidAlarmManager.periodic(
      const Duration(minutes: 15),
      _syncFloatsAlarmId,
      syncFloatsAlarmCallback,
      exact: false,
      wakeup: false,
      rescheduleOnReboot: true,
    );
  }

  static Future<void> cancelAll() async {
    await AndroidAlarmManager.cancel(_dailyReportAlarmId);
    await AndroidAlarmManager.cancel(_periodicFloatsAlarmId);
    await AndroidAlarmManager.cancel(_testSchedulerAlarmId);
    await AndroidAlarmManager.cancel(_syncFloatsAlarmId);
  }
}
