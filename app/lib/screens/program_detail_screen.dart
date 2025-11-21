import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/program.dart';
import '../models/exercise.dart';
import '../models/user.dart';
import '../models/session.dart';
import '../models/submission.dart';
import '../services/program_service.dart';
import '../services/session_service.dart';
import '../services/submission_service.dart';
import '../widgets/xg_button.dart';
import '../widgets/youtube_player_widget.dart';
import '../widgets/submission_card.dart';
import 'practice_screen.dart';
import 'program_edit_screen.dart';
import 'session_edit_screen.dart';
import 'session_detail_screen.dart';
import 'submission_chat_screen.dart';

class ProgramDetailScreen extends StatefulWidget {
  final Program program;
  final User? user; // Optional - if provided, shows edit button

  const ProgramDetailScreen({
    Key? key,
    required this.program,
    this.user,
  }) : super(key: key);

  @override
  State<ProgramDetailScreen> createState() => _ProgramDetailScreenState();
}

class _ProgramDetailScreenState extends State<ProgramDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SessionService _sessionService = SessionService();
  final SubmissionService _submissionService = SubmissionService();

  List<SessionWithLogs> _sessions = [];
  bool _isLoadingSessions = false;
  List<SubmissionListItem> _submissions = [];
  bool _isLoadingSubmissions = false;
  int _submissionsUnreadCount = 0; // Unread count for this program
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _hasChanges = false; // Track if sessions were modified

  @override
  void initState() {
    super.initState();
    // Determine if we should show tabs:
    // - Templates only show Overview
    // - Admins always see all 3 tabs (to view student progress)
    // - Students see all 3 tabs for their programs
    final bool showAllTabs = !widget.program.isTemplate || _isAdmin();
    final tabCount = showAllTabs ? 3 : 1;
    _tabController = TabController(length: tabCount, vsync: this);

    if (showAllTabs) {
      _tabController.addListener(_onTabChanged);
      _loadSessions();
      _loadSubmissions(); // Load submissions immediately to show badge in tab
    }
  }

  bool _isAdmin() {
    return widget.user?.role == 'admin';
  }

  bool _isCurrentUserProgram() {
    if (widget.user == null) return false;
    if (widget.program.ownedBy == null) return false;
    return widget.program.ownedBy == widget.user!.id;
  }

  void _onTabChanged() {
    if (_tabController.index == 1) { // Sessions tab
      _loadSessions();
    } else if (_tabController.index == 2) { // Submissions tab
      _loadSubmissions();
    }
  }

  Future<void> _loadSessions() async {
    if (_isLoadingSessions || widget.program.isTemplate) return;

    setState(() => _isLoadingSessions = true);

    try {
      List<SessionWithLogs> sessions;

      // If admin viewing a student's program, use getUserSessions
      if (_isAdmin() && widget.program.ownedBy != null) {
        sessions = await _sessionService.getUserSessions(
          widget.program.ownedBy!,
          programId: widget.program.id,
          limit: 100,
        );
      } else {
        // Student viewing their own program or admin viewing unassigned program
        sessions = await _sessionService.listSessions(
          programId: widget.program.id,
          limit: 100,
        );
      }

      setState(() {
        _sessions = sessions;
        _isLoadingSessions = false;
      });
    } catch (e) {
      setState(() => _isLoadingSessions = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load sessions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadSubmissions() async {
    if (_isLoadingSubmissions || widget.program.isTemplate) return;

    setState(() => _isLoadingSubmissions = true);

    try {
      final submissions = await _submissionService.listSubmissions(
        programId: widget.program.id,
        limit: 100,
      );

      // Load unread count for this program
      final unreadCounts = await _submissionService.getUnreadCount(
        programId: widget.program.id,
      );

      setState(() {
        _submissions = submissions;
        _submissionsUnreadCount = unreadCounts.total;
        _isLoadingSubmissions = false;
      });
    } catch (e) {
      setState(() => _isLoadingSubmissions = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load submissions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const burgundy = Color(0xFF9B1C1C);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: burgundy,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _hasChanges),
        ),
        title: Text(
          widget.program.name,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          // Edit and Delete buttons side by side (only if user can edit)
          if (widget.user != null && _canEdit()) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ProgramEditScreen(
                      user: widget.user!,
                      program: widget.program,
                    ),
                  ),
                );

                // If changes were saved, pop back to refresh the list
                if (result == true && context.mounted) {
                  Navigator.of(context).pop(true);
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteProgram(context),
            ),
          ],
        ],
        bottom: (!widget.program.isTemplate || _isAdmin())
            ? TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
                tabs: [
                  const Tab(text: 'Overview'),
                  const Tab(text: 'Sessions'),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Submissions'),
                        if (_submissionsUnreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$_submissionsUnreadCount',
                              style: const TextStyle(
                                color: Color(0xFF9B1C1C),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              )
            : null,
      ),
      body: Column(
        children: [
          // Tab content
          Expanded(
            child: (!widget.program.isTemplate || _isAdmin())
                ? TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(),
                      _buildSessionsTab(),
                      _buildSubmissionsTab(),
                    ],
                  )
                : _buildOverviewTab(),
          ),

          // Fixed bottom action button - show for current user's programs (admin or student)
          if (!widget.program.isTemplate && _isCurrentUserProgram())
            Padding(
              padding: const EdgeInsets.all(20),
              child: SafeArea(
                top: false,
                child: XGButton(
                  text: 'Start Practice',
                  onPressed: () async {
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            PracticeScreen(program: widget.program, user: widget.user!),
                      ),
                    );

                    // If session was saved, pop back to home to trigger widget refresh
                    if (result == true && context.mounted) {
                      setState(() => _hasChanges = true);
                      Navigator.of(context).pop(true);
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    const burgundy = Color(0xFF9B1C1C);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Program info card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.program.description.isNotEmpty) ...[
                  Text(
                    widget.program.description,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    _buildInfoChip(
                      Icons.fitness_center,
                      '${widget.program.exercises.length} exercises',
                      burgundy,
                    ),
                    const SizedBox(width: 12),
                    _buildInfoChip(
                      Icons.schedule,
                      '${widget.program.totalDurationMinutes} min',
                      burgundy,
                    ),
                  ],
                ),
                // Show repetitions for assigned programs
                if (widget.program.repetitionsPlanned != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildInfoChip(
                        Icons.repeat,
                        'Progress: ${widget.program.repetitionsCompleted ?? 0}/${widget.program.repetitionsPlanned}',
                        burgundy,
                      ),
                    ],
                  ),
                ],
                if (widget.program.tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.program.tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: burgundy.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: burgundy.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 12,
                            color: burgundy,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                if (widget.program.creatorName != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    widget.program.isTemplate
                        ? 'Created by ${widget.program.creatorName}'
                        : 'Assigned to ${widget.program.creatorName}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Exercises section
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Exercises',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ...widget.program.exercises.asMap().entries.map((entry) {
                  return _buildExerciseCard(entry.value, entry.key + 1);
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsTab() {
    const burgundy = Color(0xFF9B1C1C);

    // Get sessions for the selected/focused day
    List<SessionWithLogs> _getSessionsForDay(DateTime day) {
      return _sessions.where((session) {
        final sessionDate = session.session.completedAt ?? session.session.startedAt;
        return isSameDay(sessionDate, day);
      }).toList();
    }

    final selectedDaySessions = _selectedDay != null
        ? _getSessionsForDay(_selectedDay!)
        : [];

    return Column(
      children: [
        // Admin viewing student's sessions banner
        if (_isAdmin() && widget.program.creatorName != null && widget.program.ownedBy != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: burgundy.withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: burgundy, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Viewing ${widget.program.creatorName}\'s practice sessions',
                    style: TextStyle(
                      color: burgundy,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Calendar
        Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: _getSessionsForDay,
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: burgundy.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: burgundy,
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: burgundy,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: HeaderStyle(
              titleCentered: true,
              formatButtonVisible: false,
              titleTextStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
          ),
        ),

        // Add Session Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => SessionEditScreen(
                      initialProgramId: widget.program.id,
                    ),
                  ),
                );
                if (result == true) {
                  setState(() => _hasChanges = true);
                  _loadSessions();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Log Practice Session'),
              style: OutlinedButton.styleFrom(
                foregroundColor: burgundy,
                side: const BorderSide(color: burgundy, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Sessions list for selected day
        Expanded(
          child: _isLoadingSessions
              ? const Center(child: CircularProgressIndicator())
              : _selectedDay == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'Select a date to view practice sessions',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : selectedDaySessions.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              'No sessions on ${DateFormat('MMM dd, yyyy').format(_selectedDay!)}',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: selectedDaySessions.length,
                          itemBuilder: (context, index) {
                            final sessionWithLogs = selectedDaySessions[index];
                            final session = sessionWithLogs.session;
                            final sessionDate = session.completedAt ?? session.startedAt;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: burgundy.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.check_circle,
                                    color: burgundy,
                                    size: 28,
                                  ),
                                ),
                                title: Text(
                                  DateFormat('h:mm a').format(sessionDate),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: session.notes != null
                                    ? Text(
                                        session.notes!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      )
                                    : null,
                                trailing: Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey.shade400,
                                ),
                                onTap: () async {
                                  // Admins get read-only view, students get edit view
                                  final screen = _isAdmin()
                                      ? SessionDetailScreen(sessionId: session.id)
                                      : SessionEditScreen(sessionId: session.id);

                                  final result = await Navigator.of(context).push(
                                    MaterialPageRoute(builder: (context) => screen),
                                  );

                                  if (result == true) {
                                    setState(() => _hasChanges = true);
                                    _loadSessions();
                                  }
                                },
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }

  Widget _buildSubmissionsTab() {
    const burgundy = Color(0xFF9B1C1C);

    return Column(
      children: [
        // Create submission button
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final titleController = TextEditingController();
                final youtubeController = TextEditingController();

                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('New Submission'),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: titleController,
                            decoration: const InputDecoration(
                              labelText: 'Title',
                              hintText: 'e.g., Week 1 Progress',
                              border: OutlineInputBorder(),
                            ),
                            autofocus: true,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: youtubeController,
                            decoration: const InputDecoration(
                              labelText: 'YouTube URL *',
                              hintText: 'https://youtube.com/watch?v=...',
                              border: OutlineInputBorder(),
                              helperText: 'Required: Your practice video',
                            ),
                            keyboardType: TextInputType.url,
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: burgundy,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Create'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true &&
                    titleController.text.trim().isNotEmpty &&
                    youtubeController.text.trim().isNotEmpty) {
                  try {
                    // Create the submission first
                    final submission = await _submissionService.createSubmission(
                      widget.program.id,
                      titleController.text.trim(),
                    );

                    // Immediately post the YouTube URL as the first message
                    await _submissionService.createMessage(
                      submission.id,
                      'Practice video',
                      youtubeUrl: youtubeController.text.trim(),
                    );

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Submission created with video!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      _loadSubmissions();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to create submission: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } else if (confirmed == true) {
                  // Show error if fields are missing
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please fill in all fields'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('New Submission'),
              style: ElevatedButton.styleFrom(
                backgroundColor: burgundy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),

        // Submissions list
        Expanded(
          child: _isLoadingSubmissions
              ? const Center(child: CircularProgressIndicator())
              : _submissions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 80,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'No submissions yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create a submission to get feedback from your instructor',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _submissions.length,
                      itemBuilder: (context, index) {
                        final submission = _submissions[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SubmissionCard(
                            submission: submission,
                            onTap: () async {
                              final result = await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => SubmissionChatScreen(
                                    submissionId: submission.id,
                                  ),
                                ),
                              );
                              // Reload submissions if messages were added
                              if (result == true && mounted) {
                                _loadSubmissions();
                              }
                            },
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Number badge
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: burgundy.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$number',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: burgundy,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Exercise details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (exercise.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      exercise.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
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
                  // YouTube video player
                  if (exercise.hasYoutubeVideo) ...[
                    const SizedBox(height: 12),
                    ExpandableYouTubePlayer(
                      youtubeUrl: exercise.youtubeUrl!,
                    ),
                  ],
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
          Icon(icon, size: 13, color: color),
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

  // Check if the current user can edit this program
  bool _canEdit() {
    if (widget.user == null) return false;

    // User can edit if they own the program
    if (widget.program.ownedBy != null &&
        widget.program.ownedBy == widget.user!.id) {
      return true;
    }

    // Admins can edit any non-public program
    if (!widget.user!.isStudent) {
      return true;
    }

    // Otherwise, cannot edit (especially public templates from other users)
    return false;
  }

  // Delete program with confirmation
  Future<void> _deleteProgram(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Program'),
        content: Text(
          'Are you sure you want to delete "${widget.program.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final programService = ProgramService();
      await programService.deleteProgram(widget.program.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Program deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete program: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
