import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main_shell.dart';

/// Entry point kept for backward compatibility (auth_screen navigates here).
/// Immediately delegates to MainShell which owns the full tab structure.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    return const MainShell();
  }
}

/// Pure body widget for the Report tab — no Scaffold, no AppBar, no BottomNav.
class HomeBody extends StatelessWidget {
  const HomeBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Your daily reports will appear here.',
        style: TextStyle(
          fontFamily: 'Open Sans',
          fontSize: 16,
          color: Color(0xFF606060),
        ),
      ),
    );
  }
}
