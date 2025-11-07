class Submission {
  final String id;
  final String programId;
  final String userId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  Submission({
    required this.id,
    required this.programId,
    required this.userId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory Submission.fromJson(Map<String, dynamic> json) {
    return Submission(
      id: json['id'],
      programId: json['program_id'],
      userId: json['user_id'],
      title: json['title'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'program_id': programId,
      'user_id': userId,
      'title': title,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }
}

class SubmissionMessage {
  final String id;
  final String submissionId;
  final String userId;
  final String content;
  final String? youtubeUrl;
  final DateTime createdAt;

  SubmissionMessage({
    required this.id,
    required this.submissionId,
    required this.userId,
    required this.content,
    this.youtubeUrl,
    required this.createdAt,
  });

  factory SubmissionMessage.fromJson(Map<String, dynamic> json) {
    return SubmissionMessage(
      id: json['id'],
      submissionId: json['submission_id'],
      userId: json['user_id'],
      content: json['content'],
      youtubeUrl: json['youtube_url'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'submission_id': submissionId,
      'user_id': userId,
      'content': content,
      'youtube_url': youtubeUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class MessageWithAuthor {
  final String id;
  final String submissionId;
  final String userId;
  final String content;
  final String? youtubeUrl;
  final DateTime createdAt;
  final String authorName;
  final String authorEmail;
  final String authorRole;
  final bool isRead;

  MessageWithAuthor({
    required this.id,
    required this.submissionId,
    required this.userId,
    required this.content,
    this.youtubeUrl,
    required this.createdAt,
    required this.authorName,
    required this.authorEmail,
    required this.authorRole,
    required this.isRead,
  });

  factory MessageWithAuthor.fromJson(Map<String, dynamic> json) {
    return MessageWithAuthor(
      id: json['id'],
      submissionId: json['submission_id'],
      userId: json['user_id'],
      content: json['content'],
      youtubeUrl: json['youtube_url'],
      createdAt: DateTime.parse(json['created_at']),
      authorName: json['author_name'],
      authorEmail: json['author_email'],
      authorRole: json['author_role'],
      isRead: json['is_read'] ?? false,
    );
  }
}

class SubmissionListItem {
  final String id;
  final String programId;
  final String userId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String programName;
  final String studentName;
  final String studentEmail;
  final int messageCount;
  final int unreadCount;
  final DateTime lastMessageAt;
  final String lastMessageText;
  final String lastMessageFrom;

  SubmissionListItem({
    required this.id,
    required this.programId,
    required this.userId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.programName,
    required this.studentName,
    required this.studentEmail,
    required this.messageCount,
    required this.unreadCount,
    required this.lastMessageAt,
    required this.lastMessageText,
    required this.lastMessageFrom,
  });

  factory SubmissionListItem.fromJson(Map<String, dynamic> json) {
    return SubmissionListItem(
      id: json['id'],
      programId: json['program_id'],
      userId: json['user_id'],
      title: json['title'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      programName: json['program_name'] ?? '',
      studentName: json['student_name'] ?? '',
      studentEmail: json['student_email'] ?? '',
      messageCount: json['message_count'] ?? 0,
      unreadCount: json['unread_count'] ?? 0,
      lastMessageAt: DateTime.parse(json['last_message_at']),
      lastMessageText: json['last_message_text'] ?? '',
      lastMessageFrom: json['last_message_from'] ?? '',
    );
  }
}

class UnreadCounts {
  final int total;
  final Map<String, int> byProgram;
  final Map<String, int> bySubmission;

  UnreadCounts({
    required this.total,
    required this.byProgram,
    required this.bySubmission,
  });

  factory UnreadCounts.fromJson(Map<String, dynamic> json) {
    return UnreadCounts(
      total: json['total'] ?? 0,
      byProgram: Map<String, int>.from(json['by_program'] ?? {}),
      bySubmission: Map<String, int>.from(json['by_submission'] ?? {}),
    );
  }
}
