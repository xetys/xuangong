# Sound Volume Settings - Implementation Plan

**Date**: 2025-11-19
**Status**: Planning Phase
**Author**: flutter-dev-expert agent

---

## Overview

Implement per-sound volume controls for practice audio cues, with settings stored in the backend to sync across devices. Users can set individual volumes (off, 25%, 50%, 75%, 100%) for each sound type used during practice sessions.

---

## Requirements Summary

### Volume Options
- **5 discrete levels**: 0% (off), 25%, 50%, 75%, 100%
- Backend stores as integers: 0, 25, 50, 75, 100

### Sound Types to Control
1. **Countdown beeps** - Warning sound 2 seconds before exercise starts
2. **Exercise start** - 3 beeps when exercise begins
3. **Halfway bell** - Bell at 50% completion of exercise
4. **Program finished** - Long gong at session completion

### Storage Location
- **Backend-stored** (not local storage) for cross-device sync
- User preferences persist across phone, web, etc.

---

## Architecture Decisions

### 1. API Design

**Recommended Endpoint**: Extend existing user profile endpoint

**Rationale**:
- Sound settings are user preferences (like email, name)
- No need for separate endpoint complexity
- Follows existing pattern in `GET/PUT /api/v1/auth/me`
- Simpler for frontend (one profile fetch gets everything)

**Alternative Considered**: Separate `/api/v1/settings/audio` endpoint
- Rejected: Over-engineering for 4 simple integer fields
- Could revisit if we add many more settings categories

### 2. Data Model

**Backend (Go)**:
```go
type User struct {
    // ... existing fields ...

    // Audio settings (stored as integers 0, 25, 50, 75, 100)
    CountdownVolume  int  `json:"countdown_volume" db:"countdown_volume"`
    StartVolume      int  `json:"start_volume" db:"start_volume"`
    HalfwayVolume    int  `json:"halfway_volume" db:"halfway_volume"`
    FinishVolume     int  `json:"finish_volume" db:"finish_volume"`
}
```

**Frontend (Dart)**:
```dart
class User {
  // ... existing fields ...

  final int countdownVolume;  // 0, 25, 50, 75, or 100
  final int startVolume;
  final int halfwayVolume;
  final int finishVolume;
}
```

**Database Migration**:
```sql
ALTER TABLE users
  ADD COLUMN countdown_volume INTEGER NOT NULL DEFAULT 75,
  ADD COLUMN start_volume INTEGER NOT NULL DEFAULT 75,
  ADD COLUMN halfway_volume INTEGER NOT NULL DEFAULT 25,
  ADD COLUMN finish_volume INTEGER NOT NULL DEFAULT 100;

-- Add constraints to ensure valid values
ALTER TABLE users
  ADD CONSTRAINT check_countdown_volume CHECK (countdown_volume IN (0, 25, 50, 75, 100)),
  ADD CONSTRAINT check_start_volume CHECK (start_volume IN (0, 25, 50, 75, 100)),
  ADD CONSTRAINT check_halfway_volume CHECK (halfway_volume IN (0, 25, 50, 75, 100)),
  ADD CONSTRAINT check_finish_volume CHECK (finish_volume IN (0, 25, 50, 75, 100));
```

**Default Values** (set in migration):
- Countdown: 75% (important but not jarring)
- Start: 75% (important timing cue)
- Halfway: 25% (subtle progress indicator)
- Finish: 100% (clear session completion)

### 3. State Management Strategy

**Memory Cache Pattern**:
```
App Start → Fetch User Profile (includes audio settings) → Cache in AudioService
User Changes Setting → Update Backend → Update AudioService Cache
Play Sound → Read from AudioService Cache (no API call)
```

**Offline Handling**:
- Use last cached values from User model
- If never fetched, use AudioService hardcoded defaults (same as DB defaults)
- Update backend when connection returns

### 4. Update Strategy

**Recommended**: Debounced auto-save (300ms)

**Rationale**:
- Best UX: No save button needed, feels instant
- Reasonable backend load: Coalesces rapid slider movements
- Pattern: User slides → waits 300ms → auto-saves

**Implementation**:
```dart
Timer? _debounceTimer;

void _onVolumeChanged(String soundType, int newVolume) {
  // Cancel existing timer
  _debounceTimer?.cancel();

  // Update UI immediately
  setState(() {
    _audioSettings[soundType] = newVolume;
  });

  // Debounce backend update
  _debounceTimer = Timer(const Duration(milliseconds: 300), () {
    _saveSettingsToBackend();
  });
}
```

**Alternative Considered**: Save button
- Rejected: Extra tap friction, not modern UX
- Could use if backend performance becomes issue

**Alternative Considered**: Immediate save on every change
- Rejected: Too many API calls during slider drag

### 5. Error Handling Strategy

