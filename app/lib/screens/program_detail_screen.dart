import 'package:flutter/material.dart';
import '../models/program.dart';
import '../models/exercise.dart';
import '../models/user.dart';
import '../widgets/xg_button.dart';
import 'practice_screen.dart';
import 'program_edit_screen.dart';

class ProgramDetailScreen extends StatelessWidget {
  final Program program;
  final User? user; // Optional - if provided, shows edit button

  const ProgramDetailScreen({
    Key? key,
    required this.program,
    this.user,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const burgundy = Color(0xFF9B1C1C);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: burgundy),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (user != null)
            IconButton(
              icon: Icon(Icons.edit, color: burgundy),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ProgramEditScreen(
                      user: user!,
                      program: program,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Header section
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  program.name,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: burgundy,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  program.description,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildInfoChip(
                      Icons.fitness_center,
                      '${program.exercises.length} exercises',
                      burgundy,
                    ),
                    const SizedBox(width: 12),
                    _buildInfoChip(
                      Icons.schedule,
                      '${program.totalDurationMinutes} min',
                      burgundy,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Exercises list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: program.exercises.length,
              itemBuilder: (context, index) {
                final exercise = program.exercises[index];
                return _buildExerciseCard(exercise, index + 1);
              },
            ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Video submission card
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9B1C1C).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF9B1C1C).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Video submission - Coming soon!'),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFF9B1C1C).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.videocam,
                                color: Color(0xFF9B1C1C),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Submit Practice Video',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF9B1C1C),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Get feedback from your instructor',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Start practice button
                  XGButton(
                    text: 'Start Practice',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PracticeScreen(program: program),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(Exercise exercise, int number) {
    const burgundy = Color(0xFF9B1C1C);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Number badge
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: burgundy.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$number',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: burgundy,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Exercise details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    exercise.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildExerciseTag(
                        _getTypeIcon(exercise.type),
                        exercise.displayDuration,
                        burgundy,
                      ),
                      if (exercise.hasSides)
                        _buildExerciseTag(
                          Icons.swap_horiz,
                          'Both sides',
                          burgundy,
                        ),
                      if (exercise.restAfterSeconds > 0)
                        _buildExerciseTag(
                          Icons.pause_circle_outline,
                          '${exercise.restAfterSeconds}s rest',
                          Colors.grey.shade600,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseTag(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(ExerciseType type) {
    switch (type) {
      case ExerciseType.timed:
        return Icons.timer;
      case ExerciseType.repetition:
        return Icons.repeat;
      case ExerciseType.combined:
        return Icons.all_inclusive;
    }
  }
}
