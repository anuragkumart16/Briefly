import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'auth_screen.dart';
import 'config.dart';
import 'services/fcm_service.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final TextEditingController _feedbackController = TextEditingController();
  bool _isSubmitting = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmitAndDelete() async {
    final feedback = _feedbackController.text.trim();
    if (feedback.isEmpty) {
      setState(() {
        _errorMessage = 'Please provide your feedback before deleting your account.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
    });

    final navigator = Navigator.of(context);
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';
    final email = prefs.getString('user_email') ?? '';

    try {
      // 1. Submit feedback
      final feedbackResponse = await http.post(
        Uri.parse('${AppConfig.backendUrl}/api/v1/feedback'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId.isNotEmpty ? userId : null,
          'email': email.isNotEmpty ? email : null,
          'text': 'Account Deletion Feedback: $feedback',
        }),
      );

      if (feedbackResponse.statusCode != 201 && feedbackResponse.statusCode != 200) {
        throw Exception('Failed to save feedback.');
      }

      // 1.5 Unregister FCM Device
      if (userId.isNotEmpty) {
        try {
          await FcmService.unregisterDevice(userId);
        } catch (e) {
          debugPrint('Failed to unregister FCM device: $e');
        }
      }

      // 2. Delete user account from backend database
      if (userId.isNotEmpty) {
        final deleteResponse = await http.delete(
          Uri.parse('${AppConfig.backendUrl}/api/v1/users/$userId'),
        );
        if (deleteResponse.statusCode != 200) {
          throw Exception('Failed to delete account from server.');
        }
      }

      // 3. Clear session & Sign Out
      await prefs.clear();
      try {
        final googleSignIn = GoogleSignIn();
        await googleSignIn.signOut();
        await googleSignIn.disconnect();
      } catch (e) {
        debugPrint('Error signing out of Google: $e');
      }

      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('Error during account deletion process: $e');
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'An error occurred: $e. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Delete Account',
          style: TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'We are sad to see you go',
                style: TextStyle(
                  fontFamily: 'Open Sans',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Please share why you are deleting your account. Your feedback is required to complete the deletion process and helps us improve Briefly.',
                style: TextStyle(
                  fontFamily: 'Open Sans',
                  fontSize: 14,
                  color: Color(0xFF666666),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _feedbackController,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: 'What can we do better?',
                  hintStyle: const TextStyle(color: Color(0xFF999999)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFFF5B24), width: 1.5),
                  ),
                ),
                style: const TextStyle(fontFamily: 'Open Sans'),
                onChanged: (_) {
                  if (_errorMessage.isNotEmpty) {
                    setState(() => _errorMessage = '');
                  }
                },
              ),
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red, fontSize: 13, fontFamily: 'Open Sans'),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmitAndDelete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA4335), // Red Accent
                    disabledBackgroundColor: Colors.red.shade200,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Submit & Delete Account',
                          style: TextStyle(
                            fontFamily: 'Open Sans',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel & Keep Account',
                    style: TextStyle(
                      fontFamily: 'Open Sans',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF666666),
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
