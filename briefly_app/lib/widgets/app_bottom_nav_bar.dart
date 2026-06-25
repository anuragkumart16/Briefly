import 'package:flutter/material.dart';

class AppBottomNavBar extends StatelessWidget {
  /// 0 = Report, 1 = Floats, 2 = Settings
  final int selectedIndex;
  final ValueChanged<int> onTabTapped;

  const AppBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTabTapped,
  });

  static const activeColor = Color(0xFFCC3D00);
  static const inactiveColor = Color(0xFFFFB39A);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(0, Icons.article_outlined, 'Report'),
            _navItem(1, Icons.layers_outlined, 'Floats'),
            _navItem(2, Icons.settings_outlined, 'Settings'),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final bool isSelected = selectedIndex == index;
    final color = isSelected ? activeColor : inactiveColor;
    return GestureDetector(
      onTap: () => onTabTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Open Sans',
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
