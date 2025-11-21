import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/program.dart';
import '../models/exercise.dart';
import '../models/user.dart';
import '../services/audio_service.dart';
import '../services/notification_service.dart';
import 'session_complete_screen.dart';

class PracticeScreen extends StatefulWidget {
  final Program program;
  final User user;

  const PracticeScreen({Key? key, required this.program, required this.user}) : super(key: key);

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> with WidgetsBindingObserver {
  final AudioService _audioService = AudioService();
  final NotificationService _notificationService = NotificationService();

  int currentExerciseIndex = 0;
  int remainingSeconds = 0;
  Timer? _timer;
  Timer? _wakelockTimer;
  bool isPaused = false;
  bool isResting = false;
  bool isWuWeiMode = false;
  PracticePhase phase = PracticePhase.countdown;
  int countdownValue = 10;
  bool _hasShownInitialCountdown = false;
  int _initialExerciseDuration = 0;
  bool _halfTimeSoundPlayed = false;
  bool _isInBackground = false;
  int? _currentSide; // null, 1, or 2 - tracks which side is being practiced

  @override
  void initState() {
    super.initState();
    // Add lifecycle observer
    WidgetsBinding.instance.addObserver(this);

    // Enable wake lock to keep screen on
    WakelockPlus.enable();

    // Start periodic wake lock renewal every 30 seconds to ensure reliability
    _wakelockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      WakelockPlus.enable();
    });

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

    // Start countdown after audio is initialized
    _initializeAudio().then((_) {
      _startCountdown();
    });
  }

  Future<void> _initializeAudio() async {
    await _audioService.initialize();
    await _audioService.setAllVolumes(
      countdown: widget.user.countdownVolume,
      start: widget.user.startVolume,
      halfway: widget.user.halfwayVolume,
      finish: widget.user.finishVolume,
    );
  }

  @override
  void dispose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    _timer?.cancel();
    _wakelockTimer?.cancel();

    // Disable wake lock
    WakelockPlus.disable();

    // Clear any notifications
    _notificationService.clearNotifications();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Track when app goes to background/foreground
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _isInBackground = true;
      _updateNotification();
    } else if (state == AppLifecycleState.resumed) {
      _isInBackground = false;
      _notificationService.clearNotifications();
    }
  }

  /// Update notification with current practice state
  /// Only shows notification when app is in background
  void _updateNotification() {
    if (!_isInBackground) return;

    final exercise = widget.program.exercises[currentExerciseIndex];
    final current = currentExerciseIndex + 1;
    final total = widget.program.exercises.length;

    if (phase == PracticePhase.countdown) {
      // Don't show notification during countdown
      return;
    } else if (phase == PracticePhase.rest) {
      _notificationService.showRestNotification(
        remainingSeconds: remainingSeconds,
        currentExercise: current,
        totalExercises: total,
      );
    } else if (exercise.type == ExerciseType.repetition) {
      _notificationService.showRepetitionNotification(
        exerciseName: exercise.name,
        repetitions: exercise.repetitions,
        currentExercise: current,
        totalExercises: total,
      );
    } else {
      final exerciseName = exercise.hasSides && _currentSide != null
          ? '${exercise.name} - ${_currentSide == 1 ? 'First' : 'Second'} Side'
          : exercise.name;

      _notificationService.showTimerNotification(
        exerciseName: exerciseName,
        remainingSeconds: remainingSeconds,
        currentExercise: current,
        totalExercises: total,
      );
    }
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

    // Initialize side tracking for exercises with sides
    if (exercise.hasSides && _currentSide == null) {
      _currentSide = 1;
    }

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

    // Determine duration based on current side
    int duration;
    if (exercise.hasSides && _currentSide == 2) {
      // Second side: use sideDurationSeconds if available, else fall back to durationSeconds
      duration = exercise.sideDurationSeconds ?? exercise.durationSeconds ?? 60;
    } else {
      // First side or single-sided exercise
      duration = exercise.durationSeconds ?? 60;
    }

    setState(() {
      phase = PracticePhase.exercise;
      remainingSeconds = duration;
      isPaused = false;
      _initialExerciseDuration = duration;
      _halfTimeSoundPlayed = false;
    });

    // If not first exercise or transitioning to side 2, play start sound
    if (_hasShownInitialCountdown && (currentExerciseIndex > 0 || _currentSide == 2)) {
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

            // Update notification with new time
            _updateNotification();
          } else {
            _timer?.cancel();
            // Don't play sound here - handle exercise completion
            _handleExerciseComplete();
          }
        });
      }
    });
  }

  void _handleExerciseComplete() {
    final exercise = widget.program.exercises[currentExerciseIndex];

    // Check if we need to transition to the second side
    if (exercise.hasSides && _currentSide == 1) {
      // Transition to second side
      setState(() {
        _currentSide = 2;
      });
      _startExercise();
      return;
    }

    // Both sides complete (or single-sided exercise), reset side tracking
    setState(() {
      _currentSide = null;
    });

    // Start rest period or move to next exercise
    _startRest();
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

            // Update notification with new time
            _updateNotification();
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

    final exercise = widget.program.exercises[currentExerciseIndex];

    // If on first side of a two-sided exercise, skip to second side
    if (exercise.hasSides && _currentSide == 1) {
      setState(() {
        _currentSide = 2;
      });
      _audioService.playStart();
      _startExercise();
      return;
    }

    // Otherwise skip to next exercise and reset side tracking
    setState(() {
      _currentSide = null;
    });
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
            if (exercise.hasSides && _currentSide != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: burgundy.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _currentSide == 1 ? 'First Side' : 'Second Side',
                  style: TextStyle(
                    color: burgundy,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
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
                _handleExerciseComplete();
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
          if (exercise.hasSides && _currentSide != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: burgundy.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _currentSide == 1 ? 'First Side' : 'Second Side',
                style: TextStyle(
                  color: burgundy,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
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
