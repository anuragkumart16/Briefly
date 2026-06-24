import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Default: 8:00 PM
  TimeOfDay _selectedTime = const TimeOfDay(hour: 20, minute: 0);
  bool _timeSaved = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    _loadSavedTime();

    // Auto-open drawer on first launch if no time saved yet
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool('time_saved') ?? false;
      if (!saved && mounted) {
        _scaffoldKey.currentState?.openDrawer();
      }
    });
  }

  Future<void> _loadSavedTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt('report_hour');
    final minute = prefs.getInt('report_minute');
    final saved = prefs.getBool('time_saved') ?? false;
    if (hour != null && minute != null && mounted) {
      setState(() {
        _selectedTime = TimeOfDay(hour: hour, minute: minute);
        _timeSaved = saved;
      });
    }
  }

  Future<void> _saveTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('report_hour', _selectedTime.hour);
    await prefs.setInt('report_minute', _selectedTime.minute);
    await prefs.setBool('time_saved', true);
    setState(() => _timeSaved = true);
    if (mounted) {
      _scaffoldKey.currentState?.closeDrawer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Report time saved: ${_formattedTime(_selectedTime)}',
            style: const TextStyle(fontFamily: 'Open Sans'),
          ),
          backgroundColor: const Color(0xFFFF7F55),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFF7F55),
              onSurface: Colors.black87,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF7F55)),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  String _formattedTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour : $minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Color(0xFFFF5B24)),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text(
          'Briefly',
          style: TextStyle(
            fontFamily: 'Arya',
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFF5B24),
          ),
        ),
        actions: [
          if (_timeSaved)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  _formattedTime(_selectedTime),
                  style: const TextStyle(
                    fontFamily: 'Open Sans',
                    fontSize: 13,
                    color: Color(0xFF606060),
                  ),
                ),
              ),
            ),
        ],
      ),
      drawer: _buildDrawer(),
      body: const Center(
        child: Text(
          'Your daily reports will appear here.',
          style: TextStyle(
            fontFamily: 'Open Sans',
            fontSize: 16,
            color: Color(0xFF606060),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drawer header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Briefly',
                    style: TextStyle(
                      fontFamily: 'Arya',
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF5B24),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Preferences',
                    style: TextStyle(
                      fontFamily: 'Open Sans',
                      fontSize: 14,
                      color: Color(0xFF606060),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFFEEEEEE)),
                ],
              ),
            ),

            // Time picker section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    const Text(
                      'Report Time',
                      style: TextStyle(
                        fontFamily: 'Open Sans',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF606060),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Orange card — matches screenshot design
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF7F55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                      child: Column(
                        children: [
                          const Text(
                            'What time would you like to receive the report?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Open Sans',
                              fontSize: 16,
                              color: Colors.white,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Time display — tappable
                          GestureDetector(
                            onTap: _pickTime,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                _formattedTime(_selectedTime),
                                style: const TextStyle(
                                  fontFamily: 'Open Sans',
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Continue button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _saveTime,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black87,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Continue',
                                style: TextStyle(
                                  fontFamily: 'Open Sans',
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
