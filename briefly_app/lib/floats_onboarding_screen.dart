import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FloatsOnboardingScreen extends StatefulWidget {
  const FloatsOnboardingScreen({super.key});

  @override
  State<FloatsOnboardingScreen> createState() => _FloatsOnboardingScreenState();
}

class _FloatsOnboardingScreenState extends State<FloatsOnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  // Frequency options
  final List<String> _frequencies = [
    'Every Hour',
    'Every Two Hours',
    'Every Four Hours',
    'Every Six Hours',
    'Once a Day',
  ];
  String _selectedFrequency = 'Every Two Hours';

  final List<_FloatsPageData> _pages = const [
    _FloatsPageData(
      description: 'Ever happened that you learned a wisdom but forgot when it needed the most?',
      icon: Icons.lightbulb_outline_rounded,
    ),
    _FloatsPageData(
      description: 'Floats are those wisdom pieces which will be delivered to you every nth hour',
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
    await prefs.setString('floats_frequency', _selectedFrequency);
    if (!mounted) return;
    Navigator.of(context).pop(); // Returns to MainShell which switches to Floats tab
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
                        const SizedBox(height: 40),

                        // Icon illustration
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0EB),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            page.icon,
                            size: 48,
                            color: const Color(0xFFFF5B24),
                          ),
                        ),

                        // Frequency picker (last page only)
                        if (page.showFrequencyPicker) ...[
                          const SizedBox(height: 36),
                          _buildFrequencyPicker(),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom bar
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFF7F55),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!isFirst)
                    _NavButton(label: 'Previous', onPressed: _prevPage, isPrevious: true)
                  else
                    const SizedBox(width: 120),
                  _NavButton(
                    label: isLast ? 'Get Started' : 'Next',
                    onPressed: _nextPage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequencyPicker() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How frequently would you like to be reminded?',
            style: TextStyle(
              fontFamily: 'Open Sans',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF222222),
            ),
          ),
          const SizedBox(height: 16),
          ..._frequencies.map((freq) => _FrequencyOption(
                label: freq,
                isSelected: _selectedFrequency == freq,
                onTap: () => setState(() => _selectedFrequency = freq),
              )),
        ],
      ),
    );
  }
}

class _FrequencyOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FrequencyOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF5B24) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF5B24) : const Color(0xFFEEEEEE),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Open Sans',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF444444),
          ),
        ),
      ),
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

  const _NavButton({
    required this.label,
    required this.onPressed,
    this.isPrevious = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPrevious) ...[
            const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Open Sans',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          if (!isPrevious) ...[
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
          ],
        ],
      ),
    );
  }
}