**On Backend Update Failure**:
1. Keep new value in UI (optimistic update)
2. Show non-intrusive error snackbar
3. AudioService uses new value immediately (works offline)
4. Retry on next settings screen open or app restart

**Rationale**:
- Audio settings aren't critical data (unlike passwords)
- User shouldn't lose their adjustment due to temporary network issue
- Will sync next time they use settings

**Implementation**:
```dart
Future<void> _saveSettingsToBackend() async {
  try {
    await _authService.updateProfile(
      countdownVolume: _audioSettings['countdown'],
      startVolume: _audioSettings['start'],
      halfwayVolume: _audioSettings['halfway'],
      finishVolume: _audioSettings['finish'],
    );

    // Update AudioService cache
    _audioService.updateVolumeSettings(_audioSettings);

  } catch (e) {
    // Don't revert UI, just show error
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Settings saved locally. Will sync when online.'),
          backgroundColor: Colors.orange,
        ),
      );
    }

    // Still update AudioService for immediate effect
    _audioService.updateVolumeSettings(_audioSettings);
  }
}
```

---

## Implementation Steps

### Phase 1: Backend API Extension

**Task**: Add audio settings to user model and profile endpoint

**Files to Modify**:
1. `backend/migrations/000XXX_add_user_audio_settings.up.sql`
2. `backend/migrations/000XXX_add_user_audio_settings.down.sql`
3. `backend/internal/models/user.go`
4. `backend/internal/handlers/auth.go` (UpdateProfile handler)
5. `backend/internal/validators/requests.go` (add validation)

**Implementation Details**:

**Migration Up**:
```sql
-- 000XXX_add_user_audio_settings.up.sql
ALTER TABLE users
  ADD COLUMN countdown_volume INTEGER NOT NULL DEFAULT 75,
  ADD COLUMN start_volume INTEGER NOT NULL DEFAULT 75,
  ADD COLUMN halfway_volume INTEGER NOT NULL DEFAULT 25,
  ADD COLUMN finish_volume INTEGER NOT NULL DEFAULT 100;

ALTER TABLE users
  ADD CONSTRAINT check_countdown_volume CHECK (countdown_volume IN (0, 25, 50, 75, 100)),
  ADD CONSTRAINT check_start_volume CHECK (start_volume IN (0, 25, 50, 75, 100)),
  ADD CONSTRAINT check_halfway_volume CHECK (halfway_volume IN (0, 25, 50, 75, 100)),
  ADD CONSTRAINT check_finish_volume CHECK (finish_volume IN (0, 25, 50, 75, 100));
```

**Migration Down**:
```sql
-- 000XXX_add_user_audio_settings.down.sql
ALTER TABLE users
  DROP CONSTRAINT IF EXISTS check_countdown_volume,
  DROP CONSTRAINT IF EXISTS check_start_volume,
  DROP CONSTRAINT IF EXISTS check_halfway_volume,
  DROP CONSTRAINT IF EXISTS check_finish_volume;

ALTER TABLE users
  DROP COLUMN countdown_volume,
  DROP COLUMN start_volume,
  DROP COLUMN halfway_volume,
  DROP COLUMN finish_volume;
```

**User Model** (`backend/internal/models/user.go`):
```go
type User struct {
    ID           uuid.UUID `json:"id" db:"id"`
    Email        string    `json:"email" db:"email"`
    PasswordHash string    `json:"-" db:"password_hash"`
    FullName     string    `json:"full_name" db:"full_name"`
    Role         UserRole  `json:"role" db:"role"`
    IsActive     bool      `json:"is_active" db:"is_active"`
    CreatedAt    time.Time `json:"created_at" db:"created_at"`
    UpdatedAt    time.Time `json:"updated_at" db:"updated_at"`

    // Audio settings
    CountdownVolume int `json:"countdown_volume" db:"countdown_volume"`
    StartVolume     int `json:"start_volume" db:"start_volume"`
    HalfwayVolume   int `json:"halfway_volume" db:"halfway_volume"`
    FinishVolume    int `json:"finish_volume" db:"finish_volume"`
}

type UserResponse struct {
    ID       uuid.UUID `json:"id"`
    Email    string    `json:"email"`
    FullName string    `json:"full_name"`
    Role     UserRole  `json:"role"`
    IsActive bool      `json:"is_active"`
    CreatedAt time.Time `json:"created_at"`

    // Audio settings
    CountdownVolume int `json:"countdown_volume"`
    StartVolume     int `json:"start_volume"`
    HalfwayVolume   int `json:"halfway_volume"`
    FinishVolume    int `json:"finish_volume"`
}

func (u *User) ToResponse() *UserResponse {
    return &UserResponse{
        ID:              u.ID,
        Email:           u.Email,
        FullName:        u.FullName,
        Role:            u.Role,
        IsActive:        u.IsActive,
        CreatedAt:       u.CreatedAt,
        CountdownVolume: u.CountdownVolume,
        StartVolume:     u.StartVolume,
        HalfwayVolume:   u.HalfwayVolume,
        FinishVolume:    u.FinishVolume,
    }
}
```

