# Architecture Overview

## Tech Stack

### Frontend: Flutter
- **Framework**: Flutter (Dart)
- **Platforms**: iOS, Android, Web (single codebase)
- **UI**: Material Design with custom theming
- **Primary Color**: #9B1C1C (Xuan Gong burgundy)
- **State Management**: StatefulWidgets (simple approach for MVP)
- **Navigation**: MaterialPageRoute

### Backend: Go + PostgreSQL
- **Language**: Go
- **Database**: PostgreSQL
- **Authentication**: JWT tokens
- **API Style**: RESTful
- **Storage**: flutter_secure_storage for tokens

### Deployment

#### Backend
- **Container**: Docker
- **Orchestration**: Kubernetes (Helm charts)
- **Database**: PostgreSQL pod with persistent volume
- **Environment**: Production on Kubernetes cluster

#### Frontend (Web)
- **Build**: Flutter web release build
- **Server**: nginx (Alpine-based)
- **Container**: Multi-stage Docker build
  1. Build stage: Flutter builder
  2. Production stage: nginx serving static files
- **Configuration**: Runtime API URL injection via envsubst
- **Security**: Non-root nginx user (uid 101)
- **Port**: 8080 (non-privileged)

## Key Architectural Patterns

### Singleton Services
All services use singleton pattern:
- `AudioService` - Audio playback
- `NotificationService` - Push notifications
- `AuthService` - Authentication
- `ProgramService` - Program management
- `SessionService` - Session tracking

**Pattern**:
```dart
class MyService {
  static final MyService _instance = MyService._internal();
  factory MyService() => _instance;
  MyService._internal();
}
```

### Platform-Specific Code
Using conditional imports for platform differences:
```dart
import 'api_config_stub.dart'
    if (dart.library.html) 'api_config_web.dart';
```

- **Stub**: Mobile implementations (iOS/Android)
- **Web**: Web-specific implementations (dart:html)

### Service Layer Architecture
```
Screens → Services → API Client → Backend
          ↓
       Local Storage
```

## File Organization

### Flutter App Structure
```
lib/
├── config/           # Configuration (API URLs, constants)
├── models/           # Data models (User, Program, Exercise, Session)
├── screens/          # UI screens (17 total)
├── services/         # Business logic services
├── widgets/          # Reusable UI components
└── main.dart         # App entry point
```

### Backend Structure
```
backend/
├── cmd/              # Entry points (api, seed)
├── internal/         # Internal packages
│   ├── handlers/     # HTTP handlers
│   ├── middleware/   # Auth, logging, etc.
│   ├── models/       # Domain models
│   ├── repositories/ # Data access
│   └── services/     # Business logic
├── migrations/       # Database migrations
└── pkg/              # Public packages
```

## Runtime Configuration

### Web App API URL Injection
1. **Build time**: Flutter build embeds `$API_URL` placeholder in index.html
2. **Container startup**: Docker entrypoint script runs envsubst
3. **Runtime**: JavaScript reads from localStorage, Dart reads from localStorage
4. **ConfigMap**: Kubernetes injects actual API URL via environment variable

### Mobile App API URLs
- **iOS Simulator**: http://localhost:8080
- **Android Emulator**: http://10.0.2.2:8080 (host's localhost)
- **Production**: Would use actual backend URL

## Background Processing

### iOS
- **Audio**: Background audio session (AVAudioSessionCategory.playback)
- **Notifications**: Local notifications with live updates
- **Background modes**: Audio mode enabled in Info.plist

### Android
- **Wake Lock**: Keep screen on during practice
- **Foreground Service**: Background notifications
- **Permissions**: WAKE_LOCK, FOREGROUND_SERVICE, POST_NOTIFICATIONS

### Web
- **Wake Lock**: Browser Wake Lock API
- **Background**: Timer continues in background tabs
- **Notifications**: Not supported (gracefully skipped)

## Key Technologies

### Flutter Packages
- `http`: API requests
- `flutter_secure_storage`: Token storage
- `shared_preferences`: Simple key-value storage
- `audioplayers`: Audio playback
- `wakelock_plus`: Keep screen on
- `flutter_local_notifications`: Background notifications
- `table_calendar`: Calendar view
- `intl`: Date formatting

### Go Packages
- `gorilla/mux`: HTTP routing
- `lib/pq`: PostgreSQL driver
- `golang-jwt`: JWT authentication
- `bcrypt`: Password hashing

## Security Considerations

1. **JWT Authentication**: Tokens stored in secure storage
2. **Non-root containers**: Both frontend and backend run as non-root
3. **HTTPS**: TLS termination at ingress (Let's Encrypt)
4. **CORS**: Configured in backend API
5. **Password hashing**: bcrypt for user passwords

## Performance Optimizations

1. **Audio Pre-caching**: Sounds loaded at service initialization
2. **Singleton Services**: Avoid repeated initialization
3. **nginx gzip**: Compression for web assets
4. **Image optimization**: PWA icons in multiple sizes
5. **Code splitting**: (Future) For web app

## Development Tools

- **Flutter SDK**: Latest stable
- **Docker**: Multi-stage builds
- **Kubernetes**: Helm charts for deployment
- **Make**: Build automation (Makefiles in app/ and backend/)
- **Git**: Version control

## Monitoring & Observability

Currently minimal (MVP phase):
- Backend logs to stdout
- Frontend logs to browser console / device logs
- Kubernetes pod logs via `kubectl logs`

Future: Add proper logging, metrics, and error tracking.
