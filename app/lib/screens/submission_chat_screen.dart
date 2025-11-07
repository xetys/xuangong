import 'package:flutter/material.dart';
import '../models/submission.dart';
import '../models/user.dart';
import '../services/submission_service.dart';
import '../services/auth_service.dart';
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
  final AuthService _authService = AuthService();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _youtubeController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Submission? _submission;
  List<MessageWithAuthor> _messages = [];
  User? _currentUser;
  bool _isLoading = true;
  bool _isSending = false;
  bool _showYoutubeField = false;
  bool _messagesSent = false; // Track if any messages were sent

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _youtubeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final submission = await _submissionService.getSubmission(widget.submissionId);
      final messages = await _submissionService.getMessages(widget.submissionId);
      final user = await _authService.getCurrentUser();

      setState(() {
        _submission = submission;
        _messages = messages;
        _currentUser = user;
        _isLoading = false;
      });

      // Mark unread messages as read
      _markMessagesAsRead();

      // Scroll to bottom after loading
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
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

  Future<void> _markMessagesAsRead() async {
    if (_currentUser == null) return;

    for (final message in _messages) {
      if (!message.isRead && message.userId != _currentUser!.id) {
        try {
          await _submissionService.markMessageAsRead(message.id);
        } catch (e) {
          // Silently fail for read status updates
          print('Failed to mark message as read: $e');
        }
      }
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final youtubeUrl = _youtubeController.text.trim();
    final hasYoutube = youtubeUrl.isNotEmpty;

    setState(() => _isSending = true);

    try {
      await _submissionService.createMessage(
        widget.submissionId,
        content,
        youtubeUrl: hasYoutube ? youtubeUrl : null,
      );

      _messageController.clear();
      _youtubeController.clear();
      setState(() {
        _showYoutubeField = false;
        _isSending = false;
        _messagesSent = true; // Mark that messages were sent
      });

      // Reload messages
      await _loadData();
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

  @override
  Widget build(BuildContext context) {
    const burgundy = Color(0xFF9B1C1C);

    return WillPopScope(
      onWillPop: () async {
        // Return the result when navigating back
        Navigator.of(context).pop(_messagesSent);
        return false; // We handle the pop ourselves
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: burgundy,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(_messagesSent),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _submission?.title ?? 'Submission',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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
                            padding: const EdgeInsets.all(40),
                            child: Text(
                              'No messages yet.\nStart the conversation!',
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
                            return MessageBubble(
                              message: message,
                              currentUserId: _currentUser?.id ?? '',
                            );
                          },
                        ),
                ),

                // Input area
                Container(
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
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // YouTube URL field (optional)
                          if (_showYoutubeField) ...[
                            TextField(
                              controller: _youtubeController,
                              decoration: InputDecoration(
                                labelText: 'YouTube URL',
                                hintText: 'https://youtube.com/watch?v=...',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    _youtubeController.clear();
                                    setState(() => _showYoutubeField = false);
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Message input row
                          Row(
                            children: [
                              // YouTube button
                              IconButton(
                                icon: Icon(
                                  _showYoutubeField ? Icons.videocam : Icons.videocam_outlined,
                                  color: _showYoutubeField ? burgundy : Colors.grey.shade600,
                                ),
                                onPressed: () {
                                  setState(() => _showYoutubeField = !_showYoutubeField);
                                },
                              ),
                              const SizedBox(width: 8),

                              // Message text field
                              Expanded(
                                child: TextField(
                                  controller: _messageController,
                                  decoration: const InputDecoration(
                                    hintText: 'Type your message...',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                  maxLines: null,
                                  textCapitalization: TextCapitalization.sentences,
                                  onSubmitted: (_) => _sendMessage(),
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
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Icon(Icons.send, color: Colors.white),
                                  onPressed: _isSending ? null : _sendMessage,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
      ),
    );
  }
}