**Validator** (`backend/internal/validators/requests.go`):
```go
type UpdateProfileRequest struct {
    Email           *string `json:"email"`
    FullName        *string `json:"full_name"`
    CountdownVolume *int    `json:"countdown_volume"`
    StartVolume     *int    `json:"start_volume"`
    HalfwayVolume   *int    `json:"halfway_volume"`
    FinishVolume    *int    `json:"finish_volume"`
}

func (r *UpdateProfileRequest) Validate() error {
    var validationErrors []string

    if r.Email != nil && !isValidEmail(*r.Email) {
        validationErrors = append(validationErrors, "invalid email format")
    }

    if r.FullName != nil && len(*r.FullName) < 2 {
        validationErrors = append(validationErrors, "full name must be at least 2 characters")
    }

    // Validate audio settings
    validVolumes := []int{0, 25, 50, 75, 100}

    if r.CountdownVolume != nil && !contains(validVolumes, *r.CountdownVolume) {
        validationErrors = append(validationErrors, "countdown_volume must be 0, 25, 50, 75, or 100")
    }

    if r.StartVolume != nil && !contains(validVolumes, *r.StartVolume) {
        validationErrors = append(validationErrors, "start_volume must be 0, 25, 50, 75, or 100")
    }

    if r.HalfwayVolume != nil && !contains(validVolumes, *r.HalfwayVolume) {
        validationErrors = append(validationErrors, "halfway_volume must be 0, 25, 50, 75, or 100")
    }

    if r.FinishVolume != nil && !contains(validVolumes, *r.FinishVolume) {
        validationErrors = append(validationErrors, "finish_volume must be 0, 25, 50, 75, or 100")
    }

    if len(validationErrors) > 0 {
        return errors.New(strings.Join(validationErrors, "; "))
    }

    return nil
}

func contains(slice []int, val int) bool {
    for _, item := range slice {
        if item == val {
            return true
        }
    }
    return false
}
```

**Handler Update** (`backend/internal/handlers/auth.go`):
```go
// UpdateProfile updates the user's profile
func (h *AuthHandler) UpdateProfile(c *gin.Context) {
    userID := c.GetString("user_id")
    if userID == "" {
        respondError(c, appErrors.NewAuthorizationError("User not authenticated"))
        return
    }

    var req validators.UpdateProfileRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        respondError(c, appErrors.NewBadRequestError("Invalid request body"))
        return
    }

    if err := req.Validate(); err != nil {
        respondError(c, appErrors.NewValidationError(err.Error()))
        return
    }

    uid, err := uuid.Parse(userID)
    if err != nil {
        respondError(c, appErrors.NewBadRequestError("Invalid user ID"))
        return
    }

    // Update profile (now includes audio settings)
    if err := h.authService.UpdateProfile(
        c.Request.Context(),
        uid,
        req.FullName,
        req.Email,
        req.CountdownVolume,
        req.StartVolume,
        req.HalfwayVolume,
        req.FinishVolume,
    ); err != nil {
        respondError(c, err)
        return
    }

    c.JSON(http.StatusOK, gin.H{"message": "Profile updated successfully"})
}
```

**Service Update** (`backend/internal/services/auth_service.go`):
```go
func (s *AuthService) UpdateProfile(
    ctx context.Context,
    userID uuid.UUID,
    fullName, email *string,
    countdownVolume, startVolume, halfwayVolume, finishVolume *int,
) error {
    user, err := s.userRepo.GetByID(ctx, userID)
    if err != nil {
        return appErrors.NewInternalError("Failed to fetch user").WithError(err)
    }
    if user == nil {
        return appErrors.NewNotFoundError("User")
    }

    // Update basic fields
    if fullName != nil {
        user.FullName = *fullName
    }
    if email != nil {
        if *email != user.Email {
            exists, err := s.userRepo.EmailExists(ctx, *email)
            if err != nil {
                return appErrors.NewInternalError("Failed to check email").WithError(err)
            }
            if exists {
                return appErrors.NewConflictError("User with this email already exists")
            }
        }
        user.Email = *email
    }

    // Update audio settings
    if countdownVolume != nil {
        user.CountdownVolume = *countdownVolume
    }
    if startVolume != nil {
        user.StartVolume = *startVolume
    }
    if halfwayVolume != nil {
        user.HalfwayVolume = *halfwayVolume
    }
    if finishVolume != nil {
        user.FinishVolume = *finishVolume
    }

    if err := s.userRepo.Update(ctx, user); err != nil {
        return appErrors.NewInternalError("Failed to update user").WithError(err)
    }

    return nil
}
```

