import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'home_screen.dart';
import 'config.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const String _googleServerClientId = AppConfig.googleServerClientId;

  TimeOfDay _selectedTime = const TimeOfDay(hour: 20, minute: 30);

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
  }

  String _formattedTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour : $minute $period';
  }

  Future<void> _saveAndContinue() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';
    final hour = _selectedTime.hour;
    final minute = _selectedTime.minute;

    if (userId.isNotEmpty) {
      try {
        await http.put(
          Uri.parse('${AppConfig.backendUrl}/api/v1/users/$userId/settings'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'reportHour': hour,
            'reportMinute': minute,
          }),
        );
      } catch (e) {
        debugPrint('Failed to sync report time to backend settings: $e');
      }
    }

    await prefs.setInt('report_hour', hour);
    await prefs.setInt('report_minute', minute);
    await prefs.setBool('time_saved', true);
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  Future<void> _onGooglePressed() async {
    final GoogleSignIn googleSignIn = GoogleSignIn(
      scopes: [
        'email',
        'profile',
        'https://www.googleapis.com/auth/gmail.modify',
        'https://www.googleapis.com/auth/calendar',
        'https://www.googleapis.com/auth/tasks',
      ],
      serverClientId: _googleServerClientId == 'YOUR_GOOGLE_SERVER_CLIENT_ID.apps.googleusercontent.com' ? null : _googleServerClientId,
      forceCodeForRefreshToken: true,
    );

    try {
      final GoogleSignInAccount? account = await googleSignIn.signIn();
      if (account == null) {
        // User cancelled the sign-in flow
        return;
      }

      final String? authCode = account.serverAuthCode;
      if (authCode == null) {
        throw Exception(
          'Failed to retrieve authorization code. Make sure you set a valid Web client ID in the _googleServerClientId constant.',
        );
      }

      // Show loading indicator dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF5B24)),
          ),
        ),
      );

      // POST authorization code to the backend service
      final response = await http.post(
        Uri.parse('${AppConfig.backendUrl}/api/v1/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': authCode}),
      );

      // Dismiss the loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', true);
        
        if (responseData['success'] == true && responseData['data'] != null) {
          final user = responseData['data']['user'];
          if (user != null) {
            await prefs.setString('user_id', user['id'] ?? '');
            await prefs.setString('user_email', user['email'] ?? '');
            await prefs.setString('user_name', user['name'] ?? '');
            await prefs.setString('user_picture', user['picture'] ?? '');
          }
        }

        // Success: Proceed to time setup bottom sheet
        if (mounted) {
          _showTimePickerSheet();
        }
      } else {
        throw Exception(
          'Backend returned error status code ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Sign-In failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showTimePickerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
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
                  // Handle bar
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
                    'Set Report Time',
                    style: TextStyle(
                      fontFamily: 'Open Sans',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF5B24),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'What time would you like to receive your daily report?',
                    style: TextStyle(
                      fontFamily: 'Open Sans',
                      fontSize: 13,
                      color: Color(0xFF888888),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Time display — tappable
                  GestureDetector(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _selectedTime,
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: Color(0xFFFF5B24),
                                onSurface: Colors.black87,
                              ),
                              textButtonTheme: TextButtonThemeData(
                                style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFFFF5B24)),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() => _selectedTime = picked);
                        setSheetState(() {});
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formattedTime(_selectedTime),
                            style: const TextStyle(
                              fontFamily: 'Open Sans',
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF222222),
                            ),
                          ),
                          const Icon(
                            Icons.access_time_rounded,
                            color: Color(0xFFFF5B24),
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Continue button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveAndContinue,
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
                        'Continue',
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            children: [
              const Spacer(),
              // Briefly Title and Description
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Briefly',
                    style: TextStyle(
                      fontFamily: 'Arya',
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF5B24),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'News about you packed in\ndaily reports',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Open Sans',
                      fontSize: 20,
                      fontWeight: FontWeight.normal,
                      color: Color(0xFF606060),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Continue with Google Button
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _onGooglePressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7F55),
                      elevation: 2,
                      shadowColor: const Color(0xFFFF7F55).withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const _GoogleGLogo(size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Continue with Google',
                          style: TextStyle(
                            fontFamily: 'Open Sans',
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleGLogo extends StatelessWidget {
  final double size;
  const _GoogleGLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GoogleGPainter(),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2;
    final double strokeW = r * 0.36;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r - strokeW / 2);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.butt;

    // Red arc
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, _deg(-30), _deg(90), false, paint);

    // Yellow arc
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, _deg(60), _deg(90), false, paint);

    // Green arc
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, _deg(150), _deg(90), false, paint);

    // Blue arc (dominant)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, _deg(240), _deg(120), false, paint);

    // Blue crossbar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTRB(cx, cy - strokeW / 2, cx + r, cy + strokeW / 2),
      barPaint,
    );
  }

  double _deg(double d) => d * 3.141592653589793 / 180;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
