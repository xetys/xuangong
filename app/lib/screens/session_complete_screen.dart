import 'package:flutter/material.dart';
import '../models/program.dart';
import '../widgets/xg_button.dart';

class SessionCompleteScreen extends StatelessWidget {
  final Program program;

  const SessionCompleteScreen({Key? key, required this.program}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const burgundy = Color(0xFF9B1C1C);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
              // Success icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: burgundy.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: burgundy,
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                'Practice Complete!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: burgundy,
                ),
              ),
              const SizedBox(height: 16),

              // Subtitle
              Text(
                'Well done! You completed ${program.name}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),

              // Stats cards
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      Icons.fitness_center,
                      '${program.exercises.length}',
                      'Exercises',
                      burgundy,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      Icons.schedule,
                      '${program.totalDurationMinutes}',
                      'Minutes',
                      burgundy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      Icons.local_fire_department,
                      '3',
                      'Day Streak',
                      burgundy,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      Icons.trending_up,
                      '12',
                      'Total Sessions',
                      burgundy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),

              // Actions
              XGButton(
                text: 'Back to Home',
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Session history - Coming soon!'),
                    ),
                  );
                },
                child: Text(
                  'View Session History',
                  style: TextStyle(
                    color: burgundy,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