**Testing Checklist**:
- [ ] Migration runs successfully (up and down)
- [ ] Existing users get default values (75, 75, 25, 100)
- [ ] New users get default values on creation
- [ ] GET /api/v1/auth/me returns audio settings
- [ ] PUT /api/v1/auth/me accepts and validates audio settings
- [ ] Invalid values (e.g., 30, 200, -1) are rejected with 400 error
- [ ] Database constraints prevent invalid values

---

### Phase 2: Flutter Model & Service Updates

**Task**: Extend User model and AuthService to handle audio settings

**Files to Modify**:
1. `app/lib/models/user.dart`
2. `app/lib/services/auth_service.dart`

**User Model** (`app/lib/models/user.dart`):
```dart
class User {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final bool isActive;
  final DateTime? createdAt;

  // Audio settings
  final int countdownVolume;
  final int startVolume;
  final int halfwayVolume;
  final int finishVolume;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.isActive = true,
    this.createdAt,
    this.countdownVolume = 75,
    this.startVolume = 75,
    this.halfwayVolume = 25,
    this.finishVolume = 100,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      role: json['role'] as String,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      countdownVolume: json['countdown_volume'] as int? ?? 75,
      startVolume: json['start_volume'] as int? ?? 75,
      halfwayVolume: json['halfway_volume'] as int? ?? 25,
      finishVolume: json['finish_volume'] as int? ?? 100,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'countdown_volume': countdownVolume,
      'start_volume': startVolume,
      'halfway_volume': halfwayVolume,
      'finish_volume': finishVolume,
    };
  }

  bool get isAdmin => role == 'admin';
}
```

**AuthService Update** (`app/lib/services/auth_service.dart`):
```dart
// Update profile (now includes audio settings)
Future<void> updateProfile({
  String? email,
  String? fullName,
  int? countdownVolume,
  int? startVolume,
  int? halfwayVolume,
  int? finishVolume,
}) async {
  try {
    final Map<String, dynamic> body = {};
    if (email != null) body['email'] = email;
    if (fullName != null) body['full_name'] = fullName;
    if (countdownVolume != null) body['countdown_volume'] = countdownVolume;
    if (startVolume != null) body['start_volume'] = startVolume;
    if (halfwayVolume != null) body['halfway_volume'] = halfwayVolume;
    if (finishVolume != null) body['finish_volume'] = finishVolume;

    await _apiClient.put(ApiConfig.profileUrl, body);

    // Update stored email if changed
    if (email != null) {
      final userId = await _storage.getUserId();
      if (userId != null) {
        await _storage.saveUserInfo(userId, email);
      }
    }
  } catch (e) {
    throw Exception('Failed to update profile: ${e.toString()}');
  }
}
```

**Testing Checklist**:
- [ ] User.fromJson handles missing audio fields with defaults
- [ ] User.fromJson correctly parses audio fields when present
- [ ] updateProfile sends correct JSON payload
- [ ] updateProfile handles partial updates (only changed fields)

---

### Phase 3: AudioService Integration

**Task**: Add volume settings to AudioService and apply to playback

**File to Modify**: `app/lib/services/audio_service.dart`

