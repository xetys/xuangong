import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../screens/practice_calendar_screen.dart';
import '../services/session_service.dart';
import '../models/session.dart';

class PracticeHistoryWidget extends StatefulWidget {
  final VoidCallback? onRefresh;

  const PracticeHistoryWidget({Key? key, this.onRefresh}) : super(key: key);

  @override
  State<PracticeHistoryWidget> createState() => _PracticeHistoryWidgetState();
}

class _PracticeHistoryWidgetState extends State<PracticeHistoryWidget> {
  final ScrollController _scrollController = ScrollController();
  final SessionService _sessionService = SessionService();
  List<PracticeDay>? _practiceData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPracticeHistory();
    // Scroll to the right after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToEnd();
    });
  }

  // Public method to refresh data
  void refresh() {
    _loadPracticeHistory();
  }

  Future<void> _loadPracticeHistory() async {
    setState(() => _isLoading = true);

    try {
      // Get last 7 days
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
      final endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

      // Fetch sessions
      final sessions = await _sessionService.listSessions(
        startDate: startDate,
        endDate: endDate,
        limit: 100,
      );

      // Group sessions by day
      final Map<String, List<SessionWithLogs>> sessionsByDay = {};
      for (final session in sessions) {
        if (session.session.completedAt != null) {
          final dateKey = DateFormat('yyyy-MM-dd').format(session.session.completedAt!);
          sessionsByDay.putIfAbsent(dateKey, () => []);
          sessionsByDay[dateKey]!.add(session);
        }
      }

      // Build practice data for last 7 days
      final practiceData = <PracticeDay>[];
      for (int i = 6; i >= 0; i--) {
        final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        final daySessions = sessionsByDay[dateKey] ?? [];

        // Determine day name
        String dayName;
        if (i == 0) {
          dayName = 'Today';
        } else if (i == 1) {
          dayName = 'Yesterday';
        } else {
          dayName = DateFormat('E').format(date); // Mon, Tue, etc.
        }

        practiceData.add(PracticeDay(
          dayName: dayName,
          date: DateFormat('d').format(date),
          status: daySessions.isEmpty ? PracticeStatus.skipped : PracticeStatus.completed,
          sessionNames: daySessions.map((s) => s.session.programName ?? 'Practice').toList(),
        ));
      }

      setState(() {
        _practiceData = practiceData;
        _isLoading = false;
      });

      // Scroll to end after data is loaded and widget is rebuilt
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToEnd();
      });
    } catch (e) {
      print('Error loading practice history: $e');
      setState(() {
        _practiceData = [];
        _isLoading = false;
      });
    }
  }

  void _scrollToEnd() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    } else {
      // If not ready yet, try again in the next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToEnd();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const burgundy = Color(0xFF9B1C1C);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Practice',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const PracticeCalendarScreen(),
                    ),
                  );

                  // Refresh if any changes were made in the calendar
                  if (result == true && mounted) {
                    _loadPracticeHistory();
                  }
                },
                child: Text(
                  'Show All',
                  style: TextStyle(
                    fontSize: 14,
                    color: burgundy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 130,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _practiceData == null || _practiceData!.isEmpty
                  ? Center(
                      child: Text(
                        'No practice history yet',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: _practiceData!.length,
                      itemBuilder: (context, index) {
                        final practice = _practiceData![index];
                        return Padding(
                          padding: EdgeInsets.only(right: index < _practiceData!.length - 1 ? 12 : 0),
                          child: _buildPracticeCard(practice, burgundy),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildPracticeCard(PracticeDay practice, Color burgundy) {
    final isCompleted = practice.status == PracticeStatus.completed;
    final statusColor = isCompleted ? burgundy : Colors.grey.shade400;
    final visibleSessions = practice.sessionNames.take(2).toList();
    final remainingSessions = practice.sessionNames.length - visibleSessions.length;

    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted
              ? burgundy.withValues(alpha: 0.3)
              : Colors.grey.shade200,
          width: isCompleted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date with status indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    practice.dayName,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    practice.date,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Icon(
                isCompleted ? Icons.check_box : Icons.check_box_outline_blank,
                color: statusColor,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Session names
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...visibleSessions.map((sessionName) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      sessionName,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )),
                  if (remainingSessions > 0)
                    Text(
                      '+ $remainingSessions more',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Mock data
enum PracticeStatus {
  completed,
  partial,
  skipped,
}

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
  PracticeDay(
    dayName: 'Wed',
    date: '23',
    status: PracticeStatus.skipped,
    sessionNames: [],
  ),
  PracticeDay(
    dayName: 'Tue',
    date: '22',
    status: PracticeStatus.completed,
    sessionNames: ['Morning Qi Gong', 'Tai Chi Form'],
    durationMinutes: 30,
  ),
  PracticeDay(
    dayName: 'Mon',
    date: '21',
    status: PracticeStatus.completed,
    sessionNames: ['Morning Qi Gong'],
    durationMinutes: 29,
  ),
];
