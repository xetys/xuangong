import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/program.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import 'student_edit_screen.dart';
import 'program_edit_screen.dart';
import 'program_detail_screen.dart';

class StudentDetailScreen extends StatefulWidget {
  final User student;

  const StudentDetailScreen({super.key, required this.student});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();
  List<Program>? _programs;
  User? _currentUser; // The logged-in admin user
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Load current admin user and student's programs
      final currentUser = await _authService.getCurrentUser();
      final programs = await _userService.getUserPrograms(widget.student.id);
      setState(() {
        _currentUser = currentUser;
        _programs = programs;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadPrograms() async {
    // Reload programs only (for refresh after adding/editing)
    try {
      final programs = await _userService.getUserPrograms(widget.student.id);
      setState(() {
        _programs = programs;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reload programs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteStudent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student'),
        content: Text('Are you sure you want to delete ${widget.student.fullName}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _userService.deleteUser(widget.student.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting student: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const burgundy = Color(0xFF9B1C1C);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Student Details'),
        backgroundColor: burgundy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => StudentEditScreen(student: widget.student),
                ),
              );
              if (result == true && mounted) {
                // Refresh would require reloading student details
                Navigator.of(context).pop(true);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteStudent,
          ),
        ],
      ),
      body: Column(
        children: [
          // Student info card
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: burgundy.withValues(alpha: 0.1),
                  child: Text(
                    widget.student.fullName.isNotEmpty
                        ? widget.student.fullName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w600,
                      color: burgundy,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.student.fullName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.student.email,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    if (widget.student.isAdmin)
                      Chip(
                        label: const Text('ADMIN'),
                        backgroundColor: burgundy.withValues(alpha: 0.1),
                        labelStyle: TextStyle(
                          color: burgundy,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    Chip(
                      label: Text(widget.student.isActive ? 'ACTIVE' : 'INACTIVE'),
                      backgroundColor: widget.student.isActive
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.1),
                      labelStyle: TextStyle(
                        color: widget.student.isActive ? Colors.green.shade700 : Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Programs section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Row(
              children: [
                const Text(
                  'Assigned Programs',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (_programs != null)
                  Text(
                    '${_programs!.length} program${_programs!.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _buildProgramsList(burgundy),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ProgramEditScreen(
                ownedByUserId: widget.student.id,
              ),
            ),
          );

          if (result == true && mounted) {
            _loadPrograms();
          }
        },
        backgroundColor: burgundy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Program'),
      ),
    );
  }

  Widget _buildProgramsList(Color burgundy) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Error loading programs',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPrograms,
              style: ElevatedButton.styleFrom(
                backgroundColor: burgundy,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_programs == null || _programs!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No programs assigned',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a program for this student',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _programs!.length,
      itemBuilder: (context, index) {
        final program = _programs![index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildProgramCard(context, program, burgundy),
        );
      },
    );
  }

  Widget _buildProgramCard(BuildContext context, Program program, Color burgundy) {
    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            // Navigate to regular ProgramDetailScreen with admin user
            final result = await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ProgramDetailScreen(
                  program: program,
                  user: _currentUser,
                ),
              ),
            );

            if (result == true && mounted) {
              _loadPrograms();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  program.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  program.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.fitness_center,
                      size: 16,
                      color: burgundy.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${program.exercises.length} exercises',
                      style: TextStyle(
                        fontSize: 14,
                        color: burgundy.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.schedule,
                      size: 16,
                      color: burgundy.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${program.totalDurationMinutes} min',
                      style: TextStyle(
                        fontSize: 14,
                        color: burgundy.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.repeat,
                      size: 16,
                      color: burgundy.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      program.repetitionsPlanned != null
                          ? '${program.repetitionsCompleted ?? 0}/${program.repetitionsPlanned}'
                          : '${program.repetitionsCompleted ?? 0} sessions',
                      style: TextStyle(
                        fontSize: 14,
                        color: burgundy.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w600,
                      ),
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
}
