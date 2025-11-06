# Video Submission System - Flutter Implementation Plan

**Date:** 2025-11-06
**Status:** Planning Phase
**Agent:** flutter-dev-expert

## Overview

This document provides a comprehensive implementation plan for building a video submission system with chat-based feedback in Flutter. The system allows students to submit videos for instructor review and engage in threaded conversations about their practice.

---

## Backend API Reference

Based on backend models (`backend/internal/models/submission.go`), we expect these endpoints:

### Student Endpoints
- `GET /api/v1/programs/:programId/submissions` - List my submissions for a program
- `POST /api/v1/programs/:programId/submissions` - Create new submission
- `GET /api/v1/submissions/:id` - Get submission with messages
- `POST /api/v1/submissions/:id/messages` - Add message to submission
- `PUT /api/v1/submissions/:id/read` - Mark submission messages as read

### Instructor Endpoints (Admin)
- `GET /api/v1/submissions` - List all submissions (with filters)
- `GET /api/v1/submissions/unread-count` - Get total unread count

### Expected Data Models
```dart
// Based on backend models
Submission {
  id: String
  programId: String
  userId: String
  title: String
  createdAt: DateTime
  updatedAt: DateTime
  unreadCount: int  // calculated server-side
  lastMessage: Message? // embedded

  // Metadata
  studentName: String?
  programName: String?
}

Message {
  id: String
  submissionId: String
  authorId: String
  authorName: String
  authorRole: String  // 'student' or 'admin'
  content: String
  youtubeUrl: String?  // optional YouTube video
  isRead: bool
  createdAt: DateTime
}
```

---

## Implementation Phases

### Phase 1: Models and Services
Create data models and API client integration.

### Phase 2: Reusable Widgets
Build badge, message bubble, and submission card widgets.

### Phase 3: Student Views
Update program detail screen and create chat screen.

### Phase 4: Instructor Views
Create admin submissions screen and update drawer.

### Phase 5: Integration and Polish
Wire everything together, add loading states, error handling.

---

## Phase 1: Models and Services

### 1.1 Create Models

#### File: `/Users/dsteiman/Dev/stuff/xuangong/.trees/video-submission/app/lib/models/submission.dart`

```dart
class Submission {
  final String id;
  final String programId;
  final String userId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int unreadCount;
  final Message? lastMessage;

  // Metadata (populated by server)
  final String? studentName;
  final String? programName;

  Submission({
    required this.id,
    required this.programId,
    required this.userId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.unreadCount = 0,
    this.lastMessage,
    this.studentName,
    this.programName,
  });

  factory Submission.fromJson(Map<String, dynamic> json) {
    return Submission(
      id: json['id'] as String,
      programId: json['program_id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      unreadCount: json['unread_count'] as int? ?? 0,
      lastMessage: json['last_message'] != null
          ? Message.fromJson(json['last_message'] as Map<String, dynamic>)
          : null,
      studentName: json['student_name'] as String?,
      programName: json['program_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'program_id': programId,
    };
  }
}
```

#### File: `/Users/dsteiman/Dev/stuff/xuangong/.trees/video-submission/app/lib/models/message.dart`

```dart
class Message {
  final String id;
  final String submissionId;
  final String authorId;
  final String authorName;
  final String authorRole; // 'student' or 'admin'
  final String content;
  final String? youtubeUrl;
  final bool isRead;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.submissionId,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.content,
    this.youtubeUrl,
    this.isRead = false,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      submissionId: json['submission_id'] as String,
      authorId: json['author_id'] as String,
      authorName: json['author_name'] as String,
      authorRole: json['author_role'] as String,
      content: json['content'] as String,
      youtubeUrl: json['youtube_url'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      if (youtubeUrl != null) 'youtube_url': youtubeUrl,
    };
  }

  bool get isFromStudent => authorRole == 'student';
  bool get isFromInstructor => authorRole == 'admin';
  bool get hasVideo => youtubeUrl != null && youtubeUrl!.isNotEmpty;
}
```

### 1.2 Create Service

#### File: `/Users/dsteiman/Dev/stuff/xuangong/.trees/video-submission/app/lib/services/submission_service.dart`

