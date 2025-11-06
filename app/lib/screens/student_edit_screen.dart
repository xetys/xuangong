import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/user_service.dart';

class StudentEditScreen extends StatefulWidget {
  final User? student; // null for create, non-null for edit

  const StudentEditScreen({super.key, this.student});

  @override
  State<StudentEditScreen> createState() => _StudentEditScreenState();
}

class _StudentEditScreenState extends State<StudentEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final UserService _userService = UserService();

  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  bool _isActive = true;
  bool _isAdmin = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.student?.fullName ?? '');
    _emailController = TextEditingController(text: widget.student?.email ?? '');
    _passwordController = TextEditingController();
    _isActive = widget.student?.isActive ?? true;
    _isAdmin = widget.student?.isAdmin ?? false;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      if (widget.student == null) {
        // Create new student
        await _userService.createUser(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _fullNameController.text.trim(),
          role: _isAdmin ? 'admin' : 'student',
        );
      } else {
        // Update existing student
        await _userService.updateUser(
          userId: widget.student!.id,
          email: _emailController.text.trim(),
          fullName: _fullNameController.text.trim(),
          password: _passwordController.text.isNotEmpty ? _passwordController.text : null,
          isActive: _isActive,
        );

        // Update role if it changed
        final currentRole = widget.student!.role;
        final newRole = _isAdmin ? 'admin' : 'student';
        if (currentRole != newRole) {
          try {
            await _userService.updateUserRole(
              userId: widget.student!.id,
              role: newRole,
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Role updated to $newRole'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (roleError) {
            // Role update failed, revert the toggle
            setState(() => _isAdmin = !_isAdmin);
            if (mounted) {
              final errorMsg = roleError.toString();
              String friendlyMessage = 'Failed to update role';

              if (errorMsg.contains('last admin') || errorMsg.contains('at least one admin')) {
                friendlyMessage = 'Cannot remove admin privileges: System must have at least one admin user';
              }

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(friendlyMessage),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
            // Re-throw to prevent "success" message
            rethrow;
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.student == null ? 'Student created successfully' : 'Student updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      // Only show generic error if not already handled
      if (mounted && !e.toString().contains('last admin')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const burgundy = Color(0xFF9B1C1C);
    final isEditing = widget.student != null;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Student' : 'New Student'),
        backgroundColor: burgundy,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            TextFormField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a name';
                }
                if (value.trim().length < 2) {
                  return 'Name must be at least 2 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an email';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: isEditing ? 'New Password (leave blank to keep current)' : 'Password',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              validator: (value) {
                if (!isEditing && (value == null || value.isEmpty)) {
                  return 'Please enter a password';
                }
                if (value != null && value.isNotEmpty && value.length < 8) {
                  return 'Password must be at least 8 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              title: const Text('Active'),
              subtitle: const Text('User can log in'),
              value: _isActive,
              activeColor: burgundy,
              onChanged: (value) => setState(() => _isActive = value),
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Admin'),
              subtitle: const Text('User has admin privileges'),
              value: _isAdmin,
              activeColor: burgundy,
              onChanged: (value) => setState(() => _isAdmin = value),
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: burgundy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(isEditing ? 'Save Changes' : 'Create Student'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
