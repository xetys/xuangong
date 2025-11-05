# Architectural Decision Records

This file documents key technical and architectural decisions made during development.

---

## ADR-001: Runtime API URL Injection via envsubst

**Date**: 2025-11-02
**Status**: ✅ Accepted
**Deciders**: Claude Code AI

### Context
Flutter web builds are static files. We need different API URLs for development vs production without rebuilding the app for each environment.

### Decision
Use `envsubst` in Docker entrypoint script to inject API URL at container startup:
1. Flutter build includes `$API_URL` placeholder in index.html
2. Docker entrypoint runs `envsubst` to replace placeholder with actual value
3. JavaScript stores result in localStorage
4. Dart code reads from localStorage

### Consequences
**Positive**:
- Single Docker image works across all environments
- No rebuild needed for different deployments
- ConfigMap controls the URL per environment

**Negative**:
- Requires writable /usr/share/nginx/html directory
- Adds complexity to Docker entrypoint
- Must ensure proper file permissions

### Alternatives Considered
- nginx `sub_filter`: Didn't work reliably
- Environment-specific builds: Would require separate images
- JavaScript fetch from config file: Additional HTTP request

### Implementation
- `app/Dockerfile`: Entrypoint script with envsubst
- `app/web/index.html`: Placeholder and localStorage logic
- `app/lib/config/api_config_web.dart`: Read from localStorage

---

## ADR-002: Conditional Imports for Platform-Specific Code

**Date**: 2025-11-02
**Status**: ✅ Accepted
**Deciders**: Claude Code AI

### Context
`dart:html` is only available on web platform. Importing it in shared code causes compilation errors on iOS/Android.

### Decision
Use Dart conditional imports:
```dart
import 'api_config_stub.dart'
    if (dart.library.html) 'api_config_web.dart';
```

### Consequences
**Positive**:
- Clean separation of platform-specific code
- No compilation errors
- Type-safe at compile time

**Negative**:
- Need to maintain multiple implementations
- Slightly more complex file structure

### Alternatives Considered
- `kIsWeb` runtime checks: Would still import dart:html on all platforms
- Separate entry points: Too much duplication
- Platform channels: Overkill for simple configuration

### Implementation
- `app/lib/config/api_config.dart`: Main file with conditional import
- `app/lib/config/api_config_web.dart`: Web implementation
- `app/lib/config/api_config_stub.dart`: Mobile implementation

---

## ADR-003: Singleton Pattern for Services

**Date**: 2025-10-XX (Initial architecture)
**Status**: ✅ Accepted
**Deciders**: Original developer + Claude Code AI

### Context
Services like AudioService, NotificationService need to:
- Maintain state across the app
- Initialize expensive resources once
- Be accessible from multiple screens

### Decision
Use singleton pattern for all services:
```dart
class MyService {
  static final MyService _instance = MyService._internal();
  factory MyService() => _instance;
  MyService._internal();
}
```

### Consequences
**Positive**:
- Single source of truth for service state
- No duplicate initialization
- Easy access from anywhere
- Predictable behavior

**Negative**:
- Harder to test (need to reset state between tests)
- Potential memory leak if not disposed properly
- Less flexible than dependency injection

### Alternatives Considered
- Provider/Riverpod: Overkill for MVP
- Manual instance passing: Too verbose
- Service locator: More complex than needed

### Implementation
All services use this pattern:
- `audio_service.dart`
- `notification_service.dart`
- `auth_service.dart`
- `program_service.dart`
- `session_service.dart`

---

## ADR-004: Non-Root nginx Container

**Date**: 2025-11-02
**Status**: ✅ Accepted
**Deciders**: Claude Code AI

### Context
Security best practice is to run containers as non-root users. Default nginx runs as root.

### Decision
Configure nginx to run as nginx user (uid 101):
1. Make all required directories writable by nginx user
2. Change PID file location to `/var/run/nginx/nginx.pid`
3. Use port 8080 (non-privileged) instead of 80
4. Pre-create all directories at build time

### Consequences
**Positive**:
- Better security posture
- Kubernetes security policies happy
- Follows Docker/K8s best practices

**Negative**:
- More complex Dockerfile
- Must manage permissions carefully
- Non-standard nginx setup

### Alternatives Considered
- Run as root: Security risk
- Custom user: More complexity
- Different web server: nginx is proven and lightweight

