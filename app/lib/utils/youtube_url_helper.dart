/// Helper utilities for working with YouTube URLs
class YouTubeUrlHelper {
  /// Extracts the video ID from various YouTube URL formats
  ///
  /// Supported formats:
  /// - https://www.youtube.com/watch?v=VIDEO_ID
  /// - https://youtube.com/watch?v=VIDEO_ID
  /// - https://youtu.be/VIDEO_ID
  /// - https://www.youtube.com/embed/VIDEO_ID
  /// - https://www.youtube.com/v/VIDEO_ID
  /// - https://m.youtube.com/watch?v=VIDEO_ID
  ///
  /// Returns null if the URL is invalid or doesn't contain a video ID
  static String? extractVideoId(String? url) {
    if (url == null || url.trim().isEmpty) {
      return null;
    }

    url = url.trim();

    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase().replaceAll('www.', '');

      // youtu.be/VIDEO_ID
      if (host == 'youtu.be') {
        final path = uri.path.replaceFirst('/', '');
        if (path.isNotEmpty) {
          // Remove any query parameters
          return path.split('?').first;
        }
      }

      // youtube.com or m.youtube.com
      if (host == 'youtube.com' || host == 'm.youtube.com') {
        // Check path-based formats first
        // /embed/VIDEO_ID
        if (uri.path.startsWith('/embed/')) {
          final videoId = uri.path.replaceFirst('/embed/', '');
          if (videoId.isNotEmpty) {
            return videoId;
          }
        }

        // /v/VIDEO_ID
        if (uri.path.startsWith('/v/')) {
          final videoId = uri.path.replaceFirst('/v/', '');
          if (videoId.isNotEmpty) {
            return videoId;
          }
        }

        // /watch?v=VIDEO_ID
        final videoId = uri.queryParameters['v'];
        if (videoId != null && videoId.isNotEmpty) {
          return videoId;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Validates a YouTube URL and returns true if it's valid
  static bool isValidYouTubeUrl(String? url) {
    final videoId = extractVideoId(url);
    if (videoId == null) {
      return false;
    }

    // YouTube video IDs are exactly 11 characters
    // and contain alphanumeric characters, underscore, and hyphen
    final videoIdRegex = RegExp(r'^[a-zA-Z0-9_-]{11}$');
    return videoIdRegex.hasMatch(videoId);
  }

  /// Gets a user-friendly error message for an invalid YouTube URL
  static String? getValidationError(String? url) {
    if (url == null || url.trim().isEmpty) {
      return null; // Empty is valid (optional field)
    }

    if (!isValidYouTubeUrl(url)) {
      final videoId = extractVideoId(url);
      if (videoId == null) {
        return 'Please enter a valid YouTube URL\n(youtube.com/watch?v=... or youtu.be/...)';
      } else {
        return 'Invalid YouTube video ID format';
      }
    }

    return null;
  }

  /// Converts various YouTube URL formats to a standard watch URL
  static String? normalizeUrl(String? url) {
    final videoId = extractVideoId(url);
    if (videoId == null) {
      return null;
    }

    return 'https://www.youtube.com/watch?v=$videoId';
  }
}
