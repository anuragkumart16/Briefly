import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';
import 'main_shell.dart';
import 'services/notification_helper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

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
class HomeBody extends StatefulWidget {
  const HomeBody({super.key});

  @override
  State<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<HomeBody> {
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _reportData;

  Future<void> _fetchDailyReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _reportData = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';
      if (userId.isEmpty) {
        setState(() {
          _errorMessage = 'User session not found. Please log out and sign in again.';
          _isLoading = false;
        });
        return;
      }

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      final timeMin = todayStart.toUtc().toIso8601String();
      final timeMax = todayEnd.toUtc().toIso8601String();

      final url = Uri.parse('${AppConfig.backendUrl}/api/v1/users/$userId/report')
          .replace(queryParameters: {
            'timeMin': timeMin,
            'timeMax': timeMax,
          });

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          setState(() {
            _reportData = body['data'];
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = body['message'] ?? 'Failed to compile report';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Server returned an error status: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to connect: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _openEmailLink(String? urlString) async {
    if (urlString == null || urlString.isEmpty) return;
    try {
      final uri = Uri.parse(urlString);
      // Try in-app Chrome Custom Tab first (always works for https), then external browser
      final launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening link: $e')),
        );
      }

    }
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFF5B24), size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Open Sans',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF222222),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailCard(Map<String, dynamic> email) {
    final from = email['from'] ?? 'Unknown Sender';
    final subject = email['subject'] ?? 'No Subject';
    final summary = email['summary'] ?? '';
    final link = email['link'];

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFEEEEEE)),
      ),
      child: InkWell(
        onTap: () => _openEmailLink(link),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      from,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Open Sans',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF222222),
                      ),
                    ),
                  ),
                  const Icon(Icons.open_in_new_rounded, size: 16, color: Color(0xFF888888)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                subject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Open Sans',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF444444),
                ),
              ),
              if (summary.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  summary,
                  style: const TextStyle(
                    fontFamily: 'Open Sans',
                    fontSize: 12,
                    color: Color(0xFF606060),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final title = event['title'] ?? 'No Title';
    final timeStr = event['time'] ?? 'All Day';
    final summary = event['summary'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF2EE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  timeStr,
                  style: const TextStyle(
                    fontFamily: 'Open Sans',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF5B24),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Open Sans',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF222222),
                  ),
                ),
              ),
            ],
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              summary,
              style: const TextStyle(
                fontFamily: 'Open Sans',
                fontSize: 12,
                color: Color(0xFF606060),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskTile(Map<String, dynamic> task) {
    final title = task['title'] ?? 'Untitled Task';
    final summary = task['summary'] ?? '';
    final isCompleted = task['status'] == 'completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFBFB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isCompleted ? Colors.green : const Color(0xFFFF5B24),
            size: 20,
          ),
          const SizedBox(width: 12),
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
                    color: const Color(0xFF222222),
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    summary,
                    style: const TextStyle(
                      fontFamily: 'Open Sans',
                      fontSize: 12,
                      color: Color(0xFF606060),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportContent() {
    final data = _reportData!;
    final summary = data['summary'] ?? '';
    final wisdom = data['wisdom'] ?? '';
    final List<dynamic> calendar = data['calendar'] ?? [];
    final List<dynamic> tasks = data['tasks'] ?? [];
    final List<dynamic> emails = data['emails'] ?? [];

    return RefreshIndicator(
      onRefresh: _fetchDailyReport,
      color: const Color(0xFFFF5B24),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Briefing Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Today\'s Briefing',
                style: TextStyle(
                  fontFamily: 'Open Sans',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF222222),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFFFF5B24)),
                onPressed: _fetchDailyReport,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // AI Cohesive Summary Card
          if (summary.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF2EE), Color(0xFFFFFDFD)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFE0D5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFF5B24), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'AI Daily Summary'.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'Open Sans',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF5B24),
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    summary,
                    style: const TextStyle(
                      fontFamily: 'Open Sans',
                      fontSize: 14,
                      color: Color(0xFF333333),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

          // AI Wisdom Card
          if (wisdom.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E8EC)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFF9A825), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Wisdom reminder',
                          style: TextStyle(
                            fontFamily: 'Open Sans',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF707070),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          wisdom,
                          style: const TextStyle(
                            fontFamily: 'Open Sans',
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF444444),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Calendar Events Section
          _buildSectionHeader('Schedule Events', Icons.calendar_today_rounded),
          if (calendar.isEmpty)
            const Text(
              'No events scheduled for today.',
              style: TextStyle(fontFamily: 'Open Sans', fontSize: 13, color: Colors.grey),
            )
          else
            ...calendar.map((e) => _buildEventCard(e as Map<String, dynamic>)),

          // Tasks Section
          _buildSectionHeader('Action Tasks', Icons.task_alt_rounded),
          if (tasks.isEmpty)
            const Text(
              'No tasks pending for today.',
              style: TextStyle(fontFamily: 'Open Sans', fontSize: 13, color: Colors.grey),
            )
          else
            ...tasks.map((t) => _buildTaskTile(t as Map<String, dynamic>)),

          // Emails Section
          _buildSectionHeader('Unread Emails', Icons.mail_outline_rounded),
          if (emails.isEmpty)
            const Text(
              'No unread emails from today.',
              style: TextStyle(fontFamily: 'Open Sans', fontSize: 13, color: Colors.grey),
            )
          else
            ...emails.map((e) => _buildEmailCard(e as Map<String, dynamic>)),
          
          const SizedBox(height: 16),
          // Clear Report Button
          OutlinedButton(
            onPressed: () {
              setState(() {
                _reportData = null;
              });
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFCCCCCC)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              'Go Back',
              style: TextStyle(
                fontFamily: 'Open Sans',
                color: Color(0xFF666666),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF5B24)),
            ),
            const SizedBox(height: 24),
            const Text(
              'Analyzing your day...',
              style: TextStyle(
                fontFamily: 'Open Sans',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF5B24),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Compiling unread emails, calendar events,\ntasks, and wisdom floats...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Open Sans',
                fontSize: 13,
                color: Color(0xFF606060),
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 52, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Open Sans',
                  fontSize: 14,
                  color: Colors.redAccent,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: _fetchDailyReport,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5B24),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_reportData != null) {
      return _buildReportContent();
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.article_outlined, size: 76, color: Color(0xFFFFB39A)),
            const SizedBox(height: 20),
            const Text(
              'Your daily report is ready.',
              style: TextStyle(
                fontFamily: 'Open Sans',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF222222),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Compile today\'s calendar, tasks, unread emails,\nand wisdom floats using AI.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Open Sans',
                fontSize: 14,
                color: Color(0xFF606060),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _fetchDailyReport,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text(
                'Fetch Daily Report',
                style: TextStyle(
                  fontFamily: 'Open Sans',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5B24),
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: const Color(0xFFFF5B24).withValues(alpha: 0.3),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  await NotificationHelper.showNotification(
                    id: 999,
                    title: 'Test Float Notification 🚀',
                    body: 'This is an instant test notification verifying that Briefly Alerts are working correctly!',
                  );
                } catch (e) {
                  debugPrint('Failed to send instant notification: $e');
                }
              },
              icon: const Icon(Icons.notifications_active_rounded, color: Color(0xFFFF5B24)),
              label: const Text(
                'Test Notification',
                style: TextStyle(
                  fontFamily: 'Open Sans',
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF5B24),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFF5B24)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