```dart
import '../models/submission.dart';
import '../models/message.dart';
import '../config/api_config.dart';
import 'api_client.dart';

class SubmissionService {
  final ApiClient _apiClient = ApiClient();

  // Student: List submissions for a program
  Future<List<Submission>> listProgramSubmissions(String programId) async {
    final response = await _apiClient.get(
      '${ApiConfig.apiBase}/programs/$programId/submissions',
    );
    final data = _apiClient.parseResponse(response);

    return (data['submissions'] as List<dynamic>)
        .map((json) => Submission.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  // Student: Create new submission
  Future<Submission> createSubmission({
    required String programId,
    required String title,
  }) async {
    final response = await _apiClient.post(
      '${ApiConfig.apiBase}/programs/$programId/submissions',
      {'title': title},
    );
    final data = _apiClient.parseResponse(response);
    return Submission.fromJson(data as Map<String, dynamic>);
  }

  // Get submission with all messages
  Future<SubmissionWithMessages> getSubmission(String submissionId) async {
    final response = await _apiClient.get(
      '${ApiConfig.apiBase}/submissions/$submissionId',
    );
    final data = _apiClient.parseResponse(response);

    return SubmissionWithMessages(
      submission: Submission.fromJson(data['submission'] as Map<String, dynamic>),
      messages: (data['messages'] as List<dynamic>)
          .map((json) => Message.fromJson(json as Map<String, dynamic>))
          .toList(),
    );
  }

  // Add message to submission
  Future<Message> addMessage({
    required String submissionId,
    required String content,
    String? youtubeUrl,
  }) async {
    final response = await _apiClient.post(
      '${ApiConfig.apiBase}/submissions/$submissionId/messages',
      {
        'content': content,
        if (youtubeUrl != null) 'youtube_url': youtubeUrl,
      },
    );
    final data = _apiClient.parseResponse(response);
    return Message.fromJson(data as Map<String, dynamic>);
  }

  // Mark messages as read
  Future<void> markAsRead(String submissionId) async {
    await _apiClient.put(
      '${ApiConfig.apiBase}/submissions/$submissionId/read',
      {},
    );
  }

  // Admin: List all submissions
  Future<List<Submission>> listAllSubmissions({
    String? status,
    int? limit,
  }) async {
    final queryParams = <String>[];
    if (status != null) queryParams.add('status=$status');
    if (limit != null) queryParams.add('limit=$limit');

    final query = queryParams.isEmpty ? '' : '?${queryParams.join('&')}';

    final response = await _apiClient.get(
      '${ApiConfig.apiBase}/submissions$query',
    );
    final data = _apiClient.parseResponse(response);

    return (data['submissions'] as List<dynamic>)
        .map((json) => Submission.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  // Admin: Get unread count
  Future<int> getUnreadCount() async {
    final response = await _apiClient.get(
      '${ApiConfig.apiBase}/submissions/unread-count',
    );
    final data = _apiClient.parseResponse(response);
    return data['count'] as int? ?? 0;
  }
}

// Helper class for submission with messages
class SubmissionWithMessages {
  final Submission submission;
  final List<Message> messages;

  SubmissionWithMessages({
    required this.submission,
    required this.messages,
  });
}
```

---

## Phase 2: Reusable Widgets

### 2.1 Badge Widget

#### File: `/Users/dsteiman/Dev/stuff/xuangong/.trees/video-submission/app/lib/widgets/unread_badge.dart`

```dart
import 'package:flutter/material.dart';

/// Circular badge showing unread count
class UnreadBadge extends StatelessWidget {
  final int count;
  final Color? color;

  const UnreadBadge({
    Key? key,
    required this.count,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    const burgundy = Color(0xFF9B1C1C);
    final badgeColor = color ?? burgundy;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor,
        shape: count > 9 ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: count > 9 ? BorderRadius.circular(10) : null,
      ),
      constraints: const BoxConstraints(
        minWidth: 20,
        minHeight: 20,
      ),
      child: Center(
        child: Text(
          count > 99 ? '99+' : count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
```

### 2.2 Message Bubble Widget

#### File: `/Users/dsteiman/Dev/stuff/xuangong/.trees/video-submission/app/lib/widgets/message_bubble.dart`

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/message.dart';
import 'youtube_player_widget.dart';

