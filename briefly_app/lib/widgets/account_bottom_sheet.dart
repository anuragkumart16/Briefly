import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth_screen.dart';

class AccountBottomSheet extends StatelessWidget {
  final String userName;
  final String userEmail;
  final VoidCallback onSettingsTap;

  const AccountBottomSheet({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.onSettingsTap,
  });

  String get _initials {
    if (userName.isEmpty) return 'A';
    return userName[0].toUpperCase();
  }

  Future<void> _handleSignOut(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clear session
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
          // Drag handle
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
          const SizedBox(height: 24),
          
          // Identity Summary Header
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF8A65), Color(0xFFFF5B24)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF5B24).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
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
                      userName,
                      style: const TextStyle(
                        fontFamily: 'Open Sans',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF222222),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userEmail,
                      style: const TextStyle(
                        fontFamily: 'Open Sans',
                        fontSize: 13,
                        color: Color(0xFF777777),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Actions List
          _buildActionItem(
            context: context,
            icon: Icons.settings_outlined,
            title: 'Account Settings',
            onTap: () {
              Navigator.of(context).pop();
              onSettingsTap();
            },
          ),

          const Divider(height: 24, thickness: 1, color: Color(0xFFF2F2F2)),
          _buildActionItem(
            context: context,
            icon: Icons.logout_rounded,
            title: 'Sign Out',
            iconColor: const Color(0xFFEA4335),
            textColor: const Color(0xFFEA4335),
            onTap: () {
              _showSignOutConfirmation(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color iconColor = const Color(0xFFFF5B24),
    Color textColor = const Color(0xFF222222),
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Open Sans',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Open Sans',
                        fontSize: 11,
                        color: Color(0xFF888888),
                      ),
                    ),
                  ]
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFCCCCCC), size: 20),
          ],
        ),
      ),
    );
  }

  void _showSignOutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Sign Out',
            style: TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Are you sure you want to sign out of Briefly?',
            style: TextStyle(fontFamily: 'Open Sans'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey, fontFamily: 'Open Sans'),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Dismiss dialog
                Navigator.of(context).pop(); // Dismiss bottom sheet
                _handleSignOut(context); // Run signout
              },
              child: const Text(
                'Sign Out',
                style: TextStyle(color: Color(0xFFEA4335), fontWeight: FontWeight.bold, fontFamily: 'Open Sans'),
              ),
            ),
          ],
        );
      },
    );
  }
}
