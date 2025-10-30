import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/session.dart';
import '../models/program.dart';
import '../services/session_service.dart';
import '../services/program_service.dart';
import 'session_edit_screen.dart';

class PracticeCalendarScreen extends StatefulWidget {
  const PracticeCalendarScreen({Key? key}) : super(key: key);

  @override
  State<PracticeCalendarScreen> createState() => _PracticeCalendarScreenState();
}

class _PracticeCalendarScreenState extends State<PracticeCalendarScreen> {
  final SessionService _sessionService = SessionService();
  final ProgramService _programService = ProgramService();

  List<SessionWithLogs> _sessions = [];
  Map<String, Program> _programs = {};
  bool _isLoading = true;
  bool _hasChanges = false; // Track if any sessions were modified

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      setState(() => _isLoading = true);

      // Load sessions from backend
      final sessions = await _sessionService.listSessions(limit: 100);

      // Load programs to get their names
      final programs = await _programService.getMyPrograms();
      final programMap = <String, Program>{};
      for (var program in programs) {
        programMap[program.id] = program;
      }

      setState(() {
        _sessions = sessions;
        _programs = programMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
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

  // Group sessions by date
  Map<String, List<SessionWithLogs>> _groupSessionsByDate() {
    // Sort sessions by date descending first
    final sortedSessions = List<SessionWithLogs>.from(_sessions);
    sortedSessions.sort((a, b) {
      final dateA = a.session.completedAt ?? a.session.startedAt;
      final dateB = b.session.completedAt ?? b.session.startedAt;
      return dateB.compareTo(dateA); // Descending order (newest first)
    });

    // Group by date, maintaining order
    final grouped = <String, List<SessionWithLogs>>{};
    for (var session in sortedSessions) {
      final date = session.session.completedAt ?? session.session.startedAt;
      final dateKey = DateFormat('EEEE, MMM dd').format(date);
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
          onPressed: () => Navigator.pop(context, _hasChanges),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
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

  Widget _buildDateGroup(String dateKey, List<SessionWithLogs> sessions, Color burgundy) {
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

  Widget _buildSessionCard(SessionWithLogs sessionData, Color burgundy) {
    final program = _programs[sessionData.session.programId];
    final programName = program?.name ?? 'Unknown Program';

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
          onTap: () => _showSessionDetails(context, sessionData),
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
                        programName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
                            DateFormat('HH:mm').format(
                              sessionData.session.completedAt ?? sessionData.session.startedAt
                            ),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          if (sessionData.exerciseLogs.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.fitness_center,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${sessionData.exerciseLogs.length} exercises',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
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

  void _showSessionDetails(BuildContext context, SessionWithLogs sessionData) async {
    const burgundy = Color(0xFF9B1C1C);
    final program = _programs[sessionData.session.programId];
    final programName = program?.name ?? 'Unknown Program';
    final date = sessionData.session.completedAt ?? sessionData.session.startedAt;

    final result = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                programName,
                style: const TextStyle(
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
                'DATE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('EEEE, MMMM dd, yyyy - HH:mm').format(date),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),

              // Exercise logs
              if (sessionData.exerciseLogs.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'EXERCISES LOGGED',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${sessionData.exerciseLogs.length} exercises',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],

              // Notes
              if (sessionData.session.notes != null && sessionData.session.notes!.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'NOTES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  sessionData.session.notes!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final deleted = await _deleteSessionWithConfirmation(sessionData.session.id);
              if (deleted) {
                setState(() => _hasChanges = true);
                _loadSessions(); // Reload to show changes
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final edited = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SessionEditScreen(
                    sessionId: sessionData.session.id,
                  ),
                ),
              );
              if (edited == true) {
                setState(() => _hasChanges = true);
                _loadSessions(); // Reload to show changes
              }
            },
            child: const Text(
              'Edit',
              style: TextStyle(
                color: burgundy,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'close'),
            child: const Text(
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

    // Reload if edited
    if (result == true && mounted) {
      _loadSessions();
    }
  }

  Future<bool> _deleteSessionWithConfirmation(String sessionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session'),
        content: const Text('Are you sure you want to delete this session? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    try {
      await _sessionService.deleteSession(sessionId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete session: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }
}
