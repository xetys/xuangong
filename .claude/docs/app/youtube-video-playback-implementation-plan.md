# YouTube Video Playback Implementation Plan

**Created**: 2025-11-05
**Status**: Planning Phase
**Feature**: Add inline YouTube video playback to exercise cards

---

## Overview

Add YouTube video playback functionality to exercise cards, allowing instructors to attach demonstration videos to exercises and students to view them inline within the program detail screens.

### Key Requirements
- YouTube URLs stored in `Exercise.metadata['youtube_url']`
- Inline embedded player (not modal dialog)
- Icon button on exercise card (only visible when URL exists)
- Expand/collapse behavior on tap
- Proper lifecycle management (cleanup, pause on navigation)
- Support various YouTube URL formats

---

## 1. Package Dependencies

### Primary Package: `youtube_player_flutter`

**Add to `pubspec.yaml`**:
```yaml
dependencies:
  youtube_player_flutter: ^9.0.3  # Latest stable version
```

**Rationale**:
- Most mature and actively maintained YouTube player for Flutter
- Built on top of `youtube_player_iframe` (official YouTube iframe API)
- Supports all platforms (iOS, Android, Web)
- Handles URL parsing automatically
- Provides player lifecycle controls
- ~500k+ downloads, well-tested

**Alternative Considered**:
- `youtube_player_iframe` - Lower level, more complex setup
- `pod_player` - Less focused on YouTube specifically

---

## 2. Widget Architecture

### 2.1 Reusable Component Strategy

**Create**: `app/lib/widgets/youtube_player_widget.dart`

**Why Separate Widget**:
- Used in multiple screens (ProgramDetailScreen, StudentProgramDetailScreen)
- Encapsulates player lifecycle management
- Easier to test independently
- Cleaner separation of concerns
- Can be reused for other features (video submissions view, etc.)

**Widget Structure**:
```dart
class YouTubePlayerWidget extends StatefulWidget {
  final String youtubeUrl;
  final bool autoPlay;

  const YouTubePlayerWidget({
    required this.youtubeUrl,
    this.autoPlay = false,
  });
}

class _YouTubePlayerWidgetState extends State<YouTubePlayerWidget> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    // Initialize controller
    // Extract video ID from URL
    // Configure player settings
  }

  @override
  void dispose() {
    // Critical: dispose controller to prevent memory leaks
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayer(
      controller: _controller,
      // Configuration...
    );
  }
}
```

### 2.2 Expandable Exercise Card

**Modify**: Existing `_buildExerciseCard()` methods

**Approach**: Stateful wrapper for each exercise card with expand/collapse state

**Why Stateful**:
- Need to track expanded/collapsed state per card
- Player needs to pause when collapsed
- Smooth animation requires state management

**Structure**:
```dart
class _ExerciseCard extends StatefulWidget {
  final Exercise exercise;
  final int number;

  const _ExerciseCard({
    required this.exercise,
    required this.number,
  });
}

class _ExerciseCardState extends State<_ExerciseCard> {
  bool _isVideoExpanded = false;

  bool get _hasYouTubeUrl {
    final url = widget.exercise.metadata?['youtube_url'];
    return url != null && url.isNotEmpty;
  }

  void _toggleVideo() {
    setState(() {
      _isVideoExpanded = !_isVideoExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Existing card content
        Container(...),

        // Animated expandable video section
        AnimatedContainer(
          height: _isVideoExpanded ? 220 : 0,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: _isVideoExpanded
            ? YouTubePlayerWidget(
                youtubeUrl: widget.exercise.metadata!['youtube_url'],
              )
            : SizedBox.shrink(),
        ),
      ],
    );
  }
}
```

---

## 3. State Management Strategy

### 3.1 Local State (StatefulWidget)

**Recommendation**: Use StatefulWidget for player state management

**Rationale**:
- Player state is local to each exercise card
- No need for global state management
- Follows existing app pattern (no Provider/Riverpod/Bloc used)
- Simpler, more maintainable for this use case
- Performance is not a concern (few videos per screen)