/// Chat-style message bubble for submission conversations
class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isCurrentUser;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isCurrentUser,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const burgundy = Color(0xFF9B1C1C);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCurrentUser) _buildAvatar(burgundy),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: isCurrentUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                // Author name and timestamp
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 12, right: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.authorName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('MMM dd, h:mm a').format(message.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Message bubble
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isCurrentUser
                        ? burgundy
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isCurrentUser ? 16 : 4),
                      bottomRight: Radius.circular(isCurrentUser ? 4 : 16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Text content
                      Text(
                        message.content,
                        style: TextStyle(
                          fontSize: 15,
                          color: isCurrentUser
                              ? Colors.white
                              : Colors.grey.shade900,
                          height: 1.4,
                        ),
                      ),

                      // YouTube video if present
                      if (message.hasVideo) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: YouTubePlayerWidget(
                            youtubeUrl: message.youtubeUrl!,
                            autoPlay: false,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isCurrentUser) _buildAvatar(burgundy),
        ],
      ),
    );
  }

  Widget _buildAvatar(Color burgundy) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: message.isFromInstructor
            ? burgundy.withValues(alpha: 0.1)
            : Colors.grey.shade200,
        shape: BoxShape.circle,
      ),
      child: Icon(
        message.isFromInstructor
            ? Icons.school
            : Icons.person,
        size: 18,
        color: message.isFromInstructor
            ? burgundy
            : Colors.grey.shade600,
      ),
    );
  }
}
```

### 2.3 Submission Card Widget

#### File: `/Users/dsteiman/Dev/stuff/xuangong/.trees/video-submission/app/lib/widgets/submission_card.dart`

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/submission.dart';
import 'unread_badge.dart';

/// Card displaying a submission in a list
class SubmissionCard extends StatelessWidget {
  final Submission submission;
  final VoidCallback onTap;
  final bool showProgramInfo; // For admin view

  const SubmissionCard({
    Key? key,
    required this.submission,
    required this.onTap,
    this.showProgramInfo = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: burgundy.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.videocam,
                    color: burgundy,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title with badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              submission.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (submission.unreadCount > 0) ...[
                            const SizedBox(width: 8),
                            UnreadBadge(count: submission.unreadCount),
                          ],
                        ],
                      ),

                      // Student/Program info (for admin)
                      if (showProgramInfo) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${submission.studentName} • ${submission.programName}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      // Last message preview
                      if (submission.lastMessage != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          submission.lastMessage!.content,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      // Timestamp
                      const SizedBox(height: 6),
                      Text(
                        DateFormat('MMM dd, yyyy • h:mm a')
                            .format(submission.updatedAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Chevron
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

---

## Phase 3: Student Views

### 3.1 Update Program Detail Screen - Submissions Tab

#### File: `/Users/dsteiman/Dev/stuff/xuangong/.trees/video-submission/app/lib/screens/program_detail_screen.dart`

**Modifications:**

1. **Add imports (top of file):**
```dart
import '../models/submission.dart';
import '../services/submission_service.dart';
import '../widgets/submission_card.dart';
import '../widgets/unread_badge.dart';
import 'submission_chat_screen.dart';
```

2. **Add state variables (in `_ProgramDetailScreenState` class, around line 33):**
```dart
final SubmissionService _submissionService = SubmissionService();
List<Submission> _submissions = [];
bool _isLoadingSubmissions = false;
int _totalUnreadSubmissions = 0;
```

3. **Add listener to tab controller (in `initState`, around line 49):**
```dart
void _onTabChanged() {
  if (_tabController.index == 1) { // Sessions tab
    _loadSessions();
  } else if (_tabController.index == 2) { // Submissions tab
    _loadSubmissions();
  }
}
```

4. **Add submission loading method (after `_loadSessions`, around line 85):**
```dart
Future<void> _loadSubmissions() async {
  if (_isLoadingSubmissions || widget.program.isTemplate) return;

  setState(() => _isLoadingSubmissions = true);

  try {
    final submissions = await _submissionService.listProgramSubmissions(
      widget.program.id,
    );
    setState(() {
      _submissions = submissions;
      _totalUnreadSubmissions = submissions.fold(
        0,
        (sum, sub) => sum + sub.unreadCount,
      );
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
```

5. **Update tab bar to show badge (around line 150):**
```dart
Tab(
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text('Submissions'),
      if (_totalUnreadSubmissions > 0) ...[
        const SizedBox(width: 8),
        UnreadBadge(count: _totalUnreadSubmissions),
      ],
    ],
  ),
),
```

6. **Replace `_buildSubmissionsTab` method (around line 544):**
```dart
Widget _buildSubmissionsTab() {
  const burgundy = Color(0xFF9B1C1C);

  return Column(
    children: [
      // New Submission Button
      Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              final result = await _showNewSubmissionDialog();
              if (result == true) {
                _loadSubmissions();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Start New Submission'),
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

      // Submissions List
      Expanded(
        child: _isLoadingSubmissions
            ? const Center(child: CircularProgressIndicator())
            : _submissions.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.videocam_off,
                            size: 64,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
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
                            'Start a new submission to get feedback from your instructor',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
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
                      return SubmissionCard(
                        submission: submission,
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SubmissionChatScreen(
                                submissionId: submission.id,
                              ),
                            ),
                          );
                          if (result == true) {
                            _loadSubmissions();
                          }
                        },
                      );
                    },
                  ),
      ),
    ],
  );
}

