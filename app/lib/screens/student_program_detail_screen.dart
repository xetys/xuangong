import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/program.dart';
import '../models/user.dart';
import '../models/session.dart';
import '../services/session_service.dart';

class StudentProgramDetailScreen extends StatefulWidget {
  final Program program;
  final User student;

  const StudentProgramDetailScreen({
    super.key,
    required this.program,
    required this.student,
  });

  @override
  State<StudentProgramDetailScreen> createState() => _StudentProgramDetailScreenState();
}

class _StudentProgramDetailScreenState extends State<StudentProgramDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SessionService _sessionService = SessionService();

  List<SessionWithLogs> _sessions = [];
  bool _isLoadingSessions = false;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    // Only Sessions and Submissions tabs (no Overview)
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadSessions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index == 0) { // Sessions tab
      _loadSessions();
    }
  }

  Future<void> _loadSessions() async {
    if (_isLoadingSessions) return;

    setState(() => _isLoadingSessions = true);

    try {
      final sessions = await _sessionService.listSessions(
        programId: widget.program.id,
        limit: 100,
      );
      setState(() {
        _sessions = sessions;
        _isLoadingSessions = false;
      });
    } catch (e) {
      setState(() => _isLoadingSessions = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load sessions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const burgundy = Color(0xFF9B1C1C);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(widget.program.name),
        backgroundColor: burgundy,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
          tabs: const [
            Tab(text: 'Sessions'),
            Tab(text: 'Submissions'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSessionsTab(burgundy),
          _buildSubmissionsTab(),
        ],
      ),
    );
  }

  Widget _buildSessionsTab(Color burgundy) {
    return RefreshIndicator(
      onRefresh: _loadSessions,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student info banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: burgundy.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.person, color: burgundy, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.student.fullName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: burgundy,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Viewing student\'s practice sessions',
                          style: TextStyle(
                            color: burgundy.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Practice History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            // Calendar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16.0),
              child: TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                calendarStyle: CalendarStyle(
                  markerDecoration: BoxDecoration(
                    color: burgundy,
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: burgundy,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: burgundy.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
                eventLoader: (day) {
                  return _sessions.where((session) {
                    if (session.session.completedAt == null) return false;
                    return isSameDay(session.session.completedAt, day);
                  }).toList();
                },
              ),
            ),
            const SizedBox(height: 24),
            // Session list
            if (_isLoadingSessions)
              const Center(child: CircularProgressIndicator())
            else if (_sessions.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'No practice sessions yet',
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All Sessions (${_sessions.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _sessions.length,
                    itemBuilder: (context, index) {
                      final session = _sessions[index];
                      return _buildSessionCard(session, burgundy);
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(SessionWithLogs session, Color burgundy) {
    final dateStr = session.session.completedAt != null
        ? DateFormat('MMM d, y').format(session.session.completedAt!)
        : 'In progress';
    final timeStr = session.session.completedAt != null
        ? DateFormat('h:mm a').format(session.session.completedAt!)
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                session.session.completedAt != null ? Icons.check_circle : Icons.schedule,
                color: session.session.completedAt != null ? Colors.green : burgundy,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dateStr,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (timeStr.isNotEmpty)
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),
          if (session.session.totalDurationSeconds != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 16,
                  color: burgundy.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 4),
                Text(
                  '${(session.session.totalDurationSeconds! / 60).round()} minutes',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (session.session.completionRate != null) ...[
                  const SizedBox(width: 16),
                  Icon(
                    Icons.trending_up,
                    size: 16,
                    color: burgundy.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${session.session.completionRate!.toStringAsFixed(0)}% completed',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubmissionsTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'Video submissions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming soon',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