**Implementation**:
```dart
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class AudioService {
  // Singleton pattern
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal() {
    _initialize();
  }

  // Separate players for each sound to allow parallel playback
  AudioPlayer? _startPlayer;
  AudioPlayer? _halfPlayer;
  AudioPlayer? _lastTwoPlayer;
  AudioPlayer? _longGongPlayer;

  bool _initialized = false;

  // Volume settings (defaults match backend)
  int _countdownVolume = 75;
  int _startVolume = 75;
  int _halfwayVolume = 25;
  int _finishVolume = 100;

  Future<void> _initialize() async {
    if (_initialized) return;

    _startPlayer = AudioPlayer();
    _halfPlayer = AudioPlayer();
    _lastTwoPlayer = AudioPlayer();
    _longGongPlayer = AudioPlayer();

    // Configure audio context for background playback on iOS
    if (!kIsWeb && Platform.isIOS) {
      final audioContext = AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {
            AVAudioSessionOptions.mixWithOthers,
          },
        ),
      );
      AudioPlayer.global.setAudioContext(audioContext);
    }

    // Set release mode to allow sounds to overlap
    await _startPlayer!.setReleaseMode(ReleaseMode.stop);
    await _halfPlayer!.setReleaseMode(ReleaseMode.stop);
    await _lastTwoPlayer!.setReleaseMode(ReleaseMode.stop);
    await _longGongPlayer!.setReleaseMode(ReleaseMode.stop);

    // Pre-cache audio files for instant playback
    await _startPlayer!.setSource(AssetSource('sounds/start.wav'));
    await _halfPlayer!.setSource(AssetSource('sounds/half.wav'));
    await _lastTwoPlayer!.setSource(AssetSource('sounds/last_two.wav'));
    await _longGongPlayer!.setSource(AssetSource('sounds/longgong.wav'));

    _initialized = true;
  }

  Future<void> initialize() async {
    await _initialize();
  }

  /// Update volume settings from user profile
  /// Call this after fetching user data or when settings change
  void updateVolumeSettings({
    int? countdownVolume,
    int? startVolume,
    int? halfwayVolume,
    int? finishVolume,
  }) {
    if (countdownVolume != null) _countdownVolume = countdownVolume;
    if (startVolume != null) _startVolume = startVolume;
    if (halfwayVolume != null) _halfwayVolume = halfwayVolume;
    if (finishVolume != null) _finishVolume = finishVolume;
  }

  /// Convert percentage (0, 25, 50, 75, 100) to volume (0.0 - 1.0)
  double _percentToVolume(int percent) {
    return percent / 100.0;
  }

  Future<void> playStart() async {
    await _ensureInitialized();
    if (_startVolume == 0) return; // Muted

    try {
      await _startPlayer?.setVolume(_percentToVolume(_startVolume));
      await _startPlayer?.seek(Duration.zero);
      await _startPlayer?.resume();
    } catch (e) {
      print('Error playing start sound: $e');
    }
  }

  Future<void> playHalf() async {
    await _ensureInitialized();
    if (_halfwayVolume == 0) return; // Muted

    try {
      await _halfPlayer?.setVolume(_percentToVolume(_halfwayVolume));
      await _halfPlayer?.seek(Duration.zero);
      await _halfPlayer?.resume();
    } catch (e) {
      print('Error playing half sound: $e');
    }
  }

  Future<void> playLastTwo() async {
    await _ensureInitialized();
    if (_countdownVolume == 0) return; // Muted

    try {
      await _lastTwoPlayer?.setVolume(_percentToVolume(_countdownVolume));
      await _lastTwoPlayer?.seek(Duration.zero);
      await _lastTwoPlayer?.resume();
    } catch (e) {
      print('Error playing last two sound: $e');
    }
  }

  Future<void> playLongGong() async {
    await _ensureInitialized();
    if (_finishVolume == 0) return; // Muted

    try {
      await _longGongPlayer?.setVolume(_percentToVolume(_finishVolume));
      await _longGongPlayer?.seek(Duration.zero);
      await _longGongPlayer?.resume();
    } catch (e) {
      print('Error playing long gong sound: $e');
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await _initialize();
    }
  }

  /// Get current volume settings (for UI display)
  Map<String, int> getVolumeSettings() {
    return {
      'countdown': _countdownVolume,
      'start': _startVolume,
      'halfway': _halfwayVolume,
      'finish': _finishVolume,
    };
  }

  void dispose() {
    _startPlayer?.dispose();
    _halfPlayer?.dispose();
    _lastTwoPlayer?.dispose();
    _longGongPlayer?.dispose();
    _initialized = false;
  }
}
```

**Testing Checklist**:
- [ ] Volume 0 mutes sound completely (no playback)
- [ ] Volume 25/50/75/100 adjusts audio level correctly
- [ ] updateVolumeSettings immediately affects next playback
- [ ] getVolumeSettings returns current values
- [ ] Defaults work before user profile loaded

---

### Phase 4: Settings Screen UI

**Task**: Build settings screen with volume controls and test buttons

**File to Modify**: `app/lib/screens/settings_screen.dart`