### Implementation
- `app/Dockerfile`: Extensive chown and mkdir commands
- nginx.conf: PID file location change
- Port 8080 instead of 80

---

## ADR-005: Strict Subagent Policy for Claude Code

**Date**: 2025-11-02
**Status**: ✅ Accepted
**Deciders**: User + Claude Code AI

### Context
Need to maintain consistency, documentation, and control over code changes when using Claude Code subagents for research.

### Decision
**Strict Policy**: Subagents (Task tool with Plan/Explore) are for RESEARCH ONLY:
- ✅ Allowed: Read files, search, gather info, create plans
- ❌ Forbidden: Edit files, write files, run commands that modify state
- Main agent executes implementation based on subagent research

### Consequences
**Positive**:
- Main agent maintains full context
- Session continuity preserved
- Proper documentation of changes
- Clear separation of concerns
- Consistent code quality

**Negative**:
- Slower workflow (can't delegate implementation)
- More manual work for main agent
- Subagents can't make quick fixes

**Neutral**:
- Readonly tools (Read, Glob, Grep) always allowed for all agents

### Alternatives Considered
- Flexible policy: Too ambiguous
- No subagents: Would lose research capabilities
- Full delegation: Would lose context and control

### Implementation
- Added to CLAUDE.md as explicit rule
- Documented in context tracking system
- Main agent responsible for all implementation

---

## ADR-006: Session & Context Tracking System

**Date**: 2025-11-02
**Status**: ✅ Accepted
**Deciders**: User + Claude Code AI

### Context
Need to maintain context across Claude Code sessions and track decisions/changes over time.

### Decision
Create `.claude/tasks/` directory structure:
- `sessions/` - Conversation logs (date + topic naming)
- `context/` - Quick reference files (architecture, features, recent-work, decisions)

**Git-tracked**: All files committed to repository for team visibility.

### Consequences
**Positive**:
- Context preserved across sessions
- Easy onboarding for new team members
- Decision history documented
- Quick reference for Claude Code

**Negative**:
- Requires discipline to maintain
- Adds files to repository
- Need to update after significant work

### Alternatives Considered
- Local only (.gitignore): Team wouldn't benefit
- Wiki/separate docs: Would get out of sync
- No tracking: Would lose context

### Implementation
- `.claude/tasks/context/architecture.md`
- `.claude/tasks/context/features.md`
- `.claude/tasks/context/recent-work.md`
- `.claude/tasks/context/decisions.md` (this file)
- `.claude/tasks/sessions/YYYY-MM-DD_topic.md`
- CLAUDE.md updated with workflow rules

---

## ADR-007: Background Audio Configuration for iOS

**Date**: 2025-11-02
**Status**: ✅ Accepted
**Deciders**: Claude Code AI

### Context
Timer audio cues need to play when app is backgrounded on iOS. Default behavior stops audio when app isn't in foreground.

### Decision
Configure AVAudioSession for background playback:
1. Add "audio" to UIBackgroundModes in Info.plist
2. Set audio session category to `.playback`
3. Use `mixWithOthers` option to allow other apps' audio

### Consequences
**Positive**:
- Audio cues continue in background
- Doesn't interrupt music/podcasts
- Better user experience during practice

**Negative**:
- Increases battery usage slightly
- App appears in Control Center audio controls
- Must be justified in App Store review

### Alternatives Considered
- Local notifications with sound: Less precise timing
- Foreground-only: Bad UX for practitioners
- Silent mode: Defeats purpose of audio cues

### Implementation
- `app/ios/Runner/Info.plist`: UIBackgroundModes
- `app/lib/services/audio_service.dart`: AudioContext configuration

---

## Template for New ADRs

```markdown
## ADR-XXX: Title

**Date**: YYYY-MM-DD
**Status**: ✅ Accepted / ⏳ Proposed / ❌ Rejected / 🔄 Superseded
**Deciders**: Who made this decision

### Context
What is the issue we're addressing?

### Decision
What did we decide?

### Consequences
**Positive**:
- Good thing 1
- Good thing 2

**Negative**:
- Trade-off 1
- Trade-off 2

### Alternatives Considered
- Option A: Why not
- Option B: Why not

### Implementation
- File 1: What changed
- File 2: What changed
```

---

*Add new ADRs at the bottom. Keep numbering sequential. Update status as decisions evolve.*
