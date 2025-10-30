import 'dart:async';
import 'package:flutter/material.dart';
import '../models/program.dart';
import '../models/exercise.dart';
import '../services/audio_service.dart';
import 'session_complete_screen.dart';

class PracticeScreen extends StatefulWidget {
  final Program program;

  const PracticeScreen({Key? key, required this.program}) : super(key: key);

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  final AudioService _audioService = AudioService();

  int currentExerciseIndex = 0;
  int remainingSeconds = 0;
  Timer? _timer;
  bool isPaused = false;
  bool isResting = false;
  bool isWuWeiMode = false;
  PracticePhase phase = PracticePhase.countdown;
  int countdownValue = 10;
  bool _hasShownInitialCountdown = false;
  int _initialExerciseDuration = 0;
  bool _halfTimeSoundPlayed = false;

  @override
  void initState() {
    super.initState();
    // Initialize audio service
    _audioService.initialize();

    // Check if program has exercises
    if (widget.program.exercises.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This program has no exercises'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      });
      return;
    }
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    // Only show the 10-second countdown before the first exercise
    if (_hasShownInitialCountdown) {
      _startExercise();
      return;
    }

    setState(() {
      phase = PracticePhase.countdown;
      countdownValue = 10;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (countdownValue > 1) {
          countdownValue--;
          // Play last_two at countdown = 2
          if (countdownValue == 2) {
            _audioService.playLastTwo();
          }
        } else {
          // Countdown = 0, start exercise and play start sound
          _timer?.cancel();
          _hasShownInitialCountdown = true;
          _audioService.playStart();
          _startExercise();
        }
      });
    });
  }

  void _startExercise() {
    final exercise = widget.program.exercises[currentExerciseIndex];

    // For repetition-only exercises, don't start a timer
    if (exercise.type == ExerciseType.repetition) {
      setState(() {
        phase = PracticePhase.exercise;
        isPaused = false;
      });

      // If not first exercise, play start sound
      if (_hasShownInitialCountdown && currentExerciseIndex > 0) {
        _audioService.playStart();
      }
      return;
    }

    final duration = exercise.durationSeconds ?? 60; // Default 60s for mock

    setState(() {
      phase = PracticePhase.exercise;
      remainingSeconds = duration;
      isPaused = false;
      _initialExerciseDuration = duration;
      _halfTimeSoundPlayed = false;
    });

    // If not first exercise, play start sound
    if (_hasShownInitialCountdown && currentExerciseIndex > 0) {
      _audioService.playStart();
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isPaused) {
        setState(() {
          if (remainingSeconds > 0) {
            // Play half-time sound one second earlier (at half + 1)
            final halfTime = (_initialExerciseDuration / 2).round();
            if (!_halfTimeSoundPlayed && remainingSeconds == halfTime + 1) {
              _audioService.playHalf();
              _halfTimeSoundPlayed = true;
            }

            // Play last 2 seconds sound
            if (remainingSeconds == 2) {
              _audioService.playLastTwo();
            }

            remainingSeconds--;
          } else {
            _timer?.cancel();
            // Don't play sound here - just move to rest or next exercise
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
      // Session completed naturally - play longgong
      _audioService.playLongGong();
      _completeSession();
    }
  }

  void _skipExercise() {
    _timer?.cancel();

    // If in countdown phase, skip to exercise start
    if (phase == PracticePhase.countdown) {
      _hasShownInitialCountdown = true;
      _audioService.playStart();
      _startExercise();
      return;
    }

    // Otherwise skip to next exercise
    _audioService.playStart();
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
    // Play longgong when manually completing session
    _audioService.playLongGong();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => SessionCompleteScreen(program: widget.program),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const burgundy = Color(0xFF9B1C1C);

    // Guard against empty exercises list
    if (widget.program.exercises.isEmpty) {
      return Scaffold(
        backgroundColor: burgundy,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

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
                  // Only show pause and Wu Wei for timed exercises
                  if (phase == PracticePhase.exercise && exercise.type != ExerciseType.repetition)
                    _buildControlButton(
                      isPaused ? Icons.play_arrow : Icons.pause,
                      isPaused ? 'Resume' : 'Pause',
                      () => _togglePause(),
                    ),
                  if (phase == PracticePhase.exercise && exercise.type != ExerciseType.repetition)
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
      // For repetition-only exercises, show a "Done" button
      if (exercise.type == ExerciseType.repetition) {
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
            const SizedBox(height: 16),
            if (exercise.repetitions != null)
              Text(
                '${exercise.repetitions} repetitions',
                style: TextStyle(
                  fontSize: 20,
                  color: burgundy.withValues(alpha: 0.7),
                ),
              ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: () {
                _timer?.cancel();
                _startRest();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: burgundy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.check_circle, size: 32),
              label: const Text(
                'Done',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Tap when finished',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        );
      }

      // For timed or combined exercises, show timer
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