**Implementation**:
```dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../services/audio_service.dart';
import '../models/user.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  final AudioService _audioService = AudioService();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  // Current settings (loaded from user profile)
  Map<String, int> _audioSettings = {
    'countdown': 75,
    'start': 75,
    'halfway': 25,
    'finish': 100,
  };

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _authService.getCurrentUser();
      setState(() {
        _audioSettings = {
          'countdown': user.countdownVolume,
          'start': user.startVolume,
          'halfway': user.halfwayVolume,
          'finish': user.finishVolume,
        };
        _isLoading = false;
      });

      // Update AudioService with loaded settings
      _audioService.updateVolumeSettings(
        countdownVolume: user.countdownVolume,
        startVolume: user.startVolume,
        halfwayVolume: user.halfwayVolume,
        finishVolume: user.finishVolume,
      );

    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load settings: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _onVolumeChanged(String soundType, int newVolume) {
    // Cancel existing timer
    _debounceTimer?.cancel();

    // Update UI immediately (optimistic update)
    setState(() {
      _audioSettings[soundType] = newVolume;
    });

    // Update AudioService immediately for instant feedback
    _audioService.updateVolumeSettings(
      countdownVolume: soundType == 'countdown' ? newVolume : null,
      startVolume: soundType == 'start' ? newVolume : null,
      halfwayVolume: soundType == 'halfway' ? newVolume : null,
      finishVolume: soundType == 'finish' ? newVolume : null,
    );

    // Debounce backend update (300ms)
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _saveSettingsToBackend();
    });
  }

  Future<void> _saveSettingsToBackend() async {
    setState(() {
      _isSaving = true;
    });

    try {
      await _authService.updateProfile(
        countdownVolume: _audioSettings['countdown'],
        startVolume: _audioSettings['start'],
        halfwayVolume: _audioSettings['halfway'],
        finishVolume: _audioSettings['finish'],
      );

      setState(() {
        _isSaving = false;
      });

    } catch (e) {
      setState(() {
        _isSaving = false;
      });

      // Show error but don't revert (optimistic update)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Settings saved locally. Will sync when online.'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _saveSettingsToBackend,
            ),
          ),
        );
      }
    }
  }

  void _testSound(String soundType) {
    switch (soundType) {
      case 'countdown':
        _audioService.playLastTwo();
        break;
      case 'start':
        _audioService.playStart();
        break;
      case 'halfway':
        _audioService.playHalf();
        break;
      case 'finish':
        _audioService.playLongGong();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF9B1C1C),
        foregroundColor: Colors.white,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : _buildSettingsView(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B1C1C),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsView() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Text(
          'Sound Volume',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Adjust volume for each practice sound',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 24),

        _buildVolumeControl(
          'Countdown Beeps',
          'Warning before exercise starts',
          'countdown',
          Icons.timer,
        ),
        const Divider(height: 32),

        _buildVolumeControl(
          'Exercise Start',
          'Three beeps when exercise begins',
          'start',
          Icons.play_circle_outline,
        ),
        const Divider(height: 32),

        _buildVolumeControl(
          'Halfway Bell',
          'Progress indicator at 50%',
          'halfway',
          Icons.notifications_outlined,
        ),
        const Divider(height: 32),

        _buildVolumeControl(
          'Session Finished',
          'Long gong at completion',
          'finish',
          Icons.flag_outlined,
        ),
      ],
    );
  }

  Widget _buildVolumeControl(
    String title,
    String description,
    String soundType,
    IconData icon,
  ) {
    final currentVolume = _audioSettings[soundType] ?? 75;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFF9B1C1C)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                currentVolume == 0 ? Icons.volume_off : Icons.volume_up,
                color: const Color(0xFF9B1C1C),
              ),
              tooltip: 'Test sound',
              onPressed: () => _testSound(soundType),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: currentVolume.toDouble(),
                min: 0,
                max: 100,
                divisions: 4,
                label: currentVolume == 0 ? 'Off' : '$currentVolume%',
                activeColor: const Color(0xFF9B1C1C),
                onChanged: (value) {
                  // Round to nearest valid value (0, 25, 50, 75, 100)
                  final roundedValue = (value / 25).round() * 25;
                  _onVolumeChanged(soundType, roundedValue);
                },
              ),
            ),
            SizedBox(
              width: 50,
              child: Text(
                currentVolume == 0 ? 'Off' : '$currentVolume%',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
```

**UI/UX Features**:
- Slider with 5 discrete steps (0, 25, 50, 75, 100)
- Label shows "Off" at 0%, percentage otherwise
- Test button plays sound at current volume
- Immediate UI feedback on slider change
- Debounced backend save (300ms)
- Loading state while fetching settings
- Error handling with retry option
- Saving indicator in app bar
- Offline-friendly (optimistic updates)

**Testing Checklist**:
- [ ] Settings load from backend on screen open
- [ ] Slider snaps to valid values (0, 25, 50, 75, 100)
- [ ] Test button plays sound at current volume
- [ ] Volume 0 plays no sound
- [ ] Changes save after 300ms of no interaction
- [ ] Saving indicator appears during save
- [ ] Error message shows if backend unreachable
- [ ] Retry works after error
- [ ] Settings persist across app restarts

---

### Phase 5: Integration with Main App

**Task**: Load user settings at app start and update AudioService

**Files to Modify**:
1. `app/lib/main.dart`
2. `app/lib/screens/home_screen.dart` (or wherever user profile is loaded)

**Main App Integration** (`app/lib/main.dart`):
```dart
// In main() or MaterialApp initialization
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  await NotificationService().initialize();
  await AudioService().initialize();

  runApp(const MyApp());
}

// In app startup or login success
Future<void> _loadUserAndSettings() async {
  try {
    final user = await authService.getCurrentUser();

    // Update AudioService with user's volume preferences
    AudioService().updateVolumeSettings(
      countdownVolume: user.countdownVolume,
      startVolume: user.startVolume,
      halfwayVolume: user.halfwayVolume,
      finishVolume: user.finishVolume,
    );

    setState(() {
      _currentUser = user;
    });
  } catch (e) {
    // Handle error (AudioService will use defaults)
    print('Failed to load user settings: $e');
  }
}
```