**State to Track**:
- `_isVideoExpanded` - Whether video section is visible
- `_controller` - YouTube player controller (in YouTubePlayerWidget)

### 3.2 Player Lifecycle Events

**Key Events to Handle**:
1. **onReady**: Player initialized, ready to play
2. **onEnded**: Video finished playing
3. **onError**: Handle playback errors gracefully

**Auto-pause Scenarios**:
- Card collapses: `controller.pause()`
- User navigates away: Widget disposal handles cleanup
- Another video plays: Optional (could implement singleton controller)

---

## 4. URL Parsing & Validation

### 4.1 Supported YouTube URL Formats

The package handles these automatically:
- `https://www.youtube.com/watch?v=VIDEO_ID`
- `https://youtu.be/VIDEO_ID`
- `https://m.youtube.com/watch?v=VIDEO_ID`
- `https://www.youtube.com/embed/VIDEO_ID`
- `https://www.youtube.com/v/VIDEO_ID`

### 4.2 URL Validation Utility

**Create**: `app/lib/utils/youtube_url_helper.dart`

```dart
class YouTubeUrlHelper {
  static bool isValidYouTubeUrl(String? url) {
    if (url == null || url.isEmpty) return false;

    final youtubeRegex = RegExp(
      r'^(https?://)?(www\.|m\.)?(youtube\.com|youtu\.be)/.+$',
      caseSensitive: false,
    );

    return youtubeRegex.hasMatch(url);
  }

  static String? extractVideoId(String url) {
    try {
      return YoutubePlayer.convertUrlToId(url);
    } catch (e) {
      return null;
    }
  }
}
```

---

## 5. UI/UX Flow

### 5.1 Exercise Card Layout

**Current Layout**:
```
┌─────────────────────────────────────┐
│ [#] Exercise Name                   │
│     Description text                │
│     [Timer] [Sides] [Rest] tags     │
└─────────────────────────────────────┘
```

**New Layout (with video)**:
```
┌─────────────────────────────────────┐
│ [#] Exercise Name          [🎥]     │  <- Video icon button
│     Description text                │
│     [Timer] [Sides] [Rest] tags     │
├─────────────────────────────────────┤  <- Divider when expanded
│ ┌─────────────────────────────────┐ │
│ │   YouTube Video Player          │ │  <- Expandable section
│ │   (16:9 aspect ratio)           │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

### 5.2 Icon Button Design

**Position**: Top-right corner of exercise card, aligned with exercise name

**Icon**: `Icons.play_circle_outline` (when collapsed) / `Icons.expand_less` (when expanded)

**Color**: Xuan Gong burgundy (#9B1C1C)

**Behavior**:
- Only visible if `metadata['youtube_url']` exists
- Tap toggles expand/collapse
- Icon changes based on state
- Smooth animation (300ms ease-in-out)

### 5.3 Player Configuration

**Recommended Settings**:
```dart
YoutubePlayerController(
  initialVideoId: videoId,
  flags: YoutubePlayerFlags(
    autoPlay: false,              // Don't auto-play (martial arts etiquette)
    mute: false,                  // Allow sound
    disableDragSeek: false,       // Allow seeking
    loop: false,                  // Don't loop
    isLive: false,                // Not live stream
    forceHD: false,               // Auto quality selection
    enableCaption: true,          // Allow captions
    hideControls: false,          // Show YouTube controls
    controlsVisibleAtStart: true, // Show controls immediately
  ),
)
```

**Aspect Ratio**: 16:9 (YouTube standard)
**Height**: 220px (provides good viewing experience on mobile)

---

## 6. Files to Modify

### 6.1 New Files

1. **`app/lib/widgets/youtube_player_widget.dart`**
   - Reusable YouTube player component
   - Handles controller lifecycle
   - Error handling and loading states

2. **`app/lib/utils/youtube_url_helper.dart`**
   - URL validation utilities
   - Video ID extraction
   - Format conversion helpers

### 6.2 Modified Files

1. **`app/pubspec.yaml`**
   - Add `youtube_player_flutter: ^9.0.3`
   - Run `flutter pub get`

2. **`app/lib/screens/program_detail_screen.dart`**
   - Refactor `_buildExerciseCard()` to stateful widget
   - Add video icon button
   - Add expandable video section
   - Import YouTubePlayerWidget

3. **`app/lib/screens/student_program_detail_screen.dart`**
   - Same changes as program_detail_screen.dart
   - Ensure consistency between student and instructor views

4. **`app/lib/screens/program_edit_screen.dart`**
   - Add YouTube URL input field to `_ExerciseEditorDialog`
   - Add validation for YouTube URLs
   - Update `_save()` method to include metadata
   - Add helper text explaining valid URL formats

5. **`app/lib/models/exercise.dart`**
   - No changes needed (metadata field already exists)
   - Verify toJson() includes metadata (already does)

### 6.3 Optional: Platform-Specific Configuration

**iOS (`ios/Runner/Info.plist`)**:
```xml
<!-- May need to add if video playback has issues -->
<key>io.flutter.embedded_views_preview</key>
<true/>
```

**Android (`android/app/src/main/AndroidManifest.xml`)**:
```xml
<!-- May need to add for internet-based video -->
<uses-permission android:name="android.permission.INTERNET" />
<!-- Already exists, verify it's present -->
```

**Web (`web/index.html`)**:
- No changes needed, iframe-based player works automatically

---

## 7. Implementation Details

### 7.1 Exercise Editor Dialog Changes

**Add YouTube URL Field** (in `_ExerciseEditorDialog`):

**Location**: After description field, before exercise type dropdown

```dart
// Add controller
late TextEditingController _youtubeUrlController;

