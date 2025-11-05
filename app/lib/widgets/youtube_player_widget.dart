import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../utils/youtube_url_helper.dart';

/// A reusable YouTube player widget with proper lifecycle management
class YouTubePlayerWidget extends StatefulWidget {
  final String youtubeUrl;
  final bool autoPlay;
  final bool mute;

  const YouTubePlayerWidget({
    super.key,
    required this.youtubeUrl,
    this.autoPlay = false,
    this.mute = false,
  });

  @override
  State<YouTubePlayerWidget> createState() => _YouTubePlayerWidgetState();
}

class _YouTubePlayerWidgetState extends State<YouTubePlayerWidget> {
  YoutubePlayerController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  void _initializePlayer() {
    // Extract video ID from URL
    final videoId = YouTubeUrlHelper.extractVideoId(widget.youtubeUrl);

    if (videoId == null) {
      setState(() {
        _error = 'Invalid YouTube URL';
      });
      return;
    }

    try {
      _controller = YoutubePlayerController.fromVideoId(
        videoId: videoId,
        autoPlay: widget.autoPlay,
        params: YoutubePlayerParams(
          mute: widget.mute,
          showControls: true,
          showFullscreenButton: true,
          loop: false,
          enableCaption: true,
          strictRelatedVideos: true,
        ),
      );
    } catch (e) {
      setState(() {
        _error = 'Failed to load video: ${e.toString()}';
      });
    }
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show error message if initialization failed
    if (_error != null) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red[300],
              size: 48,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Show loading indicator while controller initializes
    if (_controller == null) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const CircularProgressIndicator(
          color: Color(0xFF9B1C1C),
        ),
      );
    }

    // Show the YouTube player
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: YoutubePlayer(
        controller: _controller!,
        aspectRatio: 16 / 9,
      ),
    );
  }
}

/// A compact YouTube player widget that can be expanded/collapsed
class ExpandableYouTubePlayer extends StatefulWidget {
  final String youtubeUrl;

  const ExpandableYouTubePlayer({
    super.key,
    required this.youtubeUrl,
  });

  @override
  State<ExpandableYouTubePlayer> createState() =>
      _ExpandableYouTubePlayerState();
}

class _ExpandableYouTubePlayerState extends State<ExpandableYouTubePlayer>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _heightAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _heightAnimation = Tween<double>(begin: 0.0, end: 220.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Toggle button
        InkWell(
          onTap: _toggleExpanded,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isExpanded ? Icons.videocam_off : Icons.videocam,
                  size: 20,
                  color: const Color(0xFF9B1C1C),
                ),
                const SizedBox(width: 8),
                Text(
                  _isExpanded ? 'Hide Video' : 'Watch Demo',
                  style: const TextStyle(
                    color: Color(0xFF9B1C1C),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Animated player
        AnimatedBuilder(
          animation: _heightAnimation,
          builder: (context, child) {
            return SizedBox(
              height: _heightAnimation.value,
              child: _heightAnimation.value > 0
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: child,
                    )
                  : null,
            );
          },
          child: _isExpanded
              ? YouTubePlayerWidget(
                  youtubeUrl: widget.youtubeUrl,
                  autoPlay: false,
                )
              : null,
        ),
      ],
    );
  }
}
