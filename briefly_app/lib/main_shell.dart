import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';
import 'floats_onboarding_screen.dart';
import 'floats_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'widgets/app_bottom_nav_bar.dart';
import 'widgets/app_top_bar.dart';
import 'widgets/account_bottom_sheet.dart';
import 'services/background_scheduler.dart';

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
  bool _floatsEnabled = true;
  int _floatsFrequencyHours = 2;

  // User profile details
  String _userName = 'Anurag';
  String _userEmail = 'anuragkumartiwari12@gmail.com';
  String? _userPictureUrl;

  String get _userInitials {
    if (_userName.isEmpty) return 'A';
    return _userName[0].toUpperCase();
  }

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
      final savedVal = prefs.get('time_saved');
      final saved = savedVal == true || savedVal == 1;
      if (!saved && mounted) {
        _scaffoldKey.currentState?.openDrawer();
      }
    });
  }

  Future<void> _loadSavedTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt('report_hour');
    final minute = prefs.getInt('report_minute');
    final floatsEnabled = prefs.getBool('floats_enabled') ?? true;
    final floatsFrequencyHours = prefs.getInt('floats_frequency_hours') ?? 2;
    final name = prefs.getString('user_name') ?? 'Anurag';
    final email = prefs.getString('user_email') ?? 'anuragkumartiwari12@gmail.com';
    final pictureUrl = prefs.getString('user_picture');
    if (mounted) {
      setState(() {
        if (hour != null && minute != null) {
          _selectedTime = TimeOfDay(hour: hour, minute: minute);
        }
        _floatsEnabled = floatsEnabled;
        _floatsFrequencyHours = floatsFrequencyHours;
        _userName = name;
        _userEmail = email;
        _userPictureUrl = pictureUrl;
      });
    }

    if (hour != null && minute != null) {
      await BackgroundScheduler.scheduleDailyReport(hour, minute);
    }
    await BackgroundScheduler.scheduleFloats(floatsFrequencyHours, floatsEnabled);
  }



  Future<void> _onTabTapped(int index) async {
    if (index == 1) {
      if (!_floatsEnabled) {
        _showEnableFloatsDialog();
        return;
      }
      final navigator = Navigator.of(context);
      final prefs = await SharedPreferences.getInstance();
      final done = prefs.getBool('floats_onboarding_done') ?? false;
      if (!done) {
        await navigator.push(
          MaterialPageRoute(builder: (_) => const FloatsOnboardingScreen()),
        );
      }
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

  void _showEnableFloatsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Enable Floats?',
            style: TextStyle(
              fontFamily: 'Open Sans',
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF5B24),
            ),
          ),
          content: const Text(
            'Floats are currently disabled in settings. Would you like to enable them to view and manage your stored wisdom?',
            style: TextStyle(
              fontFamily: 'Open Sans',
              color: Colors.black87,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'Open Sans',
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('floats_enabled', true);
                setState(() {
                  _floatsEnabled = true;
                });
                await BackgroundScheduler.scheduleFloats(_floatsFrequencyHours, true);
                _onTabTapped(1);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5B24),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text(
                'Enable',
                style: TextStyle(
                  fontFamily: 'Open Sans',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Help & FAQ',
            style: TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.bold),
          ),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'What is Briefly?',
                  style: TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.bold, fontSize: 15),
                ),
                SizedBox(height: 4),
                Text(
                  'Briefly aggregates your emails, calendar events, and tasks into a single daily report delivered at your preferred time.',
                  style: TextStyle(fontFamily: 'Open Sans', fontSize: 13, color: Color(0xFF606060)),
                ),
                SizedBox(height: 12),
                Text(
                  'What are Floats?',
                  style: TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.bold, fontSize: 15),
                ),
                SizedBox(height: 4),
                Text(
                  'Floats are periodic reminders containing your stored wisdom or notes, delivered every N hours.',
                  style: TextStyle(fontFamily: 'Open Sans', fontSize: 13, color: Color(0xFF606060)),
                ),
                SizedBox(height: 12),
                Text(
                  'How do Silent Hours work?',
                  style: TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.bold, fontSize: 15),
                ),
                SizedBox(height: 4),
                Text(
                  'When Silent Hours are active, Floats will not trigger notifications unless "Send Floats During Silent Hours" is toggled ON.',
                  style: TextStyle(fontFamily: 'Open Sans', fontSize: 13, color: Color(0xFF606060)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Color(0xFFFF5B24), fontFamily: 'Open Sans', fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
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
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                      borderSide: BorderSide(color: Color(0xFFFF5B24), width: 1.5),
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
                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                          final prefs = await SharedPreferences.getInstance();
                          final userId = prefs.getString('user_id') ?? '';
                          final email = prefs.getString('user_email') ?? '';
                          
                          try {
                            final response = await http.post(
                              Uri.parse('${AppConfig.backendUrl}/api/v1/feedback'),
                              headers: {'Content-Type': 'application/json'},
                              body: jsonEncode({
                                'userId': userId.isNotEmpty ? userId : null,
                                'email': email.isNotEmpty ? email : null,
                                'text': feedback,
                              }),
                            );
                            
                            if (response.statusCode == 201 || response.statusCode == 200) {
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'Feedback sent! Thank you.',
                                    style: TextStyle(fontFamily: 'Open Sans'),
                                  ),
                                  backgroundColor: const Color(0xFFFF5B24),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            } else {
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to submit feedback. Please try again.', style: TextStyle(fontFamily: 'Open Sans')),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } catch (e) {
                            debugPrint('Error sending feedback: $e');
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text('Error: $e. Please check your connection.', style: TextStyle(fontFamily: 'Open Sans')),
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
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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



  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Sign Out',
            style: TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Are you sure you want to sign out?',
            style: TextStyle(fontFamily: 'Open Sans'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey, fontFamily: 'Open Sans', fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                navigator.pop();
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                  (route) => false,
                );
              },
              child: const Text(
                'Sign Out',
                style: TextStyle(color: Color(0xFFFF5B24), fontFamily: 'Open Sans', fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDrawerNavItem({
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF2EE) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFFFF5B24) : const Color(0xFF606060),
              size: 22,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'Open Sans',
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                  color: isSelected ? const Color(0xFFFF5B24) : const Color(0xFF222222),
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
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
        userInitials: _userInitials,
        userPictureUrl: _userPictureUrl,
        onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
        onAccountTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (sheetContext) {
              return AccountBottomSheet(
                userName: _userName,
                userEmail: _userEmail,
                userPictureUrl: _userPictureUrl,
                onSettingsTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  ).then((_) async {
                    await _loadSavedTime();
                    if (!_floatsEnabled && _selectedIndex == 1) {
                      setState(() => _selectedIndex = 0);
                      _pageController.animateToPage(
                        0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  });
                },
              );
            },
          );
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
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFFFF8A65), Color(0xFFFF5B24)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: _userPictureUrl != null && _userPictureUrl!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(26),
                                child: Image.network(
                                  _userPictureUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Center(
                                    child: Text(
                                      _userInitials,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'Open Sans',
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  _userInitials,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Open Sans',
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _userName,
                              style: const TextStyle(
                                fontFamily: 'Open Sans',
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF222222),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _userEmail,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Open Sans',
                                fontSize: 12,
                                color: Color(0xFF606060),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFEEEEEE), height: 1),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildDrawerNavItem(
                    icon: Icons.article_outlined,
                    title: 'Daily Report',
                    isSelected: _selectedIndex == 0,
                    onTap: () {
                      _scaffoldKey.currentState?.closeDrawer();
                      _onTabTapped(0);
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildDrawerNavItem(
                    icon: Icons.layers_outlined,
                    title: 'Floats',
                    isSelected: _selectedIndex == 1,
                    onTap: () {
                      _scaffoldKey.currentState?.closeDrawer();
                      _onTabTapped(1);
                    },
                    trailing: _floatsEnabled
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5B24).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '8 active',
                              style: TextStyle(
                                fontFamily: 'Open Sans',
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFFF5B24),
                              ),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Disabled',
                              style: TextStyle(
                                fontFamily: 'Open Sans',
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  _buildDrawerNavItem(
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    isSelected: false,
                    onTap: () {
                      _scaffoldKey.currentState?.closeDrawer();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      ).then((_) async {
                        await _loadSavedTime();
                        if (!_floatsEnabled && _selectedIndex == 1) {
                          setState(() => _selectedIndex = 0);
                          _pageController.animateToPage(
                            0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildDrawerNavItem(
                    icon: Icons.feedback_outlined,
                    title: 'Send Feedback',
                    isSelected: false,
                    onTap: () {
                      _scaffoldKey.currentState?.closeDrawer();
                       _showFeedbackBottomSheet();
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildDrawerNavItem(
                    icon: Icons.help_outline_rounded,
                    title: 'Help & FAQ',
                    isSelected: false,
                    onTap: () {
                      _scaffoldKey.currentState?.closeDrawer();
                      _showHelpDialog();
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            const Divider(color: Color(0xFFEEEEEE), height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: _confirmLogout,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: const [
                          Icon(
                            Icons.logout_rounded,
                            color: Color(0xFFEA4335),
                            size: 20,
                          ),
                          SizedBox(width: 12),
                           Text(
                             'Sign Out',
                             style: TextStyle(
                               fontFamily: 'Open Sans',
                               fontSize: 15,
                               fontWeight: FontWeight.w500,
                               color: Color(0xFFEA4335),
                             ),
                           ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        fontFamily: 'Open Sans',
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                ],
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
