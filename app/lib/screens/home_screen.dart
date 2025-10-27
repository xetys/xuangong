import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/program.dart';
import '../services/auth_service.dart';
import '../widgets/practice_history_widget.dart';
import 'login_screen.dart';
import 'program_detail_screen.dart';
import 'program_edit_screen.dart';

class HomeScreen extends StatelessWidget {
  final User user;

  const HomeScreen({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const burgundy = Color(0xFF9B1C1C);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '玄功',
          style: TextStyle(
            color: burgundy,
            fontSize: 24,
            fontWeight: FontWeight.w300,
            letterSpacing: 4,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: burgundy),
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome message
                Text(
                  'Welcome back,',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.fullName,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: burgundy,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  user.isStudent ? 'Student' : 'Instructor',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 32),

                // Practice history widget
                const PracticeHistoryWidget(),
                const SizedBox(height: 32),

                // Section title
                const Text(
                  'Your Programs',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),

                // Mock program cards
                _buildProgramCard(
                  context,
                  title: 'Morning Qi Gong',
                  exercises: 5,
                  duration: '30 min',
                  description: 'Gentle movements to awaken the body',
                ),
                const SizedBox(height: 12),
                _buildProgramCard(
                  context,
                  title: 'Tai Chi Form',
                  exercises: 8,
                  duration: '45 min',
                  description: 'Yang style 24-form practice',
                ),
                const SizedBox(height: 12),
                _buildProgramCard(
                  context,
                  title: 'Ba Gua Circle Walking',
                  exercises: 6,
                  duration: '40 min',
                  description: 'Single palm change meditation walk',
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ProgramEditScreen(user: user),
            ),
          );
        },
        backgroundColor: burgundy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Program'),
      ),
    );
  }

  Widget _buildProgramCard(
    BuildContext context, {
    required String title,
    required int exercises,
    required String duration,
    required String description,
  }) {
    const burgundy = Color(0xFF9B1C1C);

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
          onTap: () {
            // Navigate to program detail with mock data
            final mockProgram = Program.getMockProgram();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ProgramDetailScreen(
                  program: mockProgram,
                  user: user,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
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
                      '$exercises exercises',
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
                      duration,
                      style: TextStyle(
                        fontSize: 14,
                        color: burgundy.withValues(alpha: 0.7),
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

  Future<void> _handleLogout(BuildContext context) async {
    final authService = AuthService();
    await authService.logout();

    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );
    }
  }
}
