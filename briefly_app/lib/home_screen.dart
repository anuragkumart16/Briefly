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
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
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

  @override
  void initState() {
    super.initState();
    _loadInitialReportState();
  }

  bool _isSameLocalDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _loadInitialReportState() async {
    final loadedCachedReport = await _loadCachedReport();
    final prefs = await SharedPreferences.getInstance();
    final shouldAutoFetch =
        prefs.getBool('open_report_from_notification') ?? false;

    if (shouldAutoFetch) {
      await prefs.remove('open_report_from_notification');
      if (!loadedCachedReport && mounted) {
        await _fetchDailyReport();
      }
    }
  }

  Future<bool> _loadCachedReport() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedReport = prefs.getString('cached_report');
    final cachedReportDate = prefs.getString('cached_report_date');

    if (cachedReport == null || cachedReportDate == null) return false;

    final parsedDate = DateTime.tryParse(cachedReportDate);
    if (parsedDate == null || !_isSameLocalDay(parsedDate, DateTime.now())) {
      return false;
    }

    try {
      final data = jsonDecode(cachedReport);
      if (data is Map<String, dynamic> && mounted) {
        setState(() => _reportData = data);
        return true;
      }
    } catch (_) {}
    return false;
  }

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
          _errorMessage =
              'User session not found. Please log out and sign in again.';
          _isLoading = false;
        });
        return;
      }

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      final timeMin = todayStart.toUtc().toIso8601String();
      final timeMax = todayEnd.toUtc().toIso8601String();

      final url = Uri.parse(
        '${AppConfig.backendUrl}/api/v1/users/$userId/report',
      ).replace(queryParameters: {'timeMin': timeMin, 'timeMax': timeMax});

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
          _errorMessage =
              'Server returned an error status: ${response.statusCode}';
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
      // Try a non-browser app first (opens Gmail if installed), fall back to Chrome Custom Tab
      bool launched = false;
      try {
        launched = await launchUrl(
          uri,
          mode: LaunchMode.externalNonBrowserApplication,
        );
      } catch (_) {}
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening link: $e'),
            backgroundColor: const Color(0xFFFF5B24),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  // ── Section header — matches app's bold label style ──────────────────────
  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFF5B24), size: 17),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Open Sans',
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF222222),
            ),
          ),
        ],
      ),
    );
  }

  // ── Email card ────────────────────────────────────────────────────────────
  Widget _buildEmailCard(Map<String, dynamic> email) {
    final from = email['from'] ?? 'Unknown Sender';
    final subject = email['subject'] ?? 'No Subject';
    final summary = email['summary'] ?? '';
    final link = email['link'];
    final isHighPriority = email['priority'] == 'high';

    final displayName =
        RegExp(r'^(.+?)\s*<').firstMatch(from)?.group(1)?.trim() ?? from;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: () => _openEmailLink(link),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sender avatar
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Color(0xFFFF5B24),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  fontFamily: 'Open Sans',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Open Sans',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF222222),
                          ),
                        ),
                      ),
                      if (isHighPriority) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFFF5B24,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Action needed',
                            style: TextStyle(
                              fontFamily: 'Open Sans',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFF5B24),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.open_in_new_rounded,
                        size: 13,
                        color: Color(0xFFBBBBBB),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Open Sans',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF444444),
                    ),
                  ),
                  if (summary.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      summary,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Open Sans',
                        fontSize: 12,
                        color: Color(0xFF606060),
                        height: 1.45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Calendar event card ───────────────────────────────────────────────────
  Widget _buildEventCard(Map<String, dynamic> event) {
    final title = event['title'] ?? 'No Title';
    final timeStr = event['time'] ?? 'All Day';
    final summary = event['summary'] ?? '';
    final location = event['location'] as String? ?? '';
    final attendees = event['attendees'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: Text(
                  timeStr,
                  style: const TextStyle(
                    fontFamily: 'Open Sans',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF444444),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Open Sans',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF222222),
                  ),
                ),
              ),
            ],
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              summary,
              style: const TextStyle(
                fontFamily: 'Open Sans',
                fontSize: 12,
                color: Color(0xFF606060),
                height: 1.45,
              ),
            ),
          ],
          if (location.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 13,
                  color: Color(0xFF888888),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Open Sans',
                      fontSize: 12,
                      color: Color(0xFF888888),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (attendees.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.people_outline_rounded,
                  size: 13,
                  color: Color(0xFF888888),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    attendees,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Open Sans',
                      fontSize: 12,
                      color: Color(0xFF888888),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Task tile ─────────────────────────────────────────────────────────────
  Widget _buildTaskTile(Map<String, dynamic> task) {
    final title = task['title'] ?? 'Untitled Task';
    final summary = task['summary'] ?? '';
    final deadline = task['deadline'] as String? ?? '';
    final isCompleted = task['status'] == 'completed';
    final isOverdue = deadline.toLowerCase().contains('overdue');
    final isDueToday = deadline.toLowerCase().contains('due today');

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isCompleted
                      ? const Color(0xFF888888)
                      : const Color(0xFFFF5B24),
                  size: 19,
                ),
              ),
              const SizedBox(width: 11),
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
                        color: isCompleted
                            ? const Color(0xFFAAAAAA)
                            : const Color(0xFF222222),
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (summary.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        summary,
                        style: const TextStyle(
                          fontFamily: 'Open Sans',
                          fontSize: 12,
                          color: Color(0xFF606060),
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (deadline.isNotEmpty && !isCompleted) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isOverdue
                              ? const Color(0xFFFFEEEE)
                              : isDueToday
                              ? const Color(0xFFFFF3E0)
                              : const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          deadline,
                          style: TextStyle(
                            fontFamily: 'Open Sans',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isOverdue
                                ? const Color(0xFFCC0000)
                                : isDueToday
                                ? const Color(0xFFE65100)
                                : const Color(0xFF3949AB),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // ── Empty state per section ───────────────────────────────────────────────
  Widget _buildEmptyState(String message, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFFCCCCCC)),
          const SizedBox(width: 8),
          Text(
            message,
            style: const TextStyle(
              fontFamily: 'Open Sans',
              fontSize: 13,
              color: Color(0xFFAAAAAA),
            ),
          ),
        ],
      ),
    );
  }

  // ── Main report content ───────────────────────────────────────────────────
  Widget _buildReportContent() {
    final data = _reportData!;
    final summary = data['summary'] as String? ?? '';
    final wisdom = data['wisdom'] as String? ?? '';
    final List<dynamic> calendar = data['calendar'] ?? [];
    final List<dynamic> tasks = data['tasks'] ?? [];
    final List<dynamic> emails = data['emails'] ?? [];

    final hasCalendar = data.containsKey('calendar');
    final hasTasks = data.containsKey('tasks');
    final hasEmails = data.containsKey('emails');
    final hasWisdom = data.containsKey('wisdom');

    return RefreshIndicator(
      onRefresh: _fetchDailyReport,
      color: const Color(0xFFFF5B24),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // ── Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  Text(
                    _formattedDate(),
                    style: const TextStyle(
                      fontFamily: 'Open Sans',
                      fontSize: 13,
                      color: Color(0xFF888888),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: Color(0xFFFF5B24),
                ),
                onPressed: _fetchDailyReport,
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── AI summary card (dark, branded)
          if (summary.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1C1C2E), Color(0xFF2D1B4E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFFFF5B24),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'AI SUMMARY',
                        style: TextStyle(
                          fontFamily: 'Open Sans',
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFF5B24),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    summary,
                    style: const TextStyle(
                      fontFamily: 'Open Sans',
                      fontSize: 14,
                      color: Color(0xFFDDDDDD),
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),

          // ── Wisdom card — matches app's F5F7FA card style
          if (hasWisdom && wisdom.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Wisdom',
                          style: TextStyle(
                            fontFamily: 'Open Sans',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF888888),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          wisdom,
                          style: const TextStyle(
                            fontFamily: 'Open Sans',
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF444444),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Calendar section
          if (hasCalendar) ...[
            _buildSectionHeader('Schedule', Icons.calendar_today_rounded),
            if (calendar.isEmpty)
              _buildEmptyState(
                'No events scheduled for today',
                Icons.event_busy_rounded,
              )
            else
              ...calendar.map(
                (e) => _buildEventCard(e as Map<String, dynamic>),
              ),
          ],

          // ── Tasks section
          if (hasTasks) ...[
            _buildSectionHeader('Tasks', Icons.task_alt_rounded),
            if (tasks.isEmpty)
              _buildEmptyState(
                'No tasks pending',
                Icons.check_circle_outline_rounded,
              )
            else
              Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: tasks
                      .map((t) => _buildTaskTile(t as Map<String, dynamic>))
                      .toList(),
                ),
              ),
          ],

          // ── Emails section
          if (hasEmails) ...[
            _buildSectionHeader('Unread Emails', Icons.mail_outline_rounded),
            if (emails.isEmpty)
              _buildEmptyState(
                'No important emails today',
                Icons.drafts_rounded,
              )
            else
              ...emails.map((e) => _buildEmailCard(e as Map<String, dynamic>)),
          ],

          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => setState(() => _reportData = null),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFDDDDDD)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              'Go Back',
              style: TextStyle(
                fontFamily: 'Open Sans',
                color: Color(0xFF888888),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formattedDate() {
    final now = DateTime.now();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
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
              const Icon(
                Icons.error_outline_rounded,
                size: 52,
                color: Colors.redAccent,
              ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
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

    if (_reportData != null) {
      return _buildReportContent();
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.article_outlined,
              size: 76,
              color: Color(0xFFFFB39A),
            ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 16,
                ),
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
                    body:
                        'This is an instant test notification verifying that Briefly Alerts are working correctly!',
                  );
                } catch (e) {
                  debugPrint('Failed to send instant notification: $e');
                }
              },
              icon: const Icon(
                Icons.notifications_active_rounded,
                color: Color(0xFFFF5B24),
              ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
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
