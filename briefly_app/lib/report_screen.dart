import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'config.dart';

class SkeletonWidget extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonWidget({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<SkeletonWidget> createState() => _SkeletonWidgetState();
}

class _SkeletonWidgetState extends State<SkeletonWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.45, end: 0.8).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
          ),
        );
      },
    );
  }
}

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _reportData;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  bool _isSameLocalDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _loadReport() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedReport = prefs.getString('cached_report');
    final cachedReportDate = prefs.getString('cached_report_date');

    if (cachedReport != null && cachedReportDate != null) {
      final parsedDate = DateTime.tryParse(cachedReportDate);
      if (parsedDate != null && _isSameLocalDay(parsedDate, DateTime.now())) {
        try {
          final data = jsonDecode(cachedReport);
          if (data is Map<String, dynamic>) {
            setState(() {
              _reportData = data;
              _isLoading = false;
            });
            return;
          }
        } catch (_) {}
      }
    }

    // Cache missing or outdated, fetch fresh
    await _fetchReport();
  }

  Future<void> _fetchReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';
      if (userId.isEmpty) {
        setState(() {
          _errorMessage = 'Session expired. Please sign in again.';
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

      final response = await http.get(url).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          final data = body['data'] as Map<String, dynamic>;

          // Cache locally
          await prefs.setString('cached_report', jsonEncode(data));
          await prefs.setString('cached_report_date', now.toIso8601String());

          setState(() {
            _reportData = data;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = body['message'] ?? 'Failed to compile briefing report.';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'API server error (${response.statusCode}). Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network connection failed. Check your internet connectivity.';
        _isLoading = false;
      });
    }
  }

  Future<void> _launchLink(String? urlString) async {
    if (urlString == null || urlString.isEmpty) return;
    try {
      final uri = Uri.parse(urlString);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open link: $e'),
            backgroundColor: const Color(0xFFFF5B24),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formattedDate() {
    final now = DateTime.now();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFF5B24), size: 22),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Open Sans',
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Color(0xFF222222),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonWidget(width: 140, height: 24, borderRadius: 6),
          const SizedBox(height: 8),
          const SkeletonWidget(width: 200, height: 16, borderRadius: 4),
          const SizedBox(height: 24),
          const SkeletonWidget(width: double.infinity, height: 140, borderRadius: 16),
          const SizedBox(height: 28),
          const SkeletonWidget(width: 100, height: 20, borderRadius: 4),
          const SizedBox(height: 12),
          const SkeletonWidget(width: double.infinity, height: 80, borderRadius: 12),
          const SizedBox(height: 12),
          const SkeletonWidget(width: double.infinity, height: 80, borderRadius: 12),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFFF5B24)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Daily Briefing',
          style: TextStyle(
            fontFamily: 'Open Sans',
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFFFF5B24)),
            onPressed: _fetchReport,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildSkeletonLoader()
            : _errorMessage != null
                ? _buildErrorView()
                : _reportData != null
                    ? _buildReportContent()
                    : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Open Sans',
                fontSize: 14,
                color: Color(0xFF475569),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchReport,
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

  Widget _buildReportContent() {
    final summary = _reportData!['summary'] as String? ?? '';
    final wisdom = _reportData!['wisdom'] as String? ?? '';
    final List<dynamic> calendar = _reportData!['calendar'] ?? [];
    final List<dynamic> tasks = _reportData!['tasks'] ?? [];
    final List<dynamic> emails = _reportData!['emails'] ?? [];

    return RefreshIndicator(
      onRefresh: _fetchReport,
      color: const Color(0xFFFF5B24),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // Subheader Date
          Text(
            _formattedDate(),
            style: const TextStyle(
              fontFamily: 'Open Sans',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFFFF5B24),
            ),
          ),
          const SizedBox(height: 14),

          // Branded AI Summary Card
          if (summary.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E1E30), Color(0xFF331D56)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF331D56).withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: Color(0xFFFF5B24), size: 16),
                      SizedBox(width: 6),
                      Text(
                        'AI ANALYSIS & BRIEF',
                        style: TextStyle(
                          fontFamily: 'Open Sans',
                          fontSize: 12,
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
                      color: Color(0xFFE2E8F0),
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),

          // Wisdom Quote Card
          if (wisdom.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DAILY WISDOM',
                          style: TextStyle(
                            fontFamily: 'Open Sans',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF606060),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          wisdom,
                          style: const TextStyle(
                            fontFamily: 'Open Sans',
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF606060),
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

          // Calendar Schedule Section
          if (calendar.isNotEmpty) ...[
            _buildSectionHeader('Schedule', Icons.calendar_today_rounded),
            ...calendar.map((e) => _buildEventCard(e as Map<String, dynamic>)),
          ],

          // Tasks Section
          if (tasks.isNotEmpty) ...[
            _buildSectionHeader('Tasks & Deadlines', Icons.task_alt_rounded),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: Column(
                children: tasks.map((t) => _buildTaskTile(t as Map<String, dynamic>)).toList(),
              ),
            ),
          ],

          // Emails Section
          if (emails.isNotEmpty) ...[
            _buildSectionHeader('Important Emails', Icons.mail_outline_rounded),
            ...emails.map((e) => _buildEmailCard(e as Map<String, dynamic>)),
          ],
        ],
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final title = event['title'] ?? 'No Title';
    final timeStr = event['time'] ?? 'All Day';
    final summary = event['summary'] ?? '';
    final location = event['location'] as String? ?? '';
    final attendees = event['attendees'] as String? ?? '';
    final List<dynamic> docLinks = event['documentLinks'] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFEEEEEE)),
                ),
                child: Text(
                  timeStr,
                  style: const TextStyle(
                    fontFamily: 'Open Sans',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF606060),
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
                    fontWeight: FontWeight.w500,
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
                height: 1.45,
              ),
            ),
          ],
          if (location.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Open Sans', fontSize: 12, color: Color(0xFF606060)),
                  ),
                ),
              ],
            ),
          ],
          if (attendees.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.people_outline_rounded, size: 16, color: Color(0xFF64748B)),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'People: $attendees',
                    style: const TextStyle(
                      fontFamily: 'Open Sans',
                      fontSize: 12,
                      color: Color(0xFF606060),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (docLinks.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 8),
            ...docLinks.map((doc) {
              final docTitle = doc['title'] ?? 'Attached Document';
              final docUrl = doc['link'] as String? ?? '';
              return GestureDetector(
                onTap: () => _launchLink(docUrl),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.insert_drive_file_outlined, size: 16, color: Color(0xFFFF5B24)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          docTitle,
                          style: const TextStyle(
                            fontFamily: 'Open Sans',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFFF5B24),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskTile(Map<String, dynamic> task) {
    final title = task['title'] ?? 'Untitled Task';
    final details = task['details'] ?? '';
    final deadline = task['deadline'] as String? ?? '';
    final isCompleted = task['status'] == 'completed';
    
    final isNoDeadline = deadline.toLowerCase().contains('no deadline');
    final isOverdue = deadline.toLowerCase().contains('overdue');
    final isDueToday = deadline.toLowerCase().contains('due today');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: isCompleted ? const Color(0xFF94A3B8) : const Color(0xFFFF5B24),
                size: 21,
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
                        fontWeight: FontWeight.w500,
                        color: isCompleted ? const Color(0xFF94A3B8) : const Color(0xFF222222),
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        details,
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isOverdue
                              ? const Color(0xFFFEF2F2)
                              : isDueToday
                                  ? const Color(0xFFFFF7ED)
                                  : isNoDeadline
                                      ? const Color(0xFFF1F5F9)
                                      : const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isOverdue
                                ? const Color(0xFFFCA5A5)
                                : isDueToday
                                    ? const Color(0xFFFDBA74)
                                    : isNoDeadline
                                        ? const Color(0xFFCBD5E1)
                                        : const Color(0xFFC7D2FE),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          deadline,
                          style: TextStyle(
                            fontFamily: 'Open Sans',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isOverdue
                                ? const Color(0xFFDC2626)
                                : isDueToday
                                    ? const Color(0xFFEA580C)
                                    : isNoDeadline
                                        ? const Color(0xFF475569)
                                        : const Color(0xFF4F46E5),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
        ],
      ),
    );
  }

  Widget _buildEmailCard(Map<String, dynamic> email) {
    final from = email['from'] ?? 'Unknown Sender';
    final subject = email['subject'] ?? 'No Subject';
    final crux = email['crux'] ?? '';
    final whySent = email['whySent'] ?? '';
    final summary = email['summary'] ?? '';
    final link = email['link'];
    final isHighPriority = email['priority'] == 'high';
    final List<dynamic> attachments = email['attachments'] ?? [];

    final displayName = RegExp(r'^(.+?)\s*<').firstMatch(from)?.group(1)?.trim() ?? from;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: () => _launchLink(link),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFFF8A65), Color(0xFFFF5B24)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
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
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF222222),
                          ),
                        ),
                      ),
                      if (isHighPriority) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEFEC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFFC7BC), width: 0.5),
                          ),
                          child: const Text(
                            'Action Needed',
                            style: TextStyle(
                              fontFamily: 'Open Sans',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF5B24),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 6),
                      const Icon(Icons.open_in_new_rounded, size: 12, color: Color(0xFF94A3B8)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Open Sans',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF606060),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Crux and Why Sent bloc
                  if (crux.isNotEmpty) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Crux: ',
                          style: TextStyle(fontFamily: 'Open Sans', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF606060)),
                        ),
                        Expanded(
                          child: Text(
                            crux,
                            style: const TextStyle(fontFamily: 'Open Sans', fontSize: 12, color: Color(0xFF606060)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (whySent.isNotEmpty) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Context: ',
                          style: TextStyle(fontFamily: 'Open Sans', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF606060)),
                        ),
                        Expanded(
                          child: Text(
                            whySent,
                            style: const TextStyle(fontFamily: 'Open Sans', fontSize: 12, color: Color(0xFF606060)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (summary.isNotEmpty) ...[
                    const Divider(height: 1, color: Color(0xFFEEEEEE)),
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

                  if (attachments.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: attachments.map((att) {
                        final attName = att['name'] ?? 'Attachment';
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFEEEEEE)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.attach_file_rounded, size: 14, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(
                                attName,
                                style: const TextStyle(
                                  fontFamily: 'Open Sans',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF606060),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
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
}