// Dialog to create new submission
Future<bool?> _showNewSubmissionDialog() async {
  final titleController = TextEditingController();
  const burgundy = Color(0xFF9B1C1C);

  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('New Submission'),
      content: TextField(
        controller: titleController,
        decoration: const InputDecoration(
          labelText: 'Title',
          hintText: 'e.g., "Week 1 - Cloud Hands"',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (titleController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter a title'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            try {
              await _submissionService.createSubmission(
                programId: widget.program.id,
                title: titleController.text.trim(),
              );
              if (context.mounted) {
                Navigator.pop(context, true);
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to create submission: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: burgundy,
            foregroundColor: Colors.white,
          ),
          child: const Text('Create'),
        ),
      ],
    ),
  );
}
```

### 3.2 Create Submission Chat Screen

#### File: `/Users/dsteiman/Dev/stuff/xuangong/.trees/video-submission/app/lib/screens/submission_chat_screen.dart`

```dart
import 'package:flutter/material.dart';
import '../models/submission.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../services/submission_service.dart';
import '../services/storage_service.dart';
import '../widgets/message_bubble.dart';

class SubmissionChatScreen extends StatefulWidget {
  final String submissionId;

  const SubmissionChatScreen({
    Key? key,
    required this.submissionId,
  }) : super(key: key);

  @override
  State<SubmissionChatScreen> createState() => _SubmissionChatScreenState();
}

class _SubmissionChatScreenState extends State<SubmissionChatScreen> {
  final SubmissionService _submissionService = SubmissionService();
  final StorageService _storageService = StorageService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Submission? _submission;
  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final userId = await _storageService.getUserId();
      final data = await _submissionService.getSubmission(widget.submissionId);

      // Mark as read
      await _submissionService.markAsRead(widget.submissionId);

      setState(() {
        _submission = data.submission;
        _messages = data.messages;
        _currentUserId = userId;
        _isLoading = false;
      });

