# Recent Work Log

*Last updated: 2025-11-20*

This file tracks the most recent changes to the codebase. Keep this updated after significant work.

---

## 2025-11-20: UI/UX Improvements & Sound Volume Settings

**Status**: ✅ Complete - Fully Tested

### Changes
1. **Home Screen Double Scroll Bug Fix**
   - Removed outer `SingleChildScrollView` wrapper causing nested scroll contexts
   - Changed `TabBarView` from fixed height to `Expanded` for proper layout
   - Added bottom padding (80px) to both ListViews for FAB clearance
   - Moved "Welcome back" message to drawer header

2. **Both Sides Functionality Fix**
   - Added `sideDurationController` to program_edit_screen.dart for separate side duration input
   - Implemented `_currentSide` state tracking (null, 1, or 2) in practice_screen.dart
   - Added side transition logic - second side plays after first completes
   - Fixed duration calculation to properly double duration for exercises with `hasSides=true`
   - Added UI badges showing "First Side"/"Second Side" during practice
   - Fixed fallback: `sideDurationSeconds ?? durationSeconds ?? 0`

3. **Sound Volume Settings (Backend + Flutter)**
   - **Backend**: Added 4 volume columns to users table (migration 000006)
     - `countdown_volume`, `start_volume`, `halfway_volume`, `finish_volume`
     - CHECK constraints for valid values (0, 25, 50, 75, 100)
     - Defaults: countdown=75, start=75, halfway=25, finish=100
   - **Backend**: Updated User model, validators, auth service, and repositories
   - **Backend**: Fixed repository queries to SELECT and UPDATE volume columns
   - **Flutter**: New AudioSettingsScreen with 5-level selection UI
   - **Flutter**: Updated SettingsScreen with navigation to audio settings
   - **Flutter**: Extended AudioService with volume control methods
   - **Flutter**: Settings apply immediately without app reload
   - **Flutter**: HomeScreen reloads user data when settings change

4. **Wake Lock Reliability Enhancement**
   - Added periodic timer to renew wake lock every 30 seconds
   - Prevents screen timeout on devices where wake locks can expire
   - Timer properly cleaned up in dispose method

5. **Session Count Display for All Programs**
   - Changed condition from `repetitionsPlanned != null` to always show for non-templates
   - Display format: "X/Y" if planned repetitions exist, "X sessions" otherwise
   - Applied to both home_screen.dart and student_detail_screen.dart

### Files Modified

**Backend**:
- `backend/internal/repositories/user_repository.go` - Added volume fields to all queries and Update method
- `backend/internal/models/user.go` - Added 4 volume fields to User and UserResponse
- `backend/internal/validators/requests.go` - Added volume validation to UpdateProfileRequest
- `backend/internal/services/auth_service.go` - Extended UpdateProfile to accept volume parameters
- `backend/internal/handlers/auth.go` - Updated UpdateProfile handler to pass volumes

**Backend (New Files)**:
- `backend/migrations/000006_add_user_audio_settings.up.sql`
- `backend/migrations/000006_add_user_audio_settings.down.sql`

**Flutter**:
- `app/lib/models/user.dart` - Added 4 volume fields with defaults
- `app/lib/models/program.dart` - Fixed duration calculation for both sides
- `app/lib/services/audio_service.dart` - Added volume control methods
- `app/lib/services/auth_service.dart` - Extended updateProfile with volume parameters
- `app/lib/screens/home_screen.dart` - Fixed scroll, added user reload, session count display
- `app/lib/screens/settings_screen.dart` - Made functional, returns settings changed flag
- `app/lib/screens/program_edit_screen.dart` - Added side duration input field
- `app/lib/screens/program_detail_screen.dart` - Changed button visibility to ownership-based
- `app/lib/screens/practice_screen.dart` - Side tracking, volume initialization, wake lock timer
- `app/lib/screens/student_detail_screen.dart` - Session count display

**Flutter (New Files)**:
- `app/lib/screens/audio_settings_screen.dart` - Full audio settings UI

### Technical Details

