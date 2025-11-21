import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html show window;
import '../models/user.dart';
import '../models/program.dart';
import '../models/submission.dart';
import '../services/auth_service.dart';
import '../services/program_service.dart';
import '../services/submission_service.dart';
import '../widgets/practice_history_widget.dart';
import '../widgets/unread_badge.dart';
import 'login_screen.dart';
import 'program_detail_screen.dart';
import 'program_edit_screen.dart';
import 'account_screen.dart';
import 'settings_screen.dart';
import 'students_screen.dart';
import 'submissions_screen.dart';

class HomeScreen extends StatefulWidget {
  final User user;

  const HomeScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final ProgramService _programService = ProgramService();
  final SubmissionService _submissionService = SubmissionService();
  final AuthService _authService = AuthService();
  late TabController _tabController;
  late User _currentUser;
  List<Program>? _myPrograms;
  List<Program>? _templates;
  String? _myProgramsError;
  String? _templatesError;
  bool _loadingMyPrograms = true;
  bool _loadingTemplates = true;
  UnreadCounts? _unreadCounts;
  Timer? _unreadCountTimer; // Timer for auto-reloading unread counts
  final GlobalKey<State<PracticeHistoryWidget>> _practiceHistoryKey = GlobalKey();
  bool _isImpersonating = false;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    _checkImpersonationStatus();