      // Scroll to bottom after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load submission: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final message = await _submissionService.addMessage(
        submissionId: widget.submissionId,
        content: content,
      );

      setState(() {
        _messages.add(message);
        _messageController.clear();
        _isSending = false;
      });

      _scrollToBottom();
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addYouTubeVideo() async {
    final urlController = TextEditingController();
    const burgundy = Color(0xFF9B1C1C);

    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add YouTube Video'),
        content: TextField(
          controller: urlController,
          decoration: const InputDecoration(
            labelText: 'YouTube URL',
            hintText: 'https://youtube.com/watch?v=...',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, urlController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: burgundy,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (url == null || url.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final message = await _submissionService.addMessage(
        submissionId: widget.submissionId,
        content: 'Shared a video',
        youtubeUrl: url,
      );

      setState(() {
        _messages.add(message);
        _isSending = false;
      });

      _scrollToBottom();
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add video: $e'),
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
        backgroundColor: burgundy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _submission?.title ?? 'Loading...',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Messages list
                Expanded(
                  child: _messages.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              'No messages yet. Start the conversation!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final isCurrentUser =
                                message.authorId == _currentUserId;
                            return MessageBubble(
                              message: message,
                              isCurrentUser: isCurrentUser,
                            );
                          },
                        ),
                ),

                // Input area
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        // YouTube button
                        IconButton(
                          icon: const Icon(Icons.videocam),
                          color: burgundy,
                          onPressed: _isSending ? null : _addYouTubeVideo,
                        ),
                        const SizedBox(width: 8),

                        // Text field
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                            ),
                            maxLines: null,
                            textCapitalization: TextCapitalization.sentences,
                            enabled: !_isSending,
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Send button
                        Container(
                          decoration: BoxDecoration(
                            color: burgundy,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: _isSending
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.send),
                            color: Colors.white,
                            onPressed: _isSending ? null : _sendMessage,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
```

---

## Phase 4: Instructor Views

### 4.1 Create Admin Submissions Screen

#### File: `/Users/dsteiman/Dev/stuff/xuangong/.trees/video-submission/app/lib/screens/submissions_screen.dart`

```dart
import 'package:flutter/material.dart';
import '../models/submission.dart';
import '../services/submission_service.dart';
import '../widgets/submission_card.dart';
import 'submission_chat_screen.dart';

class SubmissionsScreen extends StatefulWidget {
  const SubmissionsScreen({Key? key}) : super(key: key);

  @override
  State<SubmissionsScreen> createState() => _SubmissionsScreenState();
}

class _SubmissionsScreenState extends State<SubmissionsScreen> {
  final SubmissionService _submissionService = SubmissionService();

  List<Submission> _submissions = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final submissions = await _submissionService.listAllSubmissions();
      setState(() {
        _submissions = submissions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
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
        title: const Text(
          'All Submissions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load submissions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadSubmissions,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: burgundy,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _submissions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox,
                              size: 64,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
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
                              'Student submissions will appear here',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadSubmissions,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _submissions.length,
                        itemBuilder: (context, index) {
                          final submission = _submissions[index];
                          return SubmissionCard(
                            submission: submission,
                            showProgramInfo: true, // Show student/program names
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SubmissionChatScreen(
                                    submissionId: submission.id,
                                  ),
                                ),
                              );
                              if (result == true) {
                                _loadSubmissions();
                              }
                            },
                          );
                        },
                      ),
                    ),
    );
  }
}
```

### 4.2 Update Home Screen Drawer

#### File: `/Users/dsteiman/Dev/stuff/xuangong/.trees/video-submission/app/lib/screens/home_screen.dart`

**Modifications:**

1. **Add imports (top of file):**
```dart
import '../services/submission_service.dart';
import '../widgets/unread_badge.dart';
import 'submissions_screen.dart';
```

2. **Add state variable (in `_HomeScreenState` class, around line 32):**
```dart
int _unreadSubmissionsCount = 0;
```

3. **Add method to load unread count (after `_loadTemplates`, around line 92):**
```dart
Future<void> _loadUnreadCount() async {
  // Only for admins
  if (!widget.user.isAdmin) return;

  try {
    final submissionService = SubmissionService();
    final count = await submissionService.getUnreadCount();
    setState(() {
      _unreadSubmissionsCount = count;
    });
  } catch (e) {
    // Silently fail - not critical
    print('Failed to load unread count: $e');
  }
}
```

4. **Call in `_loadData` method (around line 47):**
```dart
Future<void> _loadData() async {
  _loadMyPrograms();
  _loadTemplates();
  _loadUnreadCount(); // Add this line
}
```

5. **Update drawer (in `_buildDrawer` method, after Students menu item, around line 580):**
```dart
ListTile(
  leading: Icon(Icons.videocam_outlined, color: burgundy),
  title: Row(
    children: [
      Text(
        'Submissions',
        style: TextStyle(color: burgundy, fontWeight: FontWeight.w500),
      ),
      if (_unreadSubmissionsCount > 0) ...[
        const SizedBox(width: 8),
        UnreadBadge(count: _unreadSubmissionsCount),
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
      // Refresh count when returning
      _loadUnreadCount();
    });
  },
),
```

### 4.3 Update Home Screen - Program Card Badge

**In `_buildProgramCard` method (around line 470), add unread badge:**

This requires backend support to include submission unread counts in program responses. For now, skip this or add a TODO comment.

---

## Phase 5: Integration and Polish

### 5.1 Testing Checklist

**Student Flow:**
- [ ] Can see "Submissions" tab in program detail
- [ ] Can create new submission with title
- [ ] Can open submission chat
- [ ] Can send text messages
- [ ] Can add YouTube video URLs
- [ ] YouTube videos display inline in chat
- [ ] Messages show correct author and timestamp
- [ ] Unread badge shows on submission cards
- [ ] Unread badge shows on Submissions tab
- [ ] Messages marked as read when opening chat

**Instructor Flow:**
- [ ] Can see "Submissions" menu item in drawer (admin only)
- [ ] Unread badge shows on drawer menu item
- [ ] Can see all submissions from all students
- [ ] Submissions show student and program names
- [ ] Can open any submission chat
- [ ] Can send feedback messages
- [ ] Can add YouTube video feedback
- [ ] Unread count updates after viewing

**UI/UX:**
- [ ] Chat scrolls to bottom on load
- [ ] Chat scrolls to bottom after sending
- [ ] Message bubbles align correctly (left/right)
- [ ] Loading states show properly
- [ ] Error messages are helpful
- [ ] Burgundy color scheme consistent
- [ ] Follows existing design patterns

### 5.2 Error Handling

All API calls should handle:
- Network errors
- Authentication errors (401)
- Not found errors (404)
- Server errors (500)
- Display user-friendly error messages
- Provide retry options where appropriate

### 5.3 Loading States

Show loading indicators for:
- Initial data load
- Sending messages
- Creating submissions
- Loading unread counts

### 5.4 Navigation Flow

```
HomeScreen
  └─> ProgramDetailScreen (Submissions tab)
       └─> SubmissionChatScreen

