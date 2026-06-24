import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'auth_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 350),
              pageBuilder: (context, animation, _) => const AuthScreen(),
              transitionsBuilder: (context, animation, _, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Text(
          'Briefly',
          style: TextStyle(
            fontFamily: 'Arya',
            fontSize: 56,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFF5B24),
          ),
        ),
      ),
    );
  }
}
