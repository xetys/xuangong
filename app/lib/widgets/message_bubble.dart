import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/submission.dart';
import 'youtube_player_widget.dart';

class MessageBubble extends StatelessWidget {
  final MessageWithAuthor message;
  final String currentUserId;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.currentUserId,
  }) : super(key: key);

  bool get _isOwnMessage => message.userId == currentUserId;

  @override
  Widget build(BuildContext context) {
    // Xuan Gong burgundy color
    const burgundy = Color(0xFF9B1C1C);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment:
            _isOwnMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Author name and timestamp
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.authorName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatTimestamp(message.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
                if (message.authorRole == 'admin') ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: burgundy.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Instructor',
                      style: TextStyle(
                        fontSize: 10,
                        color: burgundy,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Message bubble
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: _isOwnMessage ? burgundy : Colors.grey[200],
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(_isOwnMessage ? 16 : 4),
                bottomRight: Radius.circular(_isOwnMessage ? 4 : 16),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Message content
                Text(
                  message.content,
                  style: TextStyle(
                    fontSize: 15,
                    color: _isOwnMessage ? Colors.white : Colors.black87,
                    height: 1.4,
                  ),
                ),
                // YouTube video if present
                if (message.youtubeUrl != null && message.youtubeUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  YouTubePlayerWidget(
                    youtubeUrl: message.youtubeUrl!,
                    autoPlay: false,
                  ),
                ],
              ],
            ),
          ),
          // Unread indicator
          if (!message.isRead && !_isOwnMessage)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: burgundy,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      // Today - show time only
      return DateFormat.jm().format(timestamp);
    } else if (difference.inDays == 1) {
      // Yesterday
      return 'Yesterday ${DateFormat.jm().format(timestamp)}';
    } else if (difference.inDays < 7) {
      // This week - show day and time
      return '${DateFormat.E().format(timestamp)} ${DateFormat.jm().format(timestamp)}';
    } else {
      // Older - show date and time
      return DateFormat('MMM d, y').format(timestamp);
    }
  }
}