// In initState()
_youtubeUrlController = TextEditingController(
  text: widget.exercise?.metadata?['youtube_url'] ?? '',
);

// In dispose()
_youtubeUrlController.dispose();

// In build() - new form field
TextFormField(
  controller: _youtubeUrlController,
  decoration: InputDecoration(
    labelText: 'YouTube Video URL (Optional)',
    hintText: 'https://www.youtube.com/watch?v=...',
    border: OutlineInputBorder(),
    helperText: 'Add a demonstration video',
    suffixIcon: _youtubeUrlController.text.isNotEmpty
      ? IconButton(
          icon: Icon(Icons.clear),
          onPressed: () {
            _youtubeUrlController.clear();
            setState(() {});
          },
        )
      : null,
  ),
  keyboardType: TextInputType.url,
  validator: (value) {
    if (value != null && value.isNotEmpty) {
      if (!YouTubeUrlHelper.isValidYouTubeUrl(value)) {
        return 'Please enter a valid YouTube URL';
      }
    }
    return null;
  },
  onChanged: (value) {
    setState(() {}); // Refresh suffix icon
  },
),
```

**Update `_save()` method**:
```dart
void _save() {
  if (_formKey.currentState!.validate()) {
    // Prepare metadata
    final Map<String, dynamic>? metadata =
      _youtubeUrlController.text.isNotEmpty
        ? {'youtube_url': _youtubeUrlController.text.trim()}
        : null;

    final exercise = Exercise(
      // ... existing fields ...
      metadata: metadata,
    );
    widget.onSave(exercise);
    Navigator.pop(context);
  }
}
```

### 7.2 Exercise Card Icon Button

**Add to existing card layout** (in `_buildExerciseCard`):

```dart
Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    // Existing: Number badge
    Container(...),
    const SizedBox(width: 12),

    // Existing: Exercise details
    Expanded(
      child: Column(...),
    ),

    // NEW: Video icon button
    if (_hasYouTubeUrl)
      IconButton(
        icon: Icon(
          _isVideoExpanded
            ? Icons.expand_less
            : Icons.play_circle_outline,
          color: burgundy,
        ),
        onPressed: _toggleVideo,
        tooltip: _isVideoExpanded
          ? 'Hide video'
          : 'Show demonstration video',
      ),
  ],
),
```

### 7.3 Expandable Video Section

**Add after existing card content**:

```dart
// Animated video player section
AnimatedSize(
  duration: Duration(milliseconds: 300),
  curve: Curves.easeInOut,
  child: _isVideoExpanded && _hasYouTubeUrl
    ? Container(
        margin: EdgeInsets.only(top: 12),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: YouTubePlayerWidget(
            youtubeUrl: widget.exercise.metadata!['youtube_url'],
          ),
        ),
      )
    : SizedBox.shrink(),
),
```

---

## 8. Error Handling & Edge Cases

### 8.1 Error Scenarios

1. **Invalid YouTube URL**
   - Validation in editor dialog prevents saving
   - Show error message: "Please enter a valid YouTube URL"
   - Clear icon button allows quick removal

2. **Video Not Found (404)**
   - Player shows YouTube's built-in error message
   - No custom handling needed (YouTube handles it)
   - Consider: Add error listener to show friendly message

3. **Network Error**
   - Player shows loading indicator then error
   - Offline mode: Video won't load (expected behavior)
   - No special handling needed

4. **Video Restricted (Region/Embed)**
   - YouTube's player shows restriction message
   - Consider: Pre-validate URLs using YouTube Data API (overkill for MVP)

### 8.2 Edge Cases

1. **Empty metadata or null URL**
   - Icon button hidden (already handled by conditional rendering)

2. **URL changes while video playing**
   - Not possible (editor is different screen)
   - On return from editor, card rebuilds with new data

3. **Multiple videos playing simultaneously**
   - Allowed (user's choice)
   - Alternative: Implement singleton controller (complex, not needed)

4. **Memory leaks from undisposed controllers**
   - Prevented by proper dispose() in widget lifecycle
   - Critical: Always call `_controller.dispose()` in dispose()

5. **Rapid expand/collapse taps**
   - AnimatedContainer handles gracefully
   - Consider: Add tap debouncing if issues occur

6. **Very long videos**
   - No special handling needed
   - User controls playback with YouTube's built-in controls

---

## 9. Performance Considerations

### 9.1 Lazy Loading

**Strategy**: Only initialize player when expanded

**Implementation**:
```dart
// Don't create controller in initState()
YoutubePlayerController? _controller;

