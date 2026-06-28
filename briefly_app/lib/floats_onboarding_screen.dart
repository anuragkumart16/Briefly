import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/background_scheduler.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class FloatsOnboardingScreen extends StatefulWidget {
  const FloatsOnboardingScreen({super.key});

  @override
  State<FloatsOnboardingScreen> createState() => _FloatsOnboardingScreenState();
}

class _FloatsOnboardingScreenState extends State<FloatsOnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  int _selectedHours = 2;

  final List<_FloatsPageData> _pages = const [
    _FloatsPageData(
      description:
          'Ever happened that you learned a wisdom but forgot when it needed the most?',
      icon: Icons.lightbulb_outline_rounded,
    ),
    _FloatsPageData(
      description:
          'Floats are those wisdom pieces which will be delivered to you every nth hour',
      icon: Icons.notifications_none_rounded,
    ),
    _FloatsPageData(
      description: 'It would keep you reminded so that you don\'t forget.',
      icon: Icons.access_time_rounded,
    ),
    _FloatsPageData(
      description: 'Set how often you\'d like to receive your Floats.',
      icon: Icons.tune_rounded,
      showFrequencyPicker: true,
    ),
  ];

  void _skip() => _goToFloats();

  void _goToFloats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('floats_onboarding_done', true);
    await prefs.setInt('floats_frequency_hours', _selectedHours);
    final userId = prefs.getString('user_id') ?? '';
    if (userId.isNotEmpty) {
      try {
        await http.put(
          Uri.parse('${AppConfig.backendUrl}/api/v1/users/$userId/settings'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'floatsFrequencyHours': _selectedHours}),
        );
      } catch (e) {
        debugPrint('Failed to sync onboarding floats frequency to backend: $e');
      }
    }
    final floatsEnabled = prefs.getBool('floats_enabled') ?? true;
    await BackgroundScheduler.scheduleFloats(_selectedHours, floatsEnabled);
    if (!mounted) return;
    Navigator.of(
      context,
    ).pop(); // Returns to MainShell which switches to Floats tab
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _goToFloats();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _controller.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isFirst = _currentPage == 0;
    final bool isLast = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 12, right: 20),
                child: isFirst
                    ? const SizedBox(height: 40)
                    : TextButton(
                        onPressed: _skip,
                        child: const Text(
                          'Skip >',
                          style: TextStyle(
                            fontFamily: 'Open Sans',
                            fontSize: 16,
                            color: Color(0xFFFF5B24),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Title
                        const Text(
                          'Floats',
                          style: TextStyle(
                            fontFamily: 'Arya',
                            fontSize: 56,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF5B24),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Description
                        Text(
                          page.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Open Sans',
                            fontSize: 17,
                            color: Color(0xFF606060),
                            height: 1.5,
                          ),
                        ),

                        // Frequency display (last page only)
                        if (page.showFrequencyPicker) ...[
                          const SizedBox(height: 36),
                          GestureDetector(
                            onTap: _showFrequencySheet,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 18,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7F7F7),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Every $_selectedHours ${_selectedHours == 1 ? 'Hour' : 'Hours'}',
                                    style: const TextStyle(
                                      fontFamily: 'Open Sans',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF222222),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.expand_more_rounded,
                                    color: Color(0xFFFF5B24),
                                    size: 24,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!isFirst)
                    _NavButton(
                      label: 'Previous',
                      onPressed: _prevPage,
                      isPrevious: true,
                    )
                  else
                    const SizedBox(width: 120),
                  _NavButton(
                    label: isLast ? 'Get Started' : 'Next',
                    onPressed: _nextPage,
                    isPrimary: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFrequencySheet() {
    int tempHours = _selectedHours;
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
                  // Handle
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

                  // Wheel row: "Every [wheel] Hours"
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

                  // Continue button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => _selectedHours = tempHours);
                        Navigator.pop(ctx);
                        _goToFloats();
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
}

class _FloatsPageData {
  final String description;
  final IconData icon;
  final bool showFrequencyPicker;

  const _FloatsPageData({
    required this.description,
    required this.icon,
    this.showFrequencyPicker = false,
  });
}

class _NavButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isPrevious;
  final bool isPrimary;

  const _NavButton({
    required this.label,
    required this.onPressed,
    this.isPrevious = false,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      // Solid orange pill for Next / Get Started
      return ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF5B24),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Open Sans',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
              size: 16,
            ),
          ],
        ),
      );
    }

    // Ghost style for Previous
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFFFF5B24),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFFFF5B24),
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Open Sans',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFFFF5B24),
            ),
          ),
        ],
      ),
    );
  }
}
