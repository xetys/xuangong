import 'package:flutter/material.dart';

// Practice status enum
enum PracticeStatus { completed, partial, skipped }

// Practice day model (used by practice history widget)
class PracticeDay {
  final String dayName;
  final String date;
  final PracticeStatus status;
  final List<String> sessionNames;
  final int durationMinutes;
  final int exercisesCompleted;
  final int totalExercises;

  PracticeDay({
    required this.dayName,
    required this.date,
    required this.status,
    this.sessionNames = const [],
    this.durationMinutes = 0,
    this.exercisesCompleted = 0,
    this.totalExercises = 0,
  });
}

// Mock practice data
final List<PracticeDay> mockPracticeData = [
  PracticeDay(
    dayName: 'Today',
    date: '27',
    status: PracticeStatus.completed,
    sessionNames: ['Morning Qi Gong', 'Tai Chi Form'],
    durationMinutes: 30,
  ),
  PracticeDay(
    dayName: 'Sat',
    date: '26',
    status: PracticeStatus.completed,
    sessionNames: ['Morning Qi Gong', 'Ba Gua Circle Walk', 'Tai Chi Form'],
    durationMinutes: 28,
  ),
  PracticeDay(
    dayName: 'Fri',
    date: '25',
    status: PracticeStatus.partial,
    sessionNames: ['Morning Qi Gong'],
    exercisesCompleted: 3,
    totalExercises: 5,
  ),
  PracticeDay(
    dayName: 'Thu',
    date: '24',
    status: PracticeStatus.completed,
    sessionNames: ['Morning Qi Gong', 'Tai Chi Form', 'Ba Gua Walk', 'Xing Yi Practice'],
    durationMinutes: 32,
  ),
];

// Individual practice session model
class PracticeSession {
  final String id;
  final String dayName;
  final String date;
  final String sessionName;
  final int durationMinutes;
  final DateTime timestamp;

  PracticeSession({
    required this.id,
    required this.dayName,
    required this.date,
    required this.sessionName,
    required this.durationMinutes,
    required this.timestamp,
  });
}

class PracticeCalendarScreen extends StatefulWidget {
  const PracticeCalendarScreen({Key? key}) : super(key: key);

  @override
  State<PracticeCalendarScreen> createState() => _PracticeCalendarScreenState();
}

class _PracticeCalendarScreenState extends State<PracticeCalendarScreen> {
  // Convert PracticeDay data to individual sessions
  List<PracticeSession> _sessions = [];

  @override
  void initState() {
    super.initState();
    _initializeSessions();
  }

  void _initializeSessions() {
    _sessions = [];
    int idCounter = 0;

    for (var practiceDay in mockPracticeData) {
      // Only add sessions if they exist (not skipped days)
      if (practiceDay.sessionNames.isNotEmpty) {
        for (var sessionName in practiceDay.sessionNames) {
          _sessions.add(
            PracticeSession(
              id: 'session_${idCounter++}',
              dayName: practiceDay.dayName,
              date: practiceDay.date,
              sessionName: sessionName,
              durationMinutes: practiceDay.durationMinutes ~/
                  (practiceDay.sessionNames.length),
              timestamp: DateTime.now().subtract(
                Duration(days: mockPracticeData.indexOf(practiceDay)),
              ),
            ),
          );
        }
      }
    }
  }

  // Group sessions by date
  Map<String, List<PracticeSession>> _groupSessionsByDate() {
    final grouped = <String, List<PracticeSession>>{};
    for (var session in _sessions) {
      final dateKey = '${session.dayName}, ${session.date}';
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(session);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    const burgundy = Color(0xFF9B1C1C);
    final groupedSessions = _groupSessionsByDate();
    final dateKeys = groupedSessions.keys.toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: burgundy),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Practice History',
          style: TextStyle(
            color: burgundy,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _sessions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.self_improvement,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No practice sessions yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: dateKeys.length,
              itemBuilder: (context, index) {
                final dateKey = dateKeys[index];
                final sessions = groupedSessions[dateKey]!;
                return _buildDateGroup(dateKey, sessions, burgundy);
              },
            ),
    );
  }

  Widget _buildDateGroup(String dateKey, List<PracticeSession> sessions, Color burgundy) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date header
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              dateKey,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Sessions for this date
          ...sessions.map((session) => _buildSessionCard(session, burgundy)),
        ],
      ),
    );
  }

  Widget _buildSessionCard(PracticeSession session, Color burgundy) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: burgundy.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showSessionDetails(context, session),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: burgundy.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.self_improvement,
                    color: burgundy,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Session info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.sessionName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (session.durationMinutes > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${session.durationMinutes} min',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Checkmark and arrow
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: burgundy,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey.shade400,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSessionDetails(BuildContext context, PracticeSession session) {
    const burgundy = Color(0xFF9B1C1C);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                session.sessionName,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: burgundy,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, color: Colors.grey.shade600),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Date
              Text(
                'Date',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${session.dayName}, ${session.date}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),

              // Duration
              if (session.durationMinutes > 0) ...[
                const SizedBox(height: 24),
                Text(
                  'Duration',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${session.durationMinutes} minutes',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],

              // Status
              const SizedBox(height: 24),
              Text(
                'Status',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: burgundy,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Completed',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmDelete(context, session);
            },
            child: Text(
              'Delete',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(
                color: burgundy,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, PracticeSession session) {
    const burgundy = Color(0xFF9B1C1C);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session?'),
        content: Text(
          'Are you sure you want to delete "${session.sessionName}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _sessions.removeWhere((s) => s.id == session.id);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Session deleted'),
                  backgroundColor: burgundy,
                ),
              );
            },
            child: Text(
              'Delete',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