void _toggleVideo() {
  setState(() {
    _isVideoExpanded = !_isVideoExpanded;

    if (_isVideoExpanded && _controller == null) {
      // Initialize on first expand
      _controller = YoutubePlayerController(
        initialVideoId: extractVideoId(url),
        flags: YoutubePlayerFlags(...),
      );
    } else if (!_isVideoExpanded && _controller != null) {
      // Pause when collapsed
      _controller?.pause();
    }
  });
}
```

**Benefit**: Don't load video resources until user wants to watch

### 9.2 Memory Management

**Critical Points**:
1. **Always dispose controllers**: Prevent memory leaks
2. **Pause on collapse**: Save bandwidth and battery
3. **Consider player count**: Multiple players = more memory usage

**Memory Profile** (estimated):
- Collapsed card: ~50KB (just UI)
- Expanded with player: ~5-10MB (video buffer)
- Multiple players: Linear growth

**Recommendation**: No pagination needed for MVP (typical programs have 5-10 exercises)

### 9.3 Network Usage

**Considerations**:
- Video streaming uses significant bandwidth
- Honor user's data plan (don't auto-play)
- YouTube handles adaptive bitrate automatically

**Settings**:
- `autoPlay: false` - User explicitly starts playback
- `forceHD: false` - Let YouTube choose quality based on network

---

## 10. Testing Strategy

### 10.1 Manual Testing Checklist

**Editor Dialog**:
- [ ] Add valid YouTube URL and save
- [ ] Add invalid URL and verify error message
- [ ] Clear URL with clear icon button
- [ ] Save exercise without URL (metadata null)
- [ ] Edit existing exercise with URL
- [ ] Edit existing exercise without URL and add one

**Program Detail Screen**:
- [ ] Exercise card shows video icon when URL exists
- [ ] Exercise card hides video icon when URL missing
- [ ] Tap icon expands video section smoothly
- [ ] Video player loads and plays correctly
- [ ] Tap icon again collapses video
- [ ] Video pauses when collapsed
- [ ] Navigate away and back - no memory leaks

**Student Program Detail Screen**:
- [ ] Same tests as above
- [ ] Verify student can view but not edit URLs

**URL Format Testing**:
- [ ] `youtube.com/watch?v=ID` works
- [ ] `youtu.be/ID` works
- [ ] `youtube.com/embed/ID` works
- [ ] `m.youtube.com/watch?v=ID` works
- [ ] Invalid URL shows error

**Error Scenarios**:
- [ ] Video ID not found (404)
- [ ] Restricted video (region/embed blocked)
- [ ] Network error (airplane mode)
- [ ] Very long URL
- [ ] URL with extra parameters

### 10.2 Platform Testing

**iOS**:
- [ ] Video plays correctly
- [ ] Player controls work
- [ ] Full-screen mode works
- [ ] Background behavior correct

**Android**:
- [ ] Video plays correctly
- [ ] Player controls work
- [ ] Full-screen mode works
- [ ] Back button behavior

**Web**:
- [ ] Iframe player loads
- [ ] Controls work
- [ ] Responsive sizing
- [ ] Browser compatibility (Chrome, Safari, Firefox)

### 10.3 Edge Case Testing

- [ ] Rapid expand/collapse taps
- [ ] Multiple videos expanded simultaneously
- [ ] Rotate device while video playing
- [ ] Low memory device behavior
- [ ] Slow network connection
- [ ] Switch between programs with videos

---

## 11. Deployment & Migration

### 11.1 Backward Compatibility

**Good News**: Fully backward compatible!

**Reasoning**:
- Existing exercises without `metadata['youtube_url']` work unchanged
- Icon button only shows when URL exists
- No database migration needed
- No breaking changes to Exercise model

### 11.2 Rollout Plan

**Phase 1**: Backend (No changes needed)
- Exercise model already has metadata JSONB field
- API already accepts and returns metadata

**Phase 2**: Flutter App Update
1. Add package dependency
2. Create YouTubePlayerWidget
3. Update program_detail_screen.dart
4. Update student_program_detail_screen.dart
5. Update program_edit_screen.dart
6. Test thoroughly on all platforms

**Phase 3**: Gradual Adoption
- Instructors can start adding YouTube URLs to exercises
- Students immediately see video players
- No forced updates required

### 11.3 Feature Flag (Optional)

**If cautious rollout desired**:
```dart
class FeatureFlags {
  static const bool enableYouTubeVideos = true;
}