**Sound Volume Implementation**:
```dart
// AudioService volume conversion
double _convertVolume(int volume) {
  return volume / 100.0;  // Convert 0-100 to 0.0-1.0
}

// Atomic volume setting
Future<void> setAllVolumes({
  required int countdown,
  required int start,
  required int halfway,
  required int finish,
}) async {
  await _ensureInitialized();
  await _lastTwoPlayer?.setVolume(_convertVolume(countdown));
  await _startPlayer?.setVolume(_convertVolume(start));
  await _halfPlayer?.setVolume(_convertVolume(halfway));
  await _longGongPlayer?.setVolume(_convertVolume(finish));
}
```

**Settings Change Propagation**:
```dart
// SettingsScreen returns true when settings changed
return WillPopScope(
  onWillPop: () async {
    Navigator.pop(context, _settingsChanged);
    return false;
  },
  child: Scaffold(...),
);

// HomeScreen reloads user
if (result == true) {
  _loadCurrentUser();
}
```

**Wake Lock Reliability**:
```dart
// Periodic renewal every 30 seconds
_wakelockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
  WakelockPlus.enable();
});
```

### Issues Resolved
1. Double scroll causing confusing UX on home screen
2. Both sides exercises not working (duration and execution)
3. Start practice button not showing for program owners
4. Audio settings showing as "Off" despite DB values (missing SELECT columns)
5. Save button text not visible (missing foreground color)
6. Audio settings requiring app reload to take effect
7. Back arrow not visible in audio settings (missing foreground color)
8. Wake lock expiring on some devices during long practice
9. Session counts only showing for programs with planned repetitions

### Testing Completed
1. ✅ Home screen scrolling and FAB padding
2. ✅ Both sides exercises (2x duration, runs twice)
3. ✅ Audio settings UI (all 5 levels)
4. ✅ Audio settings persistence and immediate effect
5. ✅ Volume controls working during practice
6. ✅ Wake lock staying active during long sessions
7. ✅ Session count showing for all programs

### Database Schema Updates
```sql
-- Migration 000006
ALTER TABLE users
ADD COLUMN countdown_volume INTEGER NOT NULL DEFAULT 75
    CHECK (countdown_volume IN (0, 25, 50, 75, 100)),
ADD COLUMN start_volume INTEGER NOT NULL DEFAULT 75
    CHECK (start_volume IN (0, 25, 50, 75, 100)),
ADD COLUMN halfway_volume INTEGER NOT NULL DEFAULT 25
    CHECK (halfway_volume IN (0, 25, 50, 75, 100)),
ADD COLUMN finish_volume INTEGER NOT NULL DEFAULT 100
    CHECK (finish_volume IN (0, 25, 50, 75, 100));
```

---

## 2025-11-06: Admin Features - Flutter Integration

**Status**: ✅ Complete - Ready for Testing

### Changes
1. **Backend Fixes for Admin Features**
   - Added missing routes: `GET /api/v1/users/:id/sessions` and `PUT /api/v1/users/:id/role`
   - Fixed UserService to fetch exercises for programs (added exerciseRepo dependency)
   - Updated session authorization to allow admins to view any user's sessions
   - Fixed GetUserSessions handler parameter mismatch (`:id` route vs `user_id` param)

2. **Flutter Service Updates**
   - Added `getUserSessions()` to SessionService for fetching any user's sessions
   - Added `updateUserRole()` to UserService for role management
   - Updated ExerciseLog model with all backend fields (startedAt, completedAt, etc.)

3. **Admin Session Viewing**
   - Created new SessionDetailScreen (read-only view for admins)
   - Updated ProgramDetailScreen to route admins to detail view, students to edit view
   - Fixed student_detail_screen to load current admin user and navigate to full program view

4. **Bug Fixes**
   - Fixed programs showing 0 exercises by fetching exercises in GetUserPrograms
   - Fixed nullable exerciseId handling in session_edit_screen
   - Fixed authorization for admin viewing student sessions

### Files Modified
**Backend**:
- `backend/cmd/api/main.go` - Routes and UserService initialization (lines 52, 194-195)
- `backend/internal/services/user_service.go` - Added exerciseRepo, updated GetUserPrograms
- `backend/internal/services/session_service.go` - Added role parameter to GetSession (line 39)
- `backend/internal/handlers/sessions.go` - Role extraction and parameter fix (lines 128-133, 407)