HomeScreen (drawer)
  └─> SubmissionsScreen (admin only)
       └─> SubmissionChatScreen
```

---

## File Summary

### New Files to Create (15 files)

**Models:**
1. `/app/lib/models/submission.dart`
2. `/app/lib/models/message.dart`

**Services:**
3. `/app/lib/services/submission_service.dart`

**Widgets:**
4. `/app/lib/widgets/unread_badge.dart`
5. `/app/lib/widgets/message_bubble.dart`
6. `/app/lib/widgets/submission_card.dart`

**Screens:**
7. `/app/lib/screens/submission_chat_screen.dart`
8. `/app/lib/screens/submissions_screen.dart`

### Files to Modify (2 files)

1. `/app/lib/screens/program_detail_screen.dart`
   - Add imports
   - Add state variables
   - Update tab listener
   - Add `_loadSubmissions()` method
   - Update tab bar with badge
   - Replace `_buildSubmissionsTab()` method
   - Add `_showNewSubmissionDialog()` method

2. `/app/lib/screens/home_screen.dart`
   - Add imports
   - Add state variable for unread count
   - Add `_loadUnreadCount()` method
   - Update `_loadData()` to call unread count
   - Add Submissions menu item to drawer with badge

---

## Design Patterns Used

1. **State Management:** StatefulWidget with setState (consistent with existing code)
2. **Service Layer:** Dedicated service for API calls (`SubmissionService`)
3. **Reusable Widgets:** Badge, message bubble, submission card
4. **Navigation:** Push/pop with result handling
5. **Loading States:** Boolean flags with CircularProgressIndicator
6. **Error Handling:** Try-catch with SnackBar feedback
7. **Color Consistency:** Burgundy (#9B1C1C) throughout
8. **Material Design:** Following existing patterns (cards, shadows, borders)

---

## Dependencies

**Already installed:**
- `http` - API requests
- `intl` - Date formatting
- `youtube_player_iframe` - YouTube playback

**No new dependencies needed!**

---

## Backend Requirements

The backend must implement these endpoints (see backend documentation):

1. `GET /api/v1/programs/:programId/submissions`
2. `POST /api/v1/programs/:programId/submissions`
3. `GET /api/v1/submissions/:id`
4. `POST /api/v1/submissions/:id/messages`
5. `PUT /api/v1/submissions/:id/read`
6. `GET /api/v1/submissions` (admin)
7. `GET /api/v1/submissions/unread-count` (admin)

---

## Implementation Order

**Day 1: Foundation**
- Phase 1: Models and Services
- Phase 2: Reusable Widgets

**Day 2: Student Features**
- Phase 3: Update program detail, create chat screen
- Test student flow

**Day 3: Instructor Features**
- Phase 4: Create submissions screen, update drawer
- Test instructor flow

**Day 4: Polish**
- Phase 5: Integration testing, bug fixes, polish

---

## Notes

- **Offline Support:** Not included in MVP (can be added later)
- **Real-time Updates:** Not included (would require WebSocket/polling)
- **Push Notifications:** Not included (can be added later)
- **Video Recording:** Not included (using YouTube URLs only)
- **File Uploads:** Not included (YouTube-only for now)
- **Message Editing/Deletion:** Not included in MVP
- **Search/Filter:** Not included in MVP

---

## Success Criteria

- Students can create submissions and chat with instructors
- Instructors can see all submissions and provide feedback
- Unread badges work correctly
- YouTube videos display inline in chat
- UI follows existing design patterns
- No crashes or data loss
- Error messages are helpful
- Loading states provide feedback

---

**End of Implementation Plan**