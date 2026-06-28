import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'auth_screen.dart';
import 'delete_account_screen.dart';
import 'config.dart';
import 'widgets/app_top_bar.dart';
import 'services/background_scheduler.dart';
import 'widgets/account_bottom_sheet.dart';
import 'services/fcm_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _markEmailsUnread = true;
  bool _sendFloatsSilent = true;
  int _floatsFrequencyHours = 2;
  bool _floatsEnabled = true;
  bool _reportIncludeTasks = true;
  bool _reportIncludeCalendar = true;
  bool _reportIncludeEmails = true;
  bool _reportIncludeFloats = true;

  // Report Time (in sync with main shell / drawer)
  int _reportHour = 20;
  int _reportMinute = 0;

  // Silent Hours
  int _silentStartHour = 12;
  int _silentStartMinute = 0;
  int _silentEndHour = 6;
  int _silentEndMinute = 0;

  // Account details (Read-only as per instructions, taken from auth)
  String _name = 'Anurag';
  String _email = 'anuragkumartiwari12@gmail.com';
  String? _pictureUrl;

  String get _userInitials {
    if (_name.isEmpty) return 'A';
    return _name[0].toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _markEmailsUnread = prefs.getBool('mark_emails_unread') ?? true;
      _sendFloatsSilent = prefs.getBool('send_floats_silent') ?? true;
      _floatsFrequencyHours = prefs.getInt('floats_frequency_hours') ?? 2;
      _floatsEnabled = prefs.getBool('floats_enabled') ?? true;
      _reportIncludeTasks = prefs.getBool('report_include_tasks') ?? true;
      _reportIncludeCalendar = prefs.getBool('report_include_calendar') ?? true;
      _reportIncludeEmails = prefs.getBool('report_include_emails') ?? true;
      _reportIncludeFloats = prefs.getBool('report_include_floats') ?? true;

      _reportHour = prefs.getInt('report_hour') ?? 20;
      _reportMinute = prefs.getInt('report_minute') ?? 0;

      _silentStartHour = prefs.getInt('silent_start_hour') ?? 12;
      _silentStartMinute = prefs.getInt('silent_start_minute') ?? 0;
      _silentEndHour = prefs.getInt('silent_end_hour') ?? 6;
      _silentEndMinute = prefs.getInt('silent_end_minute') ?? 0;

      _name = prefs.getString('user_name') ?? 'Anurag';
      _email = prefs.getString('user_email') ?? 'anuragkumartiwari12@gmail.com';
      _pictureUrl = prefs.getString('user_picture');
    });

    final userId = prefs.getString('user_id') ?? '';
    if (userId.isNotEmpty) {
      try {
        final response = await http.get(
          Uri.parse('${AppConfig.backendUrl}/api/v1/users/$userId/settings'),
        );
        if (response.statusCode == 200) {
          final Map<String, dynamic> body = jsonDecode(response.body);
          if (body['success'] == true && body['data'] != null) {
            final data = body['data'];
            setState(() {
              _markEmailsUnread = data['markEmailsUnread'] ?? _markEmailsUnread;
              _sendFloatsSilent = data['sendFloatsSilent'] ?? _sendFloatsSilent;
              _floatsFrequencyHours =
                  data['floatsFrequencyHours'] ?? _floatsFrequencyHours;
              _floatsEnabled = data['floatsEnabled'] ?? _floatsEnabled;
              _reportIncludeTasks =
                  data['reportIncludeTasks'] ?? _reportIncludeTasks;
              _reportIncludeCalendar =
                  data['reportIncludeCalendar'] ?? _reportIncludeCalendar;
              _reportIncludeEmails =
                  data['reportIncludeEmails'] ?? _reportIncludeEmails;
              _reportIncludeFloats =
                  data['reportIncludeFloats'] ?? _reportIncludeFloats;
              _reportHour = data['reportHour'] ?? _reportHour;
              _reportMinute = data['reportMinute'] ?? _reportMinute;
              _silentStartHour = data['silentStartHour'] ?? _silentStartHour;
              _silentStartMinute =
                  data['silentStartMinute'] ?? _silentStartMinute;
              _silentEndHour = data['silentEndHour'] ?? _silentEndHour;
              _silentEndMinute = data['silentEndMinute'] ?? _silentEndMinute;
            });

            await prefs.setBool('mark_emails_unread', _markEmailsUnread);
            await prefs.setBool('send_floats_silent', _sendFloatsSilent);
            await prefs.setInt('floats_frequency_hours', _floatsFrequencyHours);
            await prefs.setBool('floats_enabled', _floatsEnabled);
            await prefs.setBool('report_include_tasks', _reportIncludeTasks);
            await prefs.setBool(
              'report_include_calendar',
              _reportIncludeCalendar,
            );
            await prefs.setBool('report_include_emails', _reportIncludeEmails);
            await prefs.setBool('report_include_floats', _reportIncludeFloats);
            await prefs.setInt('report_hour', _reportHour);
            await prefs.setInt('report_minute', _reportMinute);
            await prefs.setInt('silent_start_hour', _silentStartHour);
            await prefs.setInt('silent_start_minute', _silentStartMinute);
            await prefs.setInt('silent_end_hour', _silentEndHour);
            await prefs.setInt('silent_end_minute', _silentEndMinute);
          }
        }
      } catch (e) {
        debugPrint('Failed to load settings from backend: $e');
      }
    }
  }

  String _toCamelCase(String snakeCase) {
    List<String> parts = snakeCase.split('_');
    if (parts.isEmpty) return '';
    String camel = parts[0];
    for (int i = 1; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        camel += parts[i][0].toUpperCase() + parts[i].substring(1);
      }
    }
    return camel;
  }

  Future<void> _syncSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';
    if (userId.isEmpty) return;

    final backendKey = _toCamelCase(key);
    if (backendKey.isEmpty || backendKey == 'timeSaved') return;

    try {
      await http.put(
        Uri.parse('${AppConfig.backendUrl}/api/v1/users/$userId/settings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({backendKey: value}),
      );
    } catch (e) {
      debugPrint('Failed to sync setting $key to backend: $e');
    }
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    await _syncSetting(key, value);
    if (key == 'floats_enabled') {
      await BackgroundScheduler.scheduleFloats(_floatsFrequencyHours, value);
    }
  }

  Future<void> _saveInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
    await _syncSetting(key, value);
    if (key == 'floats_frequency_hours') {
      await BackgroundScheduler.scheduleFloats(value, _floatsEnabled);
    } else if (key == 'report_hour') {
      await BackgroundScheduler.scheduleDailyReport(value, _reportMinute);
    } else if (key == 'report_minute') {
      await BackgroundScheduler.scheduleDailyReport(_reportHour, value);
    }
  }

  String _formattedTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    var hourOfPeriod = hour % 12;
    if (hourOfPeriod == 0) hourOfPeriod = 12;
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$hourOfPeriod : $minuteStr $period';
  }

  Future<void> _pickReportTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reportHour, minute: _reportMinute),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFF5B24),
              onSurface: Colors.black87,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFF5B24),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _reportHour = picked.hour;
        _reportMinute = picked.minute;
      });
      await _saveInt('report_hour', picked.hour);
      await _saveInt('report_minute', picked.minute);
      await _saveInt('time_saved', 1); // trigger state sync flag
    }
  }

  Future<void> _scheduleTestNotification() async {
    await BackgroundScheduler.scheduleTestNotification();
    if (!mounted) return;

    final fireTime = DateTime.now().add(const Duration(minutes: 1));
    final formattedFireTime = _formattedTime(fireTime.hour, fireTime.minute);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Test report scheduled for about $formattedFireTime.',
          style: const TextStyle(fontFamily: 'Open Sans'),
        ),
        backgroundColor: const Color(0xFFFF5B24),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _pickSilentHoursStart() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _silentStartHour,
        minute: _silentStartMinute,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFF5B24),
              onSurface: Colors.black87,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFF5B24),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _silentStartHour = picked.hour;
        _silentStartMinute = picked.minute;
      });
      await _saveInt('silent_start_hour', picked.hour);
      await _saveInt('silent_start_minute', picked.minute);
    }
  }

  Future<void> _pickSilentHoursEnd() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _silentEndHour, minute: _silentEndMinute),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFF5B24),
              onSurface: Colors.black87,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFF5B24),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _silentEndHour = picked.hour;
        _silentEndMinute = picked.minute;
      });
      await _saveInt('silent_end_hour', picked.hour);
      await _saveInt('silent_end_minute', picked.minute);
    }
  }

  void _showFrequencySheet() {
    int tempHours = _floatsFrequencyHours;
    final FixedExtentScrollController wheelController =
        FixedExtentScrollController(initialItem: tempHours - 1);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEEEEE),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'How often?',
                    style: TextStyle(
                      fontFamily: 'Open Sans',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF5B24),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Choose how frequently you want to receive your Floats.',
                    style: TextStyle(
                      fontFamily: 'Open Sans',
                      fontSize: 13,
                      color: Color(0xFF888888),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Every',
                        style: TextStyle(
                          fontFamily: 'Open Sans',
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF222222),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 80,
                        height: 120,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F7F7),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListWheelScrollView.useDelegate(
                          controller: wheelController,
                          itemExtent: 44,
                          perspective: 0.003,
                          diameterRatio: 1.6,
                          physics: const FixedExtentScrollPhysics(),
                          onSelectedItemChanged: (index) {
                            setSheetState(() => tempHours = index + 1);
                          },
                          childDelegate: ListWheelChildBuilderDelegate(
                            builder: (context, index) {
                              final isSelected = tempHours == index + 1;
                              return Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontFamily: 'Open Sans',
                                    fontSize: 22,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: isSelected
                                        ? const Color(0xFFFF5B24)
                                        : const Color(0xFFAAAAAA),
                                  ),
                                ),
                              );
                            },
                            childCount: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 72,
                        child: Text(
                          tempHours == 1 ? 'Hour' : 'Hours',
                          style: const TextStyle(
                            fontFamily: 'Open Sans',
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF222222),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        setState(() => _floatsFrequencyHours = tempHours);
                        Navigator.pop(ctx);
                        await _saveInt('floats_frequency_hours', tempHours);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5B24),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Confirm',
                        style: TextStyle(
                          fontFamily: 'Open Sans',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            'Logout',
            style: TextStyle(
              fontFamily: 'Open Sans',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(fontFamily: 'Open Sans'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey, fontFamily: 'Open Sans'),
              ),
            ),
            TextButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                navigator.pop();
                final prefs = await SharedPreferences.getInstance();
                final userId = prefs.getString('user_id') ?? '';
                if (userId.isNotEmpty) {
                  try {
                    await FcmService.unregisterDevice(userId);
                  } catch (e) {
                    debugPrint('Failed to unregister FCM: $e');
                  }
                }
                await prefs.clear();
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                  (route) => false,
                );
              },
              child: const Text(
                'Logout',
                style: TextStyle(
                  color: Color(0xFFFF5B24),
                  fontFamily: 'Open Sans',
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _navigateToDeleteAccountScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DeleteAccountScreen()),
    );
  }

  void _showFeedbackBottomSheet() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEEEEE),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Send Feedback',
                  style: TextStyle(
                    fontFamily: 'Open Sans',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tell us what you think or report issues. We read all feedback.',
                  style: TextStyle(
                    fontFamily: 'Open Sans',
                    fontSize: 14,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  maxLines: 4,
                  autofocus: true,
                  style: const TextStyle(
                    fontFamily: 'Open Sans',
                    color: Color(0xFF333333),
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Type your feedback here...',
                    hintStyle: TextStyle(color: Color(0xFF999999)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(
                        color: Color(0xFFFF5B24),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey,
                          fontFamily: 'Open Sans',
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () async {
                        final feedback = controller.text.trim();
                        Navigator.pop(context);
                        if (feedback.isNotEmpty) {
                          final scaffoldMessenger = ScaffoldMessenger.of(
                            context,
                          );
                          final prefs = await SharedPreferences.getInstance();
                          final userId = prefs.getString('user_id') ?? '';
                          final email = prefs.getString('user_email') ?? '';

                          try {
                            final response = await http.post(
                              Uri.parse(
                                '${AppConfig.backendUrl}/api/v1/feedback',
                              ),
                              headers: {'Content-Type': 'application/json'},
                              body: jsonEncode({
                                'userId': userId.isNotEmpty ? userId : null,
                                'email': email.isNotEmpty ? email : null,
                                'text': feedback,
                              }),
                            );

                            if (response.statusCode == 201 ||
                                response.statusCode == 200) {
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'Feedback sent! Thank you.',
                                    style: TextStyle(fontFamily: 'Open Sans'),
                                  ),
                                  backgroundColor: const Color(0xFFFF5B24),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                            } else {
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Failed to submit feedback. Please try again.',
                                    style: TextStyle(fontFamily: 'Open Sans'),
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } catch (e) {
                            debugPrint('Error sending feedback: $e');
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Error: $e. Please check your connection.',
                                  style: TextStyle(fontFamily: 'Open Sans'),
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5B24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'Submit',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Open Sans',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            'Help & FAQ',
            style: TextStyle(
              fontFamily: 'Open Sans',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'What is Briefly?',
                  style: TextStyle(
                    fontFamily: 'Open Sans',
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Briefly aggregates your emails, calendar events, and tasks into a single daily report delivered at your preferred time.',
                  style: TextStyle(
                    fontFamily: 'Open Sans',
                    fontSize: 13,
                    color: Color(0xFF606060),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'What are Floats?',
                  style: TextStyle(
                    fontFamily: 'Open Sans',
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Floats are periodic reminders containing your stored wisdom or notes, delivered every N hours.',
                  style: TextStyle(
                    fontFamily: 'Open Sans',
                    fontSize: 13,
                    color: Color(0xFF606060),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'How do Silent Hours work?',
                  style: TextStyle(
                    fontFamily: 'Open Sans',
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'When Silent Hours are active, Floats will not trigger notifications unless "Send Floats During Silent Hours" is toggled ON.',
                  style: TextStyle(
                    fontFamily: 'Open Sans',
                    fontSize: 13,
                    color: Color(0xFF606060),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Close',
                style: TextStyle(
                  color: Color(0xFFFF5B24),
                  fontFamily: 'Open Sans',
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppTopBar(
        title: 'Settings',
        showBackButton: true,
        userInitials: _userInitials,
        userPictureUrl: _pictureUrl,
        onAccountTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (sheetContext) {
              return AccountBottomSheet(
                userName: _name,
                userEmail: _email,
                userPictureUrl: _pictureUrl,
                onSettingsTap: () {
                  // Already on settings screen
                },
              );
            },
          );
        },
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadSettings,
          color: const Color(0xFFFF5B24),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Report Settings
                  _buildSectionHeader('Report Settings'),
                  _buildSectionCard([
                    _buildToggleRow('Mark emails unread', _markEmailsUnread, (
                      val,
                    ) {
                      setState(() => _markEmailsUnread = val);
                      _saveBool('mark_emails_unread', val);
                    }),
                    const Divider(color: Color(0xFFE5E7EB), height: 1),
                    _buildTappableRow(
                      'Report Time',
                      _formattedTime(_reportHour, _reportMinute),
                      _pickReportTime,
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // Report Content
                  _buildSectionHeader('Report Content'),
                  _buildSectionCard([
                    _buildToggleRow('Add Tasks', _reportIncludeTasks, (val) {
                      setState(() => _reportIncludeTasks = val);
                      _saveBool('report_include_tasks', val);
                    }),
                    const Divider(color: Color(0xFFE5E7EB), height: 1),
                    _buildToggleRow(
                      'Add Calendar Events',
                      _reportIncludeCalendar,
                      (val) {
                        setState(() => _reportIncludeCalendar = val);
                        _saveBool('report_include_calendar', val);
                      },
                    ),
                    const Divider(color: Color(0xFFE5E7EB), height: 1),
                    _buildToggleRow('Add Emails', _reportIncludeEmails, (val) {
                      setState(() => _reportIncludeEmails = val);
                      _saveBool('report_include_emails', val);
                    }),
                    const Divider(color: Color(0xFFE5E7EB), height: 1),
                    _buildToggleRow('Add Floats', _reportIncludeFloats, (val) {
                      setState(() => _reportIncludeFloats = val);
                      _saveBool('report_include_floats', val);
                    }),
                  ]),
                  const SizedBox(height: 20),

                  // Float Settings
                  _buildSectionHeader('Float Settings'),
                  _buildSectionCard([
                    _buildToggleRow('Enable Floats', _floatsEnabled, (val) {
                      setState(() => _floatsEnabled = val);
                      _saveBool('floats_enabled', val);
                    }),
                    Opacity(
                      opacity: _floatsEnabled ? 1.0 : 0.5,
                      child: IgnorePointer(
                        ignoring: !_floatsEnabled,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(color: Color(0xFFE5E7EB), height: 1),
                            _buildToggleRow(
                              'Send Floats During Silent Hours',
                              _sendFloatsSilent,
                              (val) {
                                setState(() => _sendFloatsSilent = val);
                                _saveBool('send_floats_silent', val);
                              },
                            ),
                            const Divider(color: Color(0xFFE5E7EB), height: 1),
                            _buildTappableRow(
                              'Frequency',
                              'Every $_floatsFrequencyHours ${_floatsFrequencyHours == 1 ? 'Hour' : 'Hours'}',
                              _showFrequencySheet,
                            ),
                            const Divider(color: Color(0xFFE5E7EB), height: 1),
                            _buildTappableRow(
                              'Starts At :',
                              _formattedTime(
                                _silentStartHour,
                                _silentStartMinute,
                              ),
                              _pickSilentHoursStart,
                            ),
                            const Divider(color: Color(0xFFE5E7EB), height: 1),
                            _buildTappableRow(
                              'Ends At :',
                              _formattedTime(_silentEndHour, _silentEndMinute),
                              _pickSilentHoursEnd,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // Account Settings
                  _buildSectionHeader('Account Settings'),
                  _buildSectionCard([
                    _buildStaticRow('Name :', _name),
                    const Divider(color: Color(0xFFE5E7EB), height: 1),
                    _buildStaticRow('Email :', _email),
                    const Divider(color: Color(0xFFE5E7EB), height: 1),
                    _buildActionRow(
                      'Logout',
                      const Color(0xFFEA4335),
                      _confirmLogout,
                    ),
                    const Divider(color: Color(0xFFE5E7EB), height: 1),
                    _buildActionRow(
                      'Delete Account',
                      const Color(0xFFEA4335),
                      _navigateToDeleteAccountScreen,
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // Support & Feedback
                  _buildSectionHeader('Support & Feedback'),
                  _buildSectionCard([
                    _buildTappableActionRow('Feedback', _showFeedbackBottomSheet),
                    const Divider(color: Color(0xFFE5E7EB), height: 1),
                    _buildTappableActionRow('Help', _showHelpDialog),
                  ]),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Open Sans',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF888888),
        ),
      ),
    );
  }

  Widget _buildToggleRow(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Open Sans',
                fontSize: 16,
                color: Color(0xFF222222),
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFFFF5B24),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFE0E0E0),
          ),
        ],
      ),
    );
  }

  Widget _buildTappableRow(String label, String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Open Sans',
                fontSize: 16,
                color: Color(0xFF222222),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Open Sans',
                    fontSize: 16,
                    fontWeight: FontWeight.normal,
                    color: Color(0xFFFF5B24),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.edit_rounded,
                  color: Color(0xFFFF5B24),
                  size: 14,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaticRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Open Sans',
              fontSize: 16,
              color: Color(0xFF222222),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Open Sans',
                fontSize: 16,
                color: Color(0xFF888888),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Open Sans',
                fontSize: 16,
                fontWeight: FontWeight.normal,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTappableActionRow(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Open Sans',
                fontSize: 16,
                color: Color(0xFF222222),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