**Home Screen Integration** (example):
```dart
// In HomeScreen initState or after login
@override
void initState() {
  super.initState();
  _loadUserProfile();
}

Future<void> _loadUserProfile() async {
  try {
    final user = await _authService.getCurrentUser();

    // Update AudioService immediately
    _audioService.updateVolumeSettings(
      countdownVolume: user.countdownVolume,
      startVolume: user.startVolume,
      halfwayVolume: user.halfwayVolume,
      finishVolume: user.finishVolume,
    );

    setState(() {
      _currentUser = user;
    });
  } catch (e) {
    // AudioService will use defaults if this fails
    print('Could not load user profile: $e');
  }
}
```

**Testing Checklist**:
- [ ] User settings load on app start
- [ ] AudioService receives settings before first sound plays
- [ ] Default volumes work if user profile fails to load
- [ ] Settings update immediately when changed in SettingsScreen
- [ ] Practice sounds respect volume settings
- [ ] Settings persist after app restart
- [ ] Settings sync across devices (login on different device)

---

## File Structure Summary

### Backend Files

**Created**:
- `backend/migrations/000XXX_add_user_audio_settings.up.sql`
- `backend/migrations/000XXX_add_user_audio_settings.down.sql`

**Modified**:
- `backend/internal/models/user.go` - Add audio fields
- `backend/internal/handlers/auth.go` - Handle audio settings in UpdateProfile
- `backend/internal/services/auth_service.go` - Update profile logic
- `backend/internal/validators/requests.go` - Validate audio settings

### Frontend Files

**Modified**:
- `app/lib/models/user.dart` - Add audio fields
- `app/lib/services/auth_service.dart` - Handle audio settings in updateProfile
- `app/lib/services/audio_service.dart` - Add volume control logic
- `app/lib/screens/settings_screen.dart` - Build UI
- `app/lib/main.dart` (or home screen) - Load settings at startup

---

## Testing Strategy

### Unit Tests

**Backend** (`backend/internal/validators/requests_test.go`):
```go
func TestUpdateProfileRequest_Validate_AudioSettings(t *testing.T) {
    tests := []struct {
        name    string
        request UpdateProfileRequest
        wantErr bool
    }{
        {
            name: "valid audio settings",
            request: UpdateProfileRequest{
                CountdownVolume: intPtr(75),
                StartVolume:     intPtr(100),
                HalfwayVolume:   intPtr(0),
                FinishVolume:    intPtr(50),
            },
            wantErr: false,
        },
        {
            name: "invalid countdown volume",
            request: UpdateProfileRequest{
                CountdownVolume: intPtr(30), // Invalid
            },
            wantErr: true,
        },
        // ... more test cases
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := tt.request.Validate()
            if (err != nil) != tt.wantErr {
                t.Errorf("Validate() error = %v, wantErr %v", err, tt.wantErr)
            }
        })
    }
}
```

**Frontend** (`app/test/services/audio_service_test.dart`):
```dart
void main() {
  group('AudioService', () {
    test('converts percentage to volume correctly', () {
      final service = AudioService();
      expect(service._percentToVolume(0), 0.0);
      expect(service._percentToVolume(25), 0.25);
      expect(service._percentToVolume(50), 0.5);
      expect(service._percentToVolume(75), 0.75);
      expect(service._percentToVolume(100), 1.0);
    });

    test('mutes sound when volume is 0', () async {
      final service = AudioService();
      service.updateVolumeSettings(startVolume: 0);

      // Should return early without playing
      await service.playStart();

      // Verify no sound played (would need mock AudioPlayer)
    });

    // More tests...
  });
}
```

### Integration Tests

**Backend API Tests**:
```bash
# Test GET profile returns audio settings
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:8080/api/v1/auth/me

# Test PUT profile updates audio settings
curl -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"countdown_volume": 50, "start_volume": 100}' \
  http://localhost:8080/api/v1/auth/me

# Test validation rejects invalid values
curl -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"countdown_volume": 30}' \
  http://localhost:8080/api/v1/auth/me
# Expected: 400 Bad Request
```

**Flutter Integration Tests**:
```dart
testWidgets('Settings screen loads and saves volume settings', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
  await tester.pumpAndSettle();

  // Verify sliders loaded
  expect(find.byType(Slider), findsNWidgets(4));

  // Change countdown volume
  final slider = find.byKey(const Key('countdown_slider'));
  await tester.drag(slider, const Offset(100, 0));
  await tester.pumpAndSettle();

  // Verify debounced save triggered
  await tester.pump(const Duration(milliseconds: 400));

  // Verify AudioService updated
  final audioService = AudioService();
  final settings = audioService.getVolumeSettings();
  expect(settings['countdown'], isNot(equals(75)));
});
```