**Flutter**:
- `app/lib/services/session_service.dart` - Added getUserSessions (lines 141-176)
- `app/lib/services/user_service.dart` - Added updateUserRole (lines 77-86)
- `app/lib/screens/student_detail_screen.dart` - Load admin user, navigate to ProgramDetailScreen
- `app/lib/screens/program_detail_screen.dart` - Session routing based on role (lines 581-595)
- `app/lib/models/session.dart` - Updated ExerciseLog with all backend fields
- `app/lib/screens/session_edit_screen.dart` - Fixed nullable exerciseId (lines 76-80)

**Flutter (New Files)**:
- `app/lib/screens/session_detail_screen.dart` - Read-only session view for admins

### Technical Details
**Backend Authorization Enhancement**:
```go
// Verify user owns this session (admins can view any session)
if role != models.RoleAdmin && session.UserID != userID {
    return nil, appErrors.NewAuthorizationError("You don't have access to this session")
}
```

**Role-Based UI Routing**:
```dart
final screen = _isAdmin()
    ? SessionDetailScreen(sessionId: session.id)  // Read-only for admins
    : SessionEditScreen(sessionId: session.id);   // Editable for students
```

### Issues Resolved
1. Missing backend routes causing 404 errors
2. Programs loading without exercises (0 exercises shown)
3. Parameter mismatch in GetUserSessions handler
4. Model synchronization between backend and Flutter
5. Authorization blocking admin session access
6. Nullable type errors in session editing

### Testing Required
1. Admin viewing student sessions (across different students)
2. Admin viewing session details (read-only view)
3. Student viewing own sessions (should get editable view)
4. Program deletion by admin
5. Role updates (student → admin, admin → student)
6. Edge case: Last admin role update should fail

### Related Work
- Backend TDD implementation completed in previous session (Tasks 1-10)
- This session focused on Flutter integration (Tasks 11-14)
- Manual testing (Task 15) ready to begin

---

## 2025-11-06: Video Submission System & Backend Refactoring

**Status**: ✅ Complete

### Overview
Completed implementation of video submission chat system with TDD approach on backend, Flutter UI implementation, real-time badge updates, and comprehensive backend refactoring for better error handling and performance.

### Backend Implementation (Go + PostgreSQL)

**Database Schema**:
- Migration `000005_video_submissions_chat.up.sql`
- Tables: `submissions`, `submission_messages`, `message_read_status`
- Soft delete support, read tracking, YouTube URL support

**Three-Layer Architecture**:
1. **Repository Layer** (`internal/repositories/submission_repository.go`)
   - TDD approach with comprehensive test coverage
   - Optimized List query using LATERAL join (better performance than subqueries)
   - Sentinel errors for type-safe error handling
   - Methods: Create, GetByID, List, CreateMessage, GetMessages, MarkMessageAsRead, GetUnreadCount, SoftDelete

2. **Service Layer** (`internal/services/submission_service.go`)
   - Business logic and validation
   - YouTube URL validation using `pkg/youtube` package
   - Access control (admin can see all, students see only their own)
   - Error translation to app-specific errors

3. **Handler Layer** (`internal/handlers/submissions.go`)
   - RESTful API endpoints
   - Request validation
   - Enhanced error logging with request context

**Refactoring Improvements**:
- Sentinel errors pattern: `ErrAccessDenied`, `ErrSubmissionNotFound`, `ErrMessageNotFound`, `ErrAlreadyDeleted`
- Replaced string comparisons with `errors.Is()` for type safety
- Enhanced logging: includes HTTP method + path in error logs
- Query optimization: LATERAL join in List query for better performance

### Frontend Implementation (Flutter)

**New Screens**:
- `submission_chat_screen.dart` - Chat interface with YouTube video support
- `submissions_screen.dart` - List view with unread badges

**New Widgets**:
- `message_bubble.dart` - Message display with YouTube player integration
- `submission_card.dart` - Submission list item with metadata
- `unread_badge.dart` - Reusable badge component

**New Models**:
- `submission.dart` - Submission, SubmissionListItem, SubmissionMessage, MessageWithAuthor, UnreadCounts

**New Services**:
- `submission_service.dart` - API client for submission endpoints

**UI/UX Enhancements**:
1. **Real-time Badge Updates**
   - 30-second auto-reload timer on home screen
   - Badges show in tab titles and program cards
   - Immediate updates on navigation

2. **YouTube URL Enforcement**
   - Required field when creating submissions
   - Automatically posted as first message
   - Inline video player in chat

