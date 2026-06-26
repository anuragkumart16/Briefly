import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'config.dart';
import 'main_shell.dart';
import 'report_screen.dart';

/// Entry point kept for backward compatibility (auth_screen navigates here).
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

class HomeBody extends StatefulWidget {
  const HomeBody({super.key});

  @override
  State<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<HomeBody> {
  bool _isTasksLoading = false;
  bool _isCalendarLoading = false;
  bool _isEmailsLoading = false;

  List<dynamic> _tasks = [];
  List<dynamic> _calendarEvents = [];
  List<dynamic> _emails = [];

  Map<String, dynamic>? _cachedReportData;
  String _userId = '';

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  Future<void> _initializeDashboard() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('user_id') ?? '';
    });
    
    _loadCachedReport();
    if (_userId.isNotEmpty) {
      _fetchAllData();
    }
  }

  bool _isSameLocalDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _loadCachedReport() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedReport = prefs.getString('cached_report');
    final cachedReportDate = prefs.getString('cached_report_date');

    if (cachedReport == null || cachedReportDate == null) {
      setState(() => _cachedReportData = null);
      return;
    }

    final parsedDate = DateTime.tryParse(cachedReportDate);
    if (parsedDate == null || !_isSameLocalDay(parsedDate, DateTime.now())) {
      setState(() => _cachedReportData = null);
      return;
    }

    try {
      final data = jsonDecode(cachedReport);
      if (data is Map<String, dynamic>) {
        setState(() => _cachedReportData = data);
      }
    } catch (_) {}
  }

  Future<void> _fetchAllData() async {
    _loadCachedReport();
    await Future.wait([
      _fetchTasks(),
      _fetchCalendarEvents(),
      _fetchEmails(),
    ]);
  }

  Future<void> _fetchTasks() async {
    if (_userId.isEmpty) return;
    setState(() => _isTasksLoading = true);

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.backendUrl}/api/v1/users/$_userId/tasks'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          setState(() {
            _tasks = body['data'] as List<dynamic>;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching tasks: $e');
    } finally {
      setState(() => _isTasksLoading = false);
    }
  }

  Future<void> _fetchCalendarEvents() async {
    if (_userId.isEmpty) return;
    setState(() => _isCalendarLoading = true);

    try {
      final now = DateTime.now();
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      
      final response = await http.get(
        Uri.parse('${AppConfig.backendUrl}/api/v1/users/$_userId/calendar/today-left').replace(
          queryParameters: {
            'timeMin': now.toUtc().toIso8601String(),
            'timeMax': todayEnd.toUtc().toIso8601String(),
          },
        ),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          setState(() {
            _calendarEvents = body['data'] as List<dynamic>;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching calendar events: $e');
    } finally {
      setState(() => _isCalendarLoading = false);
    }
  }

  Future<void> _fetchEmails() async {
    if (_userId.isEmpty) return;
    setState(() => _isEmailsLoading = true);

    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);

      final response = await http.get(
        Uri.parse('${AppConfig.backendUrl}/api/v1/users/$_userId/emails/today').replace(
          queryParameters: {
            'timeMin': todayStart.toUtc().toIso8601String(),
          },
        ),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          setState(() {
            _emails = body['data'] as List<dynamic>;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching emails: $e');
    } finally {
      setState(() => _isEmailsLoading = false);
    }
  }

  Future<void> _toggleTaskStatus(Map<String, dynamic> task) async {
    final currentStatus = task['status'];
    final newStatus = currentStatus == 'completed' ? 'needsAction' : 'completed';
    
    // Optimistic UI update
    setState(() {
      task['status'] = newStatus;
    });

    try {
      final response = await http.patch(
        Uri.parse('${AppConfig.backendUrl}/api/v1/users/$_userId/tasks/${task['id']}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': newStatus}),
      );

      if (response.statusCode != 200) {
        // Revert on failure
        setState(() {
          task['status'] = currentStatus;
        });
      }
    } catch (_) {
      // Revert on failure
      setState(() {
        task['status'] = currentStatus;
      });
    }
  }

  Future<void> _deleteTask(String taskId) async {
    setState(() {
      _tasks.removeWhere((t) => t['id'] == taskId);
    });

    try {
      await http.delete(
        Uri.parse('${AppConfig.backendUrl}/api/v1/users/$_userId/tasks/$taskId'),
      );
    } catch (_) {}
  }

  void _showAddTaskSheet() {
    final titleController = TextEditingController();
    final notesController = TextEditingController();
    DateTime? selectedDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  'Add Google Task',
                  style: TextStyle(
                    fontFamily: 'Open Sans',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF5B24),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  autofocus: true,
                  style: const TextStyle(fontFamily: 'Open Sans', fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Task Title',
                    filled: true,
                    fillColor: const Color(0xFFF7F7F7),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  style: const TextStyle(fontFamily: 'Open Sans', fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Notes/Details',
                    filled: true,
                    fillColor: const Color(0xFFF7F7F7),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      selectedDate == null
                          ? 'No Deadline'
                          : 'Due: ${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
                      style: TextStyle(
                        fontFamily: 'Open Sans',
                        color: selectedDate == null ? Colors.grey : const Color(0xFFFF5B24),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (picked != null) {
                          setSheetState(() => selectedDate = picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFFFF5B24)),
                      label: const Text('Pick Date', style: TextStyle(color: Color(0xFFFF5B24))),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final title = titleController.text.trim();
                      if (title.isNotEmpty) {
                        Navigator.pop(ctx);
                        setState(() => _isTasksLoading = true);
                        try {
                          final response = await http.post(
                            Uri.parse('${AppConfig.backendUrl}/api/v1/users/$_userId/tasks'),
                            headers: {'Content-Type': 'application/json'},
                            body: jsonEncode({
                              'title': title,
                              'notes': notesController.text.trim(),
                              'due': selectedDate?.toUtc().toIso8601String(),
                            }),
                          );
                          if (response.statusCode == 201) {
                            _fetchTasks();
                          }
                        } catch (_) {}
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5B24),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Add Task', style: TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openEmailLink(String? urlString) async {
    if (urlString == null || urlString.isEmpty) return;
    try {
      final uri = Uri.parse(urlString);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Widget _buildSectionHeader(String title, IconData icon, {VoidCallback? onTrailingTap, IconData? trailingIcon}) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFFF5B24), size: 22),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Open Sans',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          if (onTrailingTap != null && trailingIcon != null)
            IconButton(
              icon: Icon(trailingIcon, color: const Color(0xFFFF5B24), size: 20),
              onPressed: onTrailingTap,
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _fetchAllData,
        color: const Color(0xFFFF5B24),
        child: SafeArea(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              // Header title
              const Text(
                'My Dashboard',
                style: TextStyle(
                  fontFamily: 'Open Sans',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),

              // Today's Report Card
              _buildReportCard(),

              // Tasks Widget
              _buildTasksSection(),

              // Schedule Widget
              _buildScheduleSection(),

              // Emails Widget
              _buildEmailsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard() {
    final hasReport = _cachedReportData != null;
    final snippet = hasReport ? (_cachedReportData!['summary'] as String? ?? '') : '';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ReportScreen()),
        ).then((_) => _loadCachedReport());
      },
      child: Container(
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
              color: const Color(0xFF331D56).withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: Color(0xFFFF5B24), size: 16),
                    SizedBox(width: 6),
                    Text(
                      'DAILY BRIEFING',
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Text(
                        hasReport ? 'View Report' : 'Compile',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 3),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 10),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              hasReport
                  ? (snippet.length > 120 ? '${snippet.substring(0, 120)}...' : snippet)
                  : 'Your Daily Briefing report is ready to be compiled. Tap here to fetch your briefing updates.',
              style: const TextStyle(
                fontFamily: 'Open Sans',
                fontSize: 15.5,
                color: Color(0xFFE2E8F0),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Tasks', Icons.task_alt_rounded, onTrailingTap: _showAddTaskSheet, trailingIcon: Icons.add_circle_outline_rounded),
        if (_isTasksLoading && _tasks.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
        else if (_tasks.isEmpty)
          _buildEmptyCard('No pending Google Tasks today.')
        else
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: _tasks.map((task) {
                final title = task['title'] ?? 'Untitled';
                final notes = task['notes'] ?? '';
                final isCompleted = task['status'] == 'completed';
                String deadline = 'No deadline';
                if (task['due'] != null && task['due'].toString().isNotEmpty) {
                  try {
                    final parsedDue = DateTime.parse(task['due'].toString()).toLocal();
                    deadline = 'Due: ${parsedDue.day}/${parsedDue.month}';
                  } catch (_) {}
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => _toggleTaskStatus(task),
                        child: Icon(
                          isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          color: isCompleted ? Colors.grey : const Color(0xFFFF5B24),
                          size: 22,
                        ),
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
                                fontSize: 15.5,
                                fontWeight: FontWeight.bold,
                                color: isCompleted ? Colors.grey : const Color(0xFF1E293B),
                                decoration: isCompleted ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            if (notes.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                notes,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              deadline,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isCompleted ? Colors.grey : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                        onPressed: () => _deleteTask(task['id']),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildScheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Schedule (Remaining)', Icons.calendar_today_rounded),
        if (_isCalendarLoading && _calendarEvents.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
        else if (_calendarEvents.isEmpty)
          _buildEmptyCard('No calendar events remaining today.')
        else
          ..._calendarEvents.map((event) {
            final title = event['summary'] ?? 'No Title';
            final startStr = event['start'] ?? '';
            final endStr = event['end'] ?? '';
            final location = event['location'] ?? '';
            
            // Format clean time e.g., 10:00 AM
            String timeString = 'All Day';
            if (startStr.isNotEmpty) {
              try {
                final date = DateTime.parse(startStr).toLocal();
                final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
                final period = date.hour >= 12 ? 'PM' : 'AM';
                final min = date.minute.toString().padLeft(2, '0');
                timeString = '$hour:$min $period';
              } catch (_) {}
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFCBD5E1))),
                        child: Text(
                          timeString,
                          style: const TextStyle(fontFamily: 'Open Sans', fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'Open Sans', fontSize: 15.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                      ),
                    ],
                  ),
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'Open Sans', fontSize: 13, color: Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildEmailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Emails Today', Icons.mail_outline_rounded),
        if (_isEmailsLoading && _emails.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
        else if (_emails.isEmpty)
          _buildEmptyCard('No unread emails today.')
        else
          ..._emails.map((email) {
            final from = email['from'] ?? 'Unknown Sender';
            final subject = email['subject'] ?? 'No Subject';
            final snippet = email['snippet'] ?? '';
            final link = email['link'];

            final displayName = RegExp(r'^(.+?)\s*<').firstMatch(from)?.group(1)?.trim() ?? from;
            final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

            return GestureDetector(
              onTap: () => _openEmailLink(link),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(color: Color(0xFFFF5B24), shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Open Sans'),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontFamily: 'Open Sans', fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                ),
                              ),
                              const Icon(Icons.open_in_new_rounded, size: 15, color: Color(0xFF94A3B8)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'Open Sans', fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                          ),
                          if (snippet.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              snippet,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.35),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: 'Open Sans', fontSize: 15, color: Color(0xFF64748B)),
      ),
    );
  }
}