    // Start periodic timer to reload unread counts every 30 seconds
    _unreadCountTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadUnreadCounts(),
    );
  }

  Future<void> _checkImpersonationStatus() async {
    final isImpersonating = await _authService.isImpersonating();
    setState(() {
      _isImpersonating = isImpersonating;
    });
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await _authService.getCurrentUser();
      setState(() {
        _currentUser = user;
      });
    } catch (e) {
      // Silently fail - user object not critical for display
      print('Failed to reload user: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _unreadCountTimer?.cancel(); // Cancel the timer
    super.dispose();
  }

  Future<void> _loadData() async {
    _loadMyPrograms();
    _loadTemplates();
    _loadUnreadCounts(); // Load for all users (students see their submissions, admins see all)
  }

  Future<void> _loadMyPrograms() async {
    setState(() {
      _loadingMyPrograms = true;
      _myProgramsError = null;
    });

    try {
      final programs = await _programService.getMyPrograms();
      setState(() {
        _myPrograms = programs;
        _loadingMyPrograms = false;
      });
    } catch (e, stackTrace) {
      print('Error loading programs: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _myProgramsError = e.toString();
        _loadingMyPrograms = false;
      });
    }
  }

  Future<void> _loadTemplates() async {
    setState(() {
      _loadingTemplates = true;
      _templatesError = null;
    });

    try {
      final templates = await _programService.getTemplates();
      setState(() {
        _templates = templates;
        _loadingTemplates = false;
      });
    } catch (e) {
      setState(() {
        _templatesError = e.toString();
        _loadingTemplates = false;
      });
    }
  }

  Future<void> _loadUnreadCounts() async {
    try {
      final counts = await _submissionService.getUnreadCount();
      setState(() {
        _unreadCounts = counts;
      });
    } catch (e) {
      // Silently fail for unread counts
      print('Failed to load unread counts: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    const burgundy = Color(0xFF9B1C1C);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: burgundy),
        title: Text(
          '玄功',
          style: TextStyle(
            color: burgundy,
            fontSize: 24,
            fontWeight: FontWeight.w300,
            letterSpacing: 4,
          ),
        ),
      ),
      drawer: _buildDrawer(context, burgundy),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Practice history widget
              PracticeHistoryWidget(key: _practiceHistoryKey),
              const SizedBox(height: 32),

              // Tab bar for My Programs and Templates
              TabBar(
                controller: _tabController,
                labelColor: burgundy,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorColor: burgundy,
                tabs: const [
                  Tab(text: 'My Programs'),
                  Tab(text: 'Templates'),
                ],
              ),
              const SizedBox(height: 16),

              // Tab content - expanded to fill remaining space
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // My Programs tab
                    _buildMyProgramsTab(burgundy),
                    // Templates tab
                    _buildTemplatesTab(burgundy),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ProgramEditScreen(user: _currentUser),
            ),
          );

          // If a program was created, reload the program lists
          if (result == true && mounted) {
            _loadMyPrograms();
            _loadTemplates();
          }
        },
        backgroundColor: burgundy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Program'),
      ),
    );
  }

  Widget _buildMyProgramsTab(Color burgundy) {
    if (_loadingMyPrograms) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_myProgramsError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
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
                _myProgramsError!,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadMyPrograms,
                style: ElevatedButton.styleFrom(
                  backgroundColor: burgundy,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_myPrograms == null || _myPrograms!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.self_improvement, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No programs yet',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a program to get started',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _myPrograms!.length,
      padding: const EdgeInsets.only(bottom: 80),
      itemBuilder: (context, index) {
        final program = _myPrograms![index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildProgramCard(context, program, burgundy, isTemplate: false),
        );
      },
    );
  }

  Widget _buildTemplatesTab(Color burgundy) {
    if (_loadingTemplates) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_templatesError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Error loading templates',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadTemplates,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_templates == null || _templates!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_books, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No templates available',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _templates!.length,
      padding: const EdgeInsets.only(bottom: 80),
      itemBuilder: (context, index) {
        final template = _templates![index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildProgramCard(context, template, burgundy, isTemplate: true),
        );
      },
    );
  }

  Widget _buildProgramCard(
    BuildContext context,
    Program program,
    Color burgundy, {
    required bool isTemplate,
  }) {
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
            final result = await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ProgramDetailScreen(
                  program: program,
                  user: _currentUser,
                ),
              ),
            );

            // If changes were saved or session completed, reload
            if (result != null && mounted) {
              _loadMyPrograms();
              _loadTemplates();
              _loadUnreadCounts(); // Reload unread counts
              // Refresh practice history widget
              final state = _practiceHistoryKey.currentState as dynamic;
              if (state != null && state.mounted) {
                state.refresh();
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        program.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // Show unread badge for non-template programs
                    if (!isTemplate && _unreadCounts != null && _unreadCounts!.byProgram.containsKey(program.id)) ...[
                      UnreadBadge(count: _unreadCounts!.byProgram[program.id]!),
                      const SizedBox(width: 8),
                    ],
                    if (isTemplate)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: burgundy.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'TEMPLATE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: burgundy,
                          ),
                        ),
                      ),
                  ],
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
                    // Show session count for non-template programs
                    if (!isTemplate) ...[
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
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, Color burgundy) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: burgundy,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(
                  Icons.account_circle,
                  size: 64,
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _currentUser.fullName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_isImpersonating)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'IMPERSONATING',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _currentUser.email,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: const Text('Account'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AccountScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            onTap: () async {
              Navigator.pop(context); // Close drawer
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
              if (result == true) {
                // Settings were changed, reload user
                _loadCurrentUser();
              }
            },
          ),
          const Divider(),
          if (_isImpersonating)
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.orange),
              title: const Text(
                'Exit Impersonation',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () async {
                Navigator.pop(context); // Close drawer
                await _handleExitImpersonation(context);
              },
            ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              _handleLogout(context);
            },
          ),
          if (_currentUser.isAdmin) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'ADMINISTRATION',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                  letterSpacing: 1,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.people_outlined, color: burgundy),
              title: Text(
                'Students',
                style: TextStyle(color: burgundy, fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const StudentsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.chat_bubble_outline, color: burgundy),
              title: Row(
                children: [
                  Text(
                    'Submissions',
                    style: TextStyle(color: burgundy, fontWeight: FontWeight.w500),
                  ),
                  if (_unreadCounts != null && _unreadCounts!.total > 0) ...[
                    const SizedBox(width: 12),
                    UnreadBadge(count: _unreadCounts!.total),
                  ],
                ],
              ),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SubmissionsScreen(),
                  ),
                ).then((_) {
                  // Reload unread counts after returning
                  _loadUnreadCounts();
                });
              },
            ),
          ],
        ],
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

  Future<void> _handleExitImpersonation(BuildContext context) async {
    try {
      await _authService.exitImpersonation();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exited impersonation. Reloading app...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }

      // Reload the app
      await Future.delayed(const Duration(seconds: 1));
      if (kIsWeb) {
        html.window.location.reload();
      } else {
        // For mobile, navigate to root
        if (context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const LoginScreen(),
            ),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exiting impersonation: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