3. **Navigation State Management**
   - WillPopScope returns boolean indicating if messages were sent
   - Parent screens reload data appropriately

### Bug Fixes
1. Fixed parameter name mismatch: `videoUrl` → `youtubeUrl`
2. Fixed route conflict: `:programId` → `:id` in Gin router
3. Fixed null handling in submission service (API can return null for empty lists)
4. Fixed badge visibility on initial app load

### Files Created

**Backend**:
- `internal/repositories/submission_repository.go`
- `internal/repositories/submission_repository_test.go`
- `internal/services/submission_service.go`
- `internal/handlers/submissions.go`
- `migrations/000005_video_submissions_chat.up.sql`
- `migrations/000005_video_submissions_chat.down.sql`

**Frontend**:
- `app/lib/models/submission.dart`
- `app/lib/screens/submission_chat_screen.dart`
- `app/lib/screens/submissions_screen.dart`
- `app/lib/services/submission_service.dart`
- `app/lib/widgets/message_bubble.dart`
- `app/lib/widgets/submission_card.dart`
- `app/lib/widgets/unread_badge.dart`

**Documentation**:
- `.claude/docs/backend/video-submission-tdd-plan.md`
- `.claude/docs/app/video-submission-flutter-implementation-plan.md`

### Files Modified

**Backend**:
- `cmd/api/main.go` - Added submission routes
- `internal/handlers/helpers.go` - Enhanced error logging
- `internal/models/submission.go` - Added submission models
- `internal/validators/requests.go` - Added submission validators
- `pkg/testutil/fixtures.go` - Added submission fixtures

**Frontend**:
- `app/lib/screens/home_screen.dart` - Added unread count timer
- `app/lib/screens/program_detail_screen.dart` - Added submissions tab, YouTube URL enforcement

### API Endpoints
```
POST   /api/v1/programs/:id/submissions
GET    /api/v1/submissions
GET    /api/v1/submissions/:id
DELETE /api/v1/submissions/:id
GET    /api/v1/submissions/:id/messages
POST   /api/v1/submissions/:id/messages
PUT    /api/v1/messages/:id/read
GET    /api/v1/submissions/unread-count
```

### Testing Status
- ✅ Backend compiles successfully
- ✅ Repository tests pass (TDD approach)
- ✅ All refactoring changes verified
- ✅ Flutter app tested with real API

---

## 2025-11-05: Logout Bug Fix

**Status**: ✅ Fixed - Ready for Testing

### Bug Description
After logout in production web app, user cannot log back in because app tries to connect to localhost instead of production API URL.

### Root Cause
FlutterSecureStorage's `deleteAll()` on web platform clears ALL localStorage items, including the Docker-injected `API_URL` configuration key. After logout, `api_config_web.dart` can't find the URL and falls back to `http://localhost:8080`.

### Solution (Recommended)
Replace `StorageService.clearAll()` implementation with explicit individual key deletions:
- Delete only: `access_token`, `refresh_token`, `user_id`, `user_email`
- Preserve: `API_URL` (environment configuration)

### Implementation
- Modified `app/lib/services/storage_service.dart` line 49-58
- Replaced `deleteAll()` with individual key deletions
- Added clear warning comments for future maintainers
- Preserves `API_URL` in localStorage during logout

### Documentation
- Full analysis: `.claude/docs/app/logout-bug-analysis-and-fix.md`
- 4 options evaluated, Option A (individual deletion) implemented
- Single file change, zero risk

### Testing Required
1. Login to production web app
2. Logout
3. Login again - should use production URL (not localhost)
4. Verify no errors in console

---

## 2025-11-05: YouTube Video Links & Alpha13 Deployment

**Status**: ✅ Complete (deployed as alpha13)

### Changes
1. Added YouTube video link support for exercises
   - Backend validator package with comprehensive URL format support
   - Frontend YouTube player widget (web-compatible)
   - Expandable inline video player on program detail screen
   - URL input field in exercise editor with validation

2. Fixed CORS for Flutter web development
   - Updated middleware to support localhost with any port
   - Handles Flutter's random port assignment

3. Established critical deployment rule
   - For deployments: ONLY change image tag in values-production.yaml
   - NEVER modify Chart.yaml, pubspec.yaml, or go.mod
   - Created `.claude/docs/deployment/CRITICAL-RULES.md`

4. Deployed alpha13 to production
   - Built Docker image: ghcr.io/xetys/xuangong/app:v2025.1.0-alpha13
   - Pushed to GitHub Container Registry
   - Deployed via Helm to xuangong-prod namespace (ONLY changed image tag)
   - Zero downtime rolling update

### Files Created
**Backend**:
- `backend/pkg/youtube/validator.go` - YouTube URL validation
- `backend/pkg/youtube/validator_test.go` - 31 passing tests

**Frontend**:
- `app/lib/utils/youtube_url_helper.dart` - URL parsing utilities
- `app/lib/widgets/youtube_player_widget.dart` - Player components

**Documentation**:
- `.claude/docs/deployment/CRITICAL-RULES.md` - Deployment versioning rules
- `.claude/tasks/sessions/2025-11-05_alpha13-youtube-deployment.md`

### Files Modified
**Backend**:
- `backend/internal/services/exercise_service.go` - Metadata validation
- `backend/internal/middleware/cors.go` - Localhost wildcard support
- `backend/.env.development` - CORS configuration
- `backend/docker-compose.yml` - Environment variables

**Frontend**:
- `app/lib/models/exercise.dart` - YouTube URL getters
- `app/lib/screens/program_edit_screen.dart` - URL input field
- `app/lib/screens/program_detail_screen.dart` - Video player integration
- `app/pubspec.yaml` - Added youtube_player_iframe: ^5.2.1
- `app/ios/Podfile.lock` - Updated dependencies

**Deployment**:
- `app/helm/xuangong-app/values-production.yaml` - Tag v2025.1.0-alpha13 (ONLY file changed for deployment)

### Issues Resolved
1. CORS blocking localhost with random ports
2. YouTube player not web-compatible (switched packages)
3. iOS webview errors (updated CocoaPods)
4. Incorrect versioning approach (established clear rules)

### Deployment
- Production URL: https://app.xuangong-prod.stytex.cloud
- Image: ghcr.io/xetys/xuangong/app:v2025.1.0-alpha13
- Status: 2 pods running, HTTP 200 ✅

---

## 2025-11-02: Session Management & Context Tracking Setup

**Status**: ✅ Complete

### Changes
1. Created `.claude/tasks/` directory structure
   - `sessions/` - For conversation logs
   - `context/` - For quick reference files

2. Updated `CLAUDE.md` with new section "Session & Context Management"
   - Added context-first workflow rules
   - Defined strict subagent usage policy
   - Added session documentation guidelines

3. Created context files:
   - `architecture.md` - Tech stack and architectural patterns
   - `features.md` - Complete feature catalog
   - `recent-work.md` - This file
   - `decisions.md` - ADR-style decision log

4. Created `tasks/README.md` - Documentation for the tracking system

### Files Modified
- `CLAUDE.md` - Added session management section
- `.gitignore` - (checked, no changes needed)

### Files Created
- `.claude/tasks/context/architecture.md`
- `.claude/tasks/context/features.md`
- `.claude/tasks/context/recent-work.md`
- `.claude/tasks/context/decisions.md`
- `.claude/tasks/README.md`
- `.claude/tasks/sessions/2025-11-02_session-management-setup.md`

---

## 2025-11-02: Background Timer Implementation

**Status**: ✅ Complete

### Changes
1. Added wake lock support to keep screen on during practice
   - Added `wakelock_plus: ^1.2.8` to pubspec.yaml
   - Integrated into `practice_screen.dart`

2. Implemented background notifications with live countdown
   - Added `flutter_local_notifications: ^17.2.3` to pubspec.yaml
   - Created `notification_service.dart` with cross-platform support
   - Shows exercise name, countdown, and progress when app backgrounded

3. Configured iOS background audio
   - Updated `Info.plist` with audio background mode
   - Configured `AudioService` with background audio session

4. Updated Android permissions
   - Added WAKE_LOCK permission
   - Added FOREGROUND_SERVICE permission
   - Added POST_NOTIFICATIONS permission (Android 13+)

5. Initialized notification service in `main.dart`

### Files Modified
- `app/pubspec.yaml` - Added packages
- `app/lib/screens/practice_screen.dart` - Wake lock + notifications
- `app/lib/services/audio_service.dart` - iOS background audio
- `app/ios/Runner/Info.plist` - Background modes
- `app/android/app/src/main/AndroidManifest.xml` - Permissions
- `app/lib/main.dart` - Service initialization

### Files Created
- `app/lib/services/notification_service.dart` - Notification management

### Testing Status
- ✅ iOS: Tested on simulator
- ⏳ Android: Not yet tested
- ✅ Web: Wake lock works, notifications gracefully skipped

---

## 2025-11-02: Session Complete Screen Updates

**Status**: ✅ Complete

### Changes
1. Commented out streak and total sessions stats
   - Added TODO for future implementation
   - Kept exercise count and duration stats

2. Fixed "View Session History" link
   - Now navigates to `PracticeCalendarScreen` instead of showing "Coming soon"
   - Calendar already implemented and working

### Files Modified
- `app/lib/screens/session_complete_screen.dart`

---

## 2025-11-02: Fixed dart:html Import Issue

**Status**: ✅ Complete

### Problem
`dart:html` is web-only and caused compilation errors on iOS/Android builds

### Solution
Implemented conditional imports with platform-specific implementations:
- `api_config.dart` - Main file with conditional import
- `api_config_web.dart` - Web implementation (uses dart:html)
- `api_config_stub.dart` - Mobile implementation (uses dart:io)

### Files Modified
- `app/lib/config/api_config.dart` - Conditional imports

### Files Created
- `app/lib/config/api_config_web.dart` - Web-specific API URL getter
- `app/lib/config/api_config_stub.dart` - Mobile API URL getter

---

## 2025-11-02: PWA Theme Color Update

**Status**: ✅ Complete (deployed as alpha9)

### Changes
1. Updated PWA manifest
   - Changed theme_color to #9B1C1C (Xuan Gong burgundy)
   - Changed background_color to match
   - Updated app name to "Xuan Gong"

2. Updated HTML meta tags
   - Added theme-color meta tag
   - Changed iOS status bar style to black-translucent

### Files Modified
- `app/web/manifest.json`
- `app/web/index.html`

### Deployment
- Built and deployed as v2025.1.0-alpha9
- Verified with curl on production

---

## 2025-11-01: Fixed API URL Injection (alpha2-alpha8)

**Status**: ✅ Complete (deployed as alpha8)

### Problem
Flutter web app showed `$API_URL` instead of actual production URL. Multiple attempts to fix:
- alpha2-alpha5: Permission issues writing to index.html
- alpha6-alpha7: nginx PID permission issues
- alpha8: Success!

### Solution
1. Created Docker entrypoint script `/docker-entrypoint.d/40-envsubst-index.sh`
2. Uses `envsubst` to replace `$API_URL` in index.html at container startup
3. Made `/usr/share/nginx/html` writable by nginx user
4. Fixed nginx PID location to `/var/run/nginx/nginx.pid`

### Files Modified
- `app/Dockerfile` - Entrypoint script, permissions, nginx PID fix
- `app/web/index.html` - JavaScript to read API URL from localStorage

### Deployment
- Production URL: https://app.xuangong-prod.stytex.cloud
- Backend URL: https://xuangong-prod.stytex.cloud

---

## Recent Git Commits

```
bb6436a prepare for deployment of web version
7a159b8 adds student administration and menu
9ad13de Add program repetition tracking and session management features
d888849 Implement program/template management with API integration
57c5556 initial import
```

---

## Current Focus Areas

1. ✅ Background timer features - Complete
2. ✅ Session management - Complete
3. ⏳ Testing on Android emulator
4. ⏳ Video upload implementation
5. ⏳ Offline mode with sync

---

## Known Issues

1. **Unused variable warning** in `main.dart:107` - `isLoggedIn` variable not used
   - Low priority, doesn't affect functionality

2. **Android testing** - Not yet tested on Android emulator
   - Need to verify background notifications work correctly

3. **Streak/session counting** - Commented out in session complete screen
   - Backend tracking exists but frontend display removed temporarily

---

## Next Steps

1. Test background timer on physical iOS device
2. Test on Android emulator
3. Deploy latest version to production (with background features)
4. Consider implementing streak/session counting
5. Plan video upload feature

---

*Keep this file updated! Add new entries at the top, maintain chronological order.*
