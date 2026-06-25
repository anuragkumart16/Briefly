import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'floats_onboarding_screen.dart';
import 'floats_screen.dart';
import 'home_screen.dart';
import 'widgets/app_bottom_nav_bar.dart';
import 'widgets/app_top_bar.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  final GlobalKey<FloatsBodyState> _floatsBodyKey = GlobalKey<FloatsBodyState>();

  // Controllers owned here so search bar stays alive across tab switches
  final TextEditingController _floatsSearchController = TextEditingController();
  String _floatsSearchQuery = '';

  // Report time state (owned here so drawer can be in the shell)
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

  Future<void> _onTabTapped(int index) async {
    if (index == 1) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const FloatsOnboardingScreen()),
      );
      if (mounted) {
        setState(() => _selectedIndex = 1);
        _pageController.animateToPage(
          1,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
      return;
    }
    setState(() => _selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _floatsSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      appBar: AppTopBar(
        title: 'Briefly',
        onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
        onAccountTap: () {
          // TODO: Navigate to account/profile screen
        },
        // Switch to search mode on Floats tab
        searchController: _selectedIndex == 1 ? _floatsSearchController : null,
        onSearchChanged: _selectedIndex == 1
            ? (v) => setState(() => _floatsSearchQuery = v)
            : null,
      ),
      drawer: _buildDrawer(),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Tab 0: Report
          const _KeepAlive(child: HomeBody()),
          // Tab 1: Floats
          _KeepAlive(
            child: FloatsBody(
              key: _floatsBodyKey,
              searchController: _floatsSearchController,
              searchQuery: _floatsSearchQuery,
              onSearchChanged: (v) => setState(() => _floatsSearchQuery = v),
            ),
          ),
          // Tab 2: Settings (stub)
          const _KeepAlive(
            child: Center(
              child: Text(
                'Settings coming soon.',
                style: TextStyle(fontFamily: 'Open Sans', fontSize: 16, color: Color(0xFF888888)),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton(
              onPressed: () => _floatsBodyKey.currentState?.showAddFloatSheet(),
              backgroundColor: const Color(0xFFFF5B24),
              elevation: 4,
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            )
          : null,
      bottomNavigationBar: AppBottomNavBar(
        selectedIndex: _selectedIndex,
        onTabTapped: _onTabTapped,
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

/// Keeps a PageView child alive in memory even when it's not the current page.
class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