// In widget code
if (FeatureFlags.enableYouTubeVideos && _hasYouTubeUrl) {
  // Show video button
}
```

**Benefit**: Can disable feature remotely if issues discovered

---

## 12. Future Enhancements

### 12.1 Near-Term (Post-MVP)

1. **Video Thumbnails**
   - Show YouTube thumbnail instead of just icon
   - Package supports: `YoutubePlayer.getThumbnail(videoId)`
   - Better visual preview

2. **Timestamp Deep Links**
   - Allow URLs with timestamp: `?t=30s`
   - Jump to specific form demonstration
   - Package supports: `startSeconds` parameter

3. **Playlist Support**
   - Multiple videos per exercise
   - Series of form corrections
   - Package supports playlist IDs

4. **Offline Caching** (Complex)
   - Download videos for offline viewing
   - Requires youtube-dl backend service
   - Legal/licensing considerations

### 12.2 Long-Term Vision

1. **Custom Video Hosting**
   - Host videos on own server
   - Better control and privacy
   - Use `video_player` package instead

2. **Video Analytics**
   - Track which videos students watch
   - Completion percentage
   - Helps instructors understand engagement

3. **Interactive Markers**
   - Annotate videos with form tips
   - Timestamp-based notes
   - Overlay graphics

4. **AI Form Comparison**
   - Side-by-side: instructor video vs student submission
   - Computer vision analysis
   - Pose estimation overlay

---

## 13. Implementation Sequence

### Step-by-Step Order

1. **Setup** (5 min)
   - Add `youtube_player_flutter` to pubspec.yaml
   - Run `flutter pub get`

2. **Create Utilities** (10 min)
   - Create `youtube_url_helper.dart`
   - Implement validation and extraction functions
   - Write quick unit tests

3. **Create Reusable Widget** (30 min)
   - Create `youtube_player_widget.dart`
   - Implement controller initialization
   - Add error handling and loading states
   - Test with sample video ID

4. **Update Exercise Editor** (20 min)
   - Add YouTube URL controller
   - Add form field with validation
   - Update save method to include metadata
   - Test adding/editing URLs

5. **Update Program Detail Screen** (45 min)
   - Refactor `_buildExerciseCard` to stateful widget
   - Add video icon button
   - Add expandable video section
   - Implement expand/collapse logic
   - Test thoroughly

6. **Update Student Program Detail Screen** (30 min)
   - Apply same changes as program detail
   - Ensure consistency
   - Test student view

7. **Cross-Platform Testing** (60 min)
   - Test on iOS simulator
   - Test on Android emulator
   - Test on web browser
   - Test all edge cases

8. **Polish & Documentation** (20 min)
   - Add code comments
   - Update session documentation
   - Create pull request
   - Write user-facing documentation

**Total Estimated Time**: 3.5 hours

---

## 14. Success Criteria

### Definition of Done

- [ ] Instructors can add YouTube URLs to exercises in editor
- [ ] Invalid URLs are rejected with clear error messages
- [ ] Exercise cards show video icon only when URL exists
- [ ] Tapping icon expands/collapses video player smoothly
- [ ] Video plays correctly on all platforms (iOS, Android, Web)
- [ ] Player pauses when collapsed
- [ ] No memory leaks (controllers properly disposed)
- [ ] Student view shows videos (read-only)
- [ ] Backward compatible with existing exercises
- [ ] Code is well-documented
- [ ] All manual tests pass

### User Acceptance Criteria

**Instructor Perspective**:
- "I can easily add demonstration videos to exercises"
- "The video player is intuitive and doesn't interfere with practice"
- "Students can watch my form demonstrations"

**Student Perspective**:
- "I can watch demonstration videos before practicing"
- "The video player is easy to use"
- "Videos help me understand proper form"

---

## 15. Risk Assessment

### Low Risk ✅
- Package is mature and stable
- No backend changes needed
- Fully backward compatible
- Can be feature-flagged if needed

### Medium Risk ⚠️
- Platform-specific video playback quirks
- Network-dependent feature (offline users affected)
- Memory usage with multiple players

### Mitigation Strategies
1. **Thorough platform testing** before release
2. **Clear documentation** that videos require internet
3. **Lazy loading** to minimize memory usage
4. **Proper disposal** to prevent leaks
5. **Graceful degradation** (hide icon if URL invalid)

---

## 16. Documentation Updates Needed

### Code Documentation
- Add comprehensive comments to YouTubePlayerWidget
- Document metadata structure in Exercise model
- Add inline comments for expand/collapse logic

### User Documentation
- Instructor guide: "How to add demonstration videos"
- Student guide: "How to watch exercise videos"
- FAQ: "What video formats are supported?"

### Developer Documentation
- Update architecture.md with new widget
- Add to features.md catalog
- Document in session notes

---

## Conclusion

This implementation provides a clean, performant solution for YouTube video playback that:
- Follows Flutter best practices
- Maintains the app's minimalist design philosophy
- Respects martial arts training context (no auto-play, non-intrusive)
- Is fully backward compatible
- Can be extended for future video features

The inline expansion approach aligns with the principle of **wu wei** (effortless action) - the video is there when needed but doesn't demand attention when not required.

**Next Steps**:
1. Review this plan with main agent
2. Confirm approach and any modifications needed
3. Main agent implements based on this plan
4. Update session documentation upon completion
