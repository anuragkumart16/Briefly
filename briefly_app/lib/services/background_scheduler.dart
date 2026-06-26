import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import '../config.dart';
import 'notification_helper.dart';

@pragma('vm:entry-point')
void dailyReportAlarmCallback() async {
  // 1. Initialize notification helper inside background isolate
  await NotificationHelper.init();
  
  // 2. Load SharedPreferences to get configurations
  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString('user_id') ?? '';
  
  if (userId.isEmpty) {
    await NotificationHelper.showNotification(
      id: 100,
      title: 'Daily Report',
      body: 'Your Daily Report is ready! Tap to view.',
    );
    return;
  }
  
  await NotificationHelper.showNotification(
    id: 100,
    title: 'Daily Report',
    body: 'Your unified Daily Report has been prepared.',
  );
}

@pragma('vm:entry-point')
void periodicFloatsAlarmCallback() async {
  // 1. Initialize notification helper inside background isolate
  await NotificationHelper.init();
  
  // 2. Load SharedPreferences to check status and active silent window
  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString('user_id') ?? '';
  final floatsEnabled = prefs.getBool('floats_enabled') ?? true;
  final sendFloatsSilent = prefs.getBool('send_floats_silent') ?? true;
  
  if (userId.isEmpty || !floatsEnabled) return;
  
  // Verify if it is silent hours
  if (!sendFloatsSilent) {
    final silentStartHour = prefs.getInt('silent_start_hour') ?? 12;
    final silentStartMinute = prefs.getInt('silent_start_minute') ?? 0;
    final silentEndHour = prefs.getInt('silent_end_hour') ?? 6;
    final silentEndMinute = prefs.getInt('silent_end_minute') ?? 0;
    
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = silentStartHour * 60 + silentStartMinute;
    final endMinutes = silentEndHour * 60 + silentEndMinute;
    
    bool isSilent = false;
    if (startMinutes < endMinutes) {
      isSilent = currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    } else {
      isSilent = currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    }
    
    if (isSilent) {
      // Do not send floats during silent hours
      return;
    }
  }
  
  // 3. Fetch active floats from the backend database
  try {
    final response = await http.get(
      Uri.parse('${AppConfig.backendUrl}/api/v1/users/$userId/floats'),
    );
    
    if (response.statusCode == 200) {
      final Map<String, dynamic> body = jsonDecode(response.body);
      if (body['success'] == true && body['data'] != null) {
        final List<dynamic> floatsData = body['data'];
        
        final activeFloats = floatsData
            .where((json) => json['isActive'] == true)
            .map((json) => json['text'] as String)
            .toList();
            
        if (activeFloats.isNotEmpty) {
          final random = Random();
          final selectedFloat = activeFloats[random.nextInt(activeFloats.length)];
          
          await NotificationHelper.showNotification(
            id: 200 + random.nextInt(100),
            title: 'Briefly Floats',
            body: selectedFloat,
          );
        }
      }
    }
  } catch (e) {
    // Fail silently in background isolate
  }
}

class BackgroundScheduler {
  static const int _dailyReportAlarmId = 100;
  static const int _periodicFloatsAlarmId = 200;

  static Future<void> scheduleDailyReport(int hour, int minute) async {
    await AndroidAlarmManager.cancel(_dailyReportAlarmId);
    
    final now = DateTime.now();
    var scheduleTime = DateTime(now.year, now.month, now.day, hour, minute);
    
    if (scheduleTime.isBefore(now)) {
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
      exact: false, // inexact saves battery for general periodic syncs
      wakeup: true,
      rescheduleOnReboot: true,
    );
  }
  
  static Future<void> cancelAll() async {
    await AndroidAlarmManager.cancel(_dailyReportAlarmId);
    await AndroidAlarmManager.cancel(_periodicFloatsAlarmId);
  }
}
