import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/program.dart';
import '../models/exercise.dart';
import '../models/session.dart';
import '../services/program_service.dart';
import '../services/session_service.dart';

class SessionEditScreen extends StatefulWidget {
  final String? sessionId; // null for create mode
  final String? initialProgramId;

  const SessionEditScreen({
    Key? key,
    this.sessionId,
    this.initialProgramId,
  }) : super(key: key);

  @override
  State<SessionEditScreen> createState() => _SessionEditScreenState();
}

class _SessionEditScreenState extends State<SessionEditScreen> {
  final ProgramService _programService = ProgramService();
  final SessionService _sessionService = SessionService();

  List<Program> _programs = [];
  Program? _selectedProgram;
  DateTime _sessionDate = DateTime.now();
  String? _notes;

  // Map of exercise ID to repetitions completed
  final Map<String, int?> _exerciseReps = {};

  // Map of exercise ID to TextEditingController
  final Map<String, TextEditingController> _repControllers = {};

  bool _isLoading = true;
  bool _isSaving = false;
  SessionWithLogs? _existingSession;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    // Dispose all text editing controllers
    _repControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      // Load programs
      final programs = await _programService.getMyPrograms();

      // If editing existing session, load it
      if (widget.sessionId != null) {
        final session = await _sessionService.getSession(widget.sessionId!);
        _existingSession = session;
        _sessionDate = session.session.completedAt ?? session.session.startedAt;
        _notes = session.session.notes;

        // Find the program for this session
        _selectedProgram = programs.firstWhere(
          (p) => p.id == session.session.programId,
          orElse: () => programs.first,
        );

        // Load existing rep counts
        for (var log in session.exerciseLogs) {
          _exerciseReps[log.exerciseId] = log.repetitionsCompleted;
        }
      } else if (widget.initialProgramId != null) {
        // Creating new session with pre-selected program
        _selectedProgram = programs.firstWhere(
          (p) => p.id == widget.initialProgramId,
          orElse: () => programs.first,
        );
      } else {
        // Creating new session, select first program
        _selectedProgram = programs.isNotEmpty ? programs.first : null;
      }

      setState(() {
        _programs = programs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveSession() async {
    if (_selectedProgram == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a program'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String sessionId;

      if (_existingSession != null) {
        // Editing existing session
        sessionId = _existingSession!.session.id;

        // Update session notes (already completed, so just update via complete endpoint)
        await _sessionService.completeSession(
          sessionId,
          notes: _notes,
          completedAt: _sessionDate,
        );
      } else {
        // Creating new session
        final newSession = await _sessionService.startSession(_selectedProgram!.id);
        sessionId = newSession.id;

        // Complete it immediately with the selected date
        await _sessionService.completeSession(
          sessionId,
          notes: _notes,
          completedAt: _sessionDate,
        );
      }

      // Log exercises with repetitions
      for (var exercise in _selectedProgram!.exercises) {
        if (_exerciseReps.containsKey(exercise.id)) {
          final reps = _exerciseReps[exercise.id];
          if (reps != null) {
            await _sessionService.logExercise(
              sessionId,
              exercise.id,
              repetitionsCompleted: reps,
            );
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save session: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteSession() async {
    if (_existingSession == null) return;

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

    if (confirmed != true) return;

    setState(() => _isSaving = true);

    try {
      await _sessionService.deleteSession(_existingSession!.session.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete session: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _sessionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );

    if (picked != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_sessionDate),
      );

      if (time != null) {
        setState(() {
          _sessionDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const burgundy = Color(0xFF9B1C1C);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sessionId != null ? 'Edit Session' : 'Save Session'),
        backgroundColor: burgundy,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _programs.isEmpty
              ? const Center(
                  child: Text(
                    'No programs available.\nCreate a program first.',
                    textAlign: TextAlign.center,
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Program selector
                      const Text(
                        'Program',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<Program>(
                        value: _selectedProgram,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        items: _programs.map((program) {
                          return DropdownMenuItem(
                            value: program,
                            child: Text(program.name),
                          );
                        }).toList(),
                        onChanged: (program) {
                          setState(() {
                            _selectedProgram = program;
                            _exerciseReps.clear(); // Reset reps when changing program
                            // Dispose old controllers and clear the map
                            _repControllers.values.forEach((controller) => controller.dispose());
                            _repControllers.clear();
                          });
                        },
                      ),
                      const SizedBox(height: 24),

                      // Date/Time selector
                      const Text(
                        'Date & Time',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _selectDate,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, color: burgundy),
                              const SizedBox(width: 12),
                              Text(
                                DateFormat('MMM dd, yyyy - HH:mm').format(_sessionDate),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Exercise repetitions
                      if (_selectedProgram != null) ...[
                        const Text(
                          'Repetitions',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._buildExerciseInputs(),
                        const SizedBox(height: 24),
                      ],

                      // Notes
                      const Text(
                        'Notes (optional)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        maxLines: 3,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          hintText: 'Add any notes about this practice session...',
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        onChanged: (value) => _notes = value.isEmpty ? null : value,
                      ),
                      const SizedBox(height: 32),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveSession,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: burgundy,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Save Session',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),

                      // Delete button (only show when editing existing session)
                      if (_existingSession != null) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _isSaving ? null : _deleteSession,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Delete Session',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  List<Widget> _buildExerciseInputs() {
    final repExercises = _selectedProgram!.exercises
        .where((ex) => ex.type == ExerciseType.repetition || ex.type == ExerciseType.combined)
        .toList();

    if (repExercises.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'No repetition-based exercises in this program',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      ];
    }

    return repExercises.map((exercise) {
      // Create controller if it doesn't exist
      if (!_repControllers.containsKey(exercise.id)) {
        _repControllers[exercise.id] = TextEditingController(
          text: _exerciseReps[exercise.id]?.toString() ?? '',
        );
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                exercise.name,
                style: const TextStyle(fontSize: 15),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  hintText: exercise.repetitions?.toString() ?? '0',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                  ),
                  suffixText: 'reps',
                ),
                controller: _repControllers[exercise.id],
                onChanged: (value) {
                  final reps = int.tryParse(value);
                  _exerciseReps[exercise.id] = reps;
                },
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
