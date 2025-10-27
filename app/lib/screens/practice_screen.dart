import 'dart:async';
import 'package:flutter/material.dart';
import '../models/program.dart';
import '../models/exercise.dart';
import 'session_complete_screen.dart';

class PracticeScreen extends StatefulWidget {
  final Program program;

  const PracticeScreen({Key? key, required this.program}) : super(key: key);

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  int currentExerciseIndex = 0;
  int remainingSeconds = 0;
  Timer? _timer;
  bool isPaused = false;
  bool isResting = false;
  bool isWuWeiMode = false;
  PracticePhase phase = PracticePhase.countdown;
  int countdownValue = 3;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() {
      phase = PracticePhase.countdown;
      countdownValue = 3;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (countdownValue > 1) {
          countdownValue--;
        } else {
          _timer?.cancel();
          _startExercise();
        }
      });
    });
  }

  void _startExercise() {
    final exercise = widget.program.exercises[currentExerciseIndex];
    setState(() {
      phase = PracticePhase.exercise;
      remainingSeconds = exercise.durationSeconds ?? 60; // Default 60s for mock
      isPaused = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isPaused) {
        setState(() {
          if (remainingSeconds > 0) {
            remainingSeconds--;
          } else {
            _timer?.cancel();
            _startRest();
          }
        });
      }
    });
  }

  void _startRest() {
    final exercise = widget.program.exercises[currentExerciseIndex];
    if (exercise.restAfterSeconds > 0) {
      setState(() {
        phase = PracticePhase.rest;
        isResting = true;
        remainingSeconds = exercise.restAfterSeconds;
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          if (remainingSeconds > 0) {
            remainingSeconds--;
          } else {
            _timer?.cancel();
            _nextExercise();
          }
        });
      });
    } else {
      _nextExercise();
    }
  }

  void _nextExercise() {
    if (currentExerciseIndex < widget.program.exercises.length - 1) {
      setState(() {
        currentExerciseIndex++;
        isResting = false;
      });
      _startCountdown();
    } else {
      _completeSession();
    }
  }

  void _skipExercise() {
    _timer?.cancel();
    _nextExercise();
  }

  void _togglePause() {
    setState(() {
      isPaused = !isPaused;
    });
  }

  void _toggleWuWeiMode() {
    setState(() {
      isWuWeiMode = !isWuWeiMode;
    });
  }

  void _completeSession() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => SessionCompleteScreen(program: widget.program),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const burgundy = Color(0xFF9B1C1C);
    final exercise = widget.program.exercises[currentExerciseIndex];
    final progress = (currentExerciseIndex + 1) / widget.program.exercises.length;

    return Scaffold(
      backgroundColor: burgundy,
      body: SafeArea(
        child: Column(
          children: [
            // Header with progress
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => _showExitDialog(context),
                      ),
                      Text(
                        '${currentExerciseIndex + 1}/${widget.program.exercises.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 48), // Balance layout
                    ],
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 4,
                  ),
                ],
              ),
            ),

            // Main content
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: _buildPhaseContent(exercise, burgundy),
              ),
            ),

            // Controls
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControlButton(
                    Icons.skip_next,
                    'Skip',
                    () => _skipExercise(),
                  ),
                  if (phase == PracticePhase.exercise)
                    _buildControlButton(
                      isPaused ? Icons.play_arrow : Icons.pause,
                      isPaused ? 'Resume' : 'Pause',
                      () => _togglePause(),
                    ),
                  if (phase == PracticePhase.exercise)
                    _buildControlButton(
                      isWuWeiMode ? Icons.visibility : Icons.visibility_off,
                      'Wu Wei',
                      () => _toggleWuWeiMode(),
                    ),
                  _buildControlButton(
                    Icons.check,
                    'Complete',
                    () => _completeSession(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseContent(Exercise exercise, Color burgundy) {
    if (phase == PracticePhase.countdown) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              exercise.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: burgundy,
              ),
            ),
            const SizedBox(height: 48),
            Text(
              '$countdownValue',
              style: TextStyle(
                fontSize: 96,
                fontWeight: FontWeight.w300,
                color: burgundy,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Get ready...',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    } else if (phase == PracticePhase.rest) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.self_improvement, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 32),
            Text(
              'Rest',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: burgundy,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '$remainingSeconds',
              style: TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.w300,
                color: burgundy,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Breathe deeply...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    } else {
      // Exercise phase
      final minutes = remainingSeconds ~/ 60;
      final seconds = remainingSeconds % 60;
      final timeDisplay = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            exercise.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: burgundy,
            ),
          ),
          const SizedBox(height: 32),
          // Show meditation icon in Wu Wei mode, otherwise show time
          if (isWuWeiMode)
            Icon(
              Icons.self_improvement,
              size: 96,
              color: burgundy.withValues(alpha: 0.7),
            )
          else
            Text(
              timeDisplay,
              style: TextStyle(
                fontSize: 96,
                fontWeight: FontWeight.w300,
                color: burgundy,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          const SizedBox(height: 24),
          if (isPaused)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'PAUSED',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ),
        ],
      );
    }
  }

  Widget _buildControlButton(IconData icon, String label, VoidCallback onPressed) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, color: Colors.white),
          iconSize: 32,
          onPressed: onPressed,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Practice?'),
        content: const Text('Are you sure you want to end this practice session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close practice screen
            },
            child: const Text('End'),
          ),
        ],
      ),
    );
  }
}

enum PracticePhase {
  countdown,
  exercise,
  rest,
}
