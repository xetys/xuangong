import 'package:flutter/material.dart';
import '../screens/practice_calendar_screen.dart';

class PracticeHistoryWidget extends StatefulWidget {
  const PracticeHistoryWidget({Key? key}) : super(key: key);

  @override
  State<PracticeHistoryWidget> createState() => _PracticeHistoryWidgetState();
}

class _PracticeHistoryWidgetState extends State<PracticeHistoryWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Scroll to the right after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToEnd();
    });
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
    final reversedData = mockPracticeData.reversed.toList();

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
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const PracticeCalendarScreen(),
                    ),
                  );
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
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: reversedData.length,
            itemBuilder: (context, index) {
              final practice = reversedData[index];
              return Padding(
                padding: EdgeInsets.only(right: index < reversedData.length - 1 ? 12 : 0),
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
    final visibleSessions = practice.sessionNames.take(3).toList();
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
