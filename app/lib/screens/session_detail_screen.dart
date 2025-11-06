import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/session.dart';
import '../services/session_service.dart';

class SessionDetailScreen extends StatefulWidget {
  final String sessionId;

  const SessionDetailScreen({
    super.key,
    required this.sessionId,
  });

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  final SessionService _sessionService = SessionService();
  SessionWithLogs? _session;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = await _sessionService.getSession(widget.sessionId);
      setState(() {
        _session = session;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const burgundy = Color(0xFF9B1C1C);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Session Details'),
        backgroundColor: burgundy,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(burgundy),
    );
  }

  Widget _buildBody(Color burgundy) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                'Error loading session',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadSession,
                style: ElevatedButton.styleFrom(
                  backgroundColor: burgundy,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_session == null) {
      return Center(
        child: Text(
          'Session not found',
          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(burgundy),
          const SizedBox(height: 24),
          _buildExerciseLogsCard(burgundy),
          if (_session!.session.notes != null && _session!.session.notes!.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildNotesCard(burgundy),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard(Color burgundy) {
    final session = _session!.session;
    final dateStr = session.completedAt != null
        ? DateFormat('EEEE, MMMM d, y').format(session.completedAt!)
        : 'In progress';
    final timeStr = session.completedAt != null
        ? DateFormat('h:mm a').format(session.completedAt!)
        : '';

    return Container(
      width: double.infinity,
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                session.completedAt != null
                    ? Icons.check_circle
                    : Icons.schedule,
                color:
                    session.completedAt != null ? Colors.green : burgundy,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
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
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.timer_outlined,
            'Duration',
            session.totalDurationSeconds != null
                ? '${(session.totalDurationSeconds! / 60).round()} minutes'
                : 'N/A',
            burgundy,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.trending_up,
            'Completion',
            session.completionRate != null
                ? '${session.completionRate!.toStringAsFixed(0)}%'
                : 'N/A',
            burgundy,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.calendar_today,
            'Started',
            DateFormat('MMM d, y h:mm a').format(session.startedAt),
            burgundy,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
      IconData icon, String label, String value, Color burgundy) {
    return Row(
      children: [
        Icon(icon, size: 20, color: burgundy.withValues(alpha: 0.7)),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseLogsCard(Color burgundy) {
    final logs = _session!.exerciseLogs;

    return Container(
      width: double.infinity,
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fitness_center, color: burgundy, size: 24),
              const SizedBox(width: 12),
              const Text(
                'Exercise Log',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (logs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'No exercises logged',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: logs.length,
              separatorBuilder: (_, __) => const Divider(height: 24),
              itemBuilder: (context, index) {
                final log = logs[index];
                return _buildExerciseLogItem(log, index + 1, burgundy);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildExerciseLogItem(ExerciseLog log, int exerciseNumber, Color burgundy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Exercise $exerciseNumber',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (log.skipped)
          Row(
            children: [
              Icon(
                Icons.skip_next,
                size: 16,
                color: Colors.orange.shade700,
              ),
              const SizedBox(width: 6),
              Text(
                'Skipped',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        if (!log.skipped && log.repetitionsCompleted != null)
          Row(
            children: [
              Icon(
                Icons.repeat,
                size: 16,
                color: burgundy.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Text(
                '${log.repetitionsCompleted} repetitions completed',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        if (!log.skipped && log.actualDurationSeconds != null)
          Row(
            children: [
              Icon(
                Icons.timer_outlined,
                size: 16,
                color: burgundy.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Text(
                '${(log.actualDurationSeconds! / 60).round()} minutes',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        if (!log.skipped && log.completedAt != null)
          Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 16,
                color: Colors.green.shade700,
              ),
              const SizedBox(width: 6),
              Text(
                'Completed ${DateFormat('h:mm a').format(log.completedAt!)}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildNotesCard(Color burgundy) {
    return Container(
      width: double.infinity,
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.note_outlined, color: burgundy, size: 24),
              const SizedBox(width: 12),
              const Text(
                'Notes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _session!.session.notes!,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