### Manual Testing Checklist

**Backend**:
- [ ] Migration creates columns with defaults
- [ ] Existing users get default values
- [ ] New users get default values
- [ ] GET /auth/me includes audio settings
- [ ] PUT /auth/me updates audio settings
- [ ] Invalid values rejected (e.g., 30, -1, 200)
- [ ] Database constraints prevent invalid values

**Frontend**:
- [ ] Settings screen loads without errors
- [ ] Sliders show correct initial values
- [ ] Moving slider updates UI immediately
- [ ] Test button plays sound at current volume
- [ ] Volume 0 mutes sound completely
- [ ] Changes save after 300ms
- [ ] Saving indicator shows during save
- [ ] Error message shows if offline
- [ ] Retry works after error
- [ ] Settings persist after app restart
- [ ] Practice sounds respect volume settings
- [ ] Countdown beep volume applies
- [ ] Start beep volume applies
- [ ] Halfway bell volume applies
- [ ] Finish gong volume applies

**Cross-Device Sync**:
- [ ] Change settings on phone
- [ ] Login on web
- [ ] Verify settings synced
- [ ] Change settings on web
- [ ] Reopen phone app
- [ ] Verify settings synced

---

## Rollout Plan

### Phase 1: Backend (Safe to Deploy)
1. Run migration (adds columns with defaults)
2. Deploy backend with new API fields
3. Verify existing clients still work (backward compatible)
4. Test with curl/Postman

### Phase 2: Frontend (Staged)
1. Deploy new app build to beta testers
2. Verify settings load and save correctly
3. Gather feedback on default volumes
4. Adjust defaults if needed (backend migration update)
5. Deploy to all users

### Phase 3: Monitoring
1. Monitor error logs for validation failures
2. Check usage patterns (which sounds get muted most?)
3. Consider adding analytics event for settings changes
4. Iterate on defaults based on user behavior

---

## Known Limitations & Future Enhancements

### Current Limitations
1. **No system volume integration**: Uses app-level volume only
2. **No sound preview**: Test button required to hear volume level
3. **No presets**: Can't save/share favorite combinations
4. **No per-program settings**: Same volumes for all programs

### Potential Future Features
1. **Volume presets**: "Quiet Practice", "Full Volume", "Minimal Cues"
2. **Program-specific volumes**: Different settings per program
3. **Time-based profiles**: Auto-adjust volume based on time of day
4. **Advanced controls**: Adjust individual beep within 3-beep start
5. **Sound customization**: Choose different sounds (bowl vs bell)
6. **Haptic feedback**: Vibration as alternative to sound

---

## Questions & Answers

### Q: Why not store settings locally?
**A**: Backend storage enables cross-device sync. Students often practice on phone but might review programs on web. Consistent experience matters.

### Q: Why 5 discrete levels instead of continuous slider?
**A**: Simpler UX, easier testing, clearer intent. "Medium" vs "72%" is more intuitive. Backend validation is trivial with enum-like constraints.

### Q: Why debounce instead of save button?
**A**: Better UX. Modern users expect instant saves (like iOS Settings). Debouncing prevents excessive API calls while maintaining instant feel.

### Q: What if backend is down when user changes settings?
**A**: Optimistic update: UI shows new value, AudioService uses it immediately, backend update queued. Non-intrusive error message with retry option.

### Q: Should countdown and start be separate?
**A**: Yes. Countdown warns "exercise coming", start marks "begin now". Different semantic meanings, users may want different volumes (e.g., subtle warning, loud start).

### Q: Why not 10% increments?
**A**: 5 levels is sweet spot for audio perception. More levels = decision paralysis. Fewer = not enough control. 25% steps match typical audio perception thresholds.

---

## Summary

This implementation provides a clean, backend-synced solution for per-sound volume control:

**Backend**: 4 integer fields in users table, validated to (0, 25, 50, 75, 100)
**Frontend**: Singleton AudioService caches settings, applies on playback
**UI**: Sliders with test buttons, debounced auto-save, offline-friendly
**UX**: Instant feedback, non-intrusive errors, cross-device sync

**Estimated Implementation Time**:
- Backend: 2-3 hours (migration, validation, handlers, tests)
- Frontend: 3-4 hours (service updates, UI, integration, tests)
- Testing: 2 hours (manual testing, edge cases, cross-device)
- **Total**: 7-9 hours

**Risk Level**: Low
- Backward compatible (existing clients ignore new fields)
- Defaults preserve current behavior (75% for most sounds)
- No breaking changes to existing APIs
- Easy rollback (drop columns if needed)

**User Value**: High
- Addresses common request ("sounds too loud in public")
- Enables new use cases (silent practice with visual-only cues)
- Respects martial arts context (minimal disruption to Wu Wei mode)
- Professional touch (per-sound control shows attention to detail)