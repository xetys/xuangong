# Recent Work Log

*Last updated: 2025-11-05*

This file tracks the most recent changes to the codebase. Keep this updated after significant work.

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
