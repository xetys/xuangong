# Keep Logged In Feature - Implementation Plan

**Date:** 2025-11-02
**Author:** flutter-dev-expert agent
**Status:** Ready for implementation

## Executive Summary

Implementation of persistent authentication ("keep logged in") for the Xuan Gong app. This is a standard Flutter pattern that validates stored JWT tokens on app startup and automatically navigates to the HomeScreen if valid.

## Current State Analysis

### Existing Infrastructure ✅
The app already has excellent foundations:

1. **Secure Token Storage** - Using `FlutterSecureStorage` (best practice)
2. **Clean Service Architecture** - Separation of concerns (AuthService, StorageService, ApiClient)
3. **JWT Authentication** - Standard token-based auth with access and refresh tokens
4. **Auth Methods Available**:
   - `isLoggedIn()` - Checks token existence
   - `getCurrentUser()` - Validates token and fetches user data
   - `logout()` - Clears storage

### Current Limitation
The `SplashScreen._checkAuthStatus()` (lines 103-118 in main.dart) currently:
- Checks `isLoggedIn()` but ignores the result
- Always navigates to `LoginScreen` (MVP behavior)
- Comment indicates intention: "In production, you'd fetch user data if logged in"

## Flutter Best Practices Review

### ✅ What's Already Good

1. **FlutterSecureStorage Usage**: Excellent choice for token storage
   - Platform-specific encryption (Keychain on iOS, KeyStore on Android)
   - Secure against root/jailbreak attacks
   - Industry standard for Flutter auth

2. **Singleton Pattern**: StorageService uses proper singleton pattern
   ```dart
   static final StorageService _instance = StorageService._internal();
   factory StorageService() => _instance;
   ```

3. **Mounted Check**: Proper use of `if (mounted)` before navigation
   ```dart
   if (mounted) {
     Navigator.of(context).pushReplacement(...)
   }
   ```

4. **Navigation Pattern**: Using `pushReplacement` (correct - prevents back navigation to splash)

5. **Async Initialization**: Proper `WidgetsFlutterBinding.ensureInitialized()` in main()

### ⚠️ Areas for Improvement

#### 1. Missing Token Refresh Logic
**Issue**: ApiClient (line 79-80) throws "Unauthorized" on 401, but doesn't attempt token refresh.

**Impact**: If access token expires but refresh token is still valid, user is forced to re-login unnecessarily.

**Recommendation**: Add token refresh interceptor to ApiClient. This is critical for "keep logged in" to work seamlessly.

#### 2. No Network Error Handling in SplashScreen
**Issue**: `getCurrentUser()` requires network. If offline or network fails, the auto-login flow will fail silently.

**Impact**: User stuck on splash screen or incorrectly sent to login even though they have valid tokens.

**Recommendation**: Implement offline detection and error handling with user-friendly messages.

#### 3. Lack of Token Expiry Checking
**Issue**: `isLoggedIn()` only checks token existence, not validity or expiration.

**Impact**: False positive - shows logged in but token is expired.

**Recommendation**: While JWT expiry should be checked server-side, we can decode the JWT client-side to fail fast before network call.

## Proposed Implementation

### Phase 1: Basic Auto-Login (Minimum Viable)

**File**: `/Users/dsteiman/Dev/stuff/xuangong/app/lib/main.dart`

**Changes to `_SplashScreenState._checkAuthStatus()`**:

```dart
Future<void> _checkAuthStatus() async {
  // Small delay for visual feedback
  await Future.delayed(const Duration(milliseconds: 500));

  final isLoggedIn = await _authService.isLoggedIn();

  if (!mounted) return;

  if (isLoggedIn) {
    // Token exists, try to fetch user data to validate it
    try {
      final user = await _authService.getCurrentUser();

      if (mounted) {
        // Token is valid, navigate to home
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => HomeScreen(user: user),
          ),
        );
      }
    } catch (e) {
      // Token is invalid or network error
      // Clear storage and go to login
      await _authService.logout();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        );
      }
    }
  } else {
    // No token, go to login
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
    );
  }
}
```

**Import Required**:
```dart
import 'screens/home_screen.dart'; // Add this import
```

**Pros**:
- Simple, straightforward implementation
- Leverages existing `getCurrentUser()` for validation
- Handles invalid tokens by clearing storage
- Minimal code changes (10-15 lines)

**Cons**:
- Requires network call on every app start
- No distinction between network error vs invalid token
- Could be slow on poor networks

### Phase 2: Enhanced Auto-Login (Recommended)

Addresses the cons above with:

#### 2A. Network Error Handling

```dart
Future<void> _checkAuthStatus() async {
  await Future.delayed(const Duration(milliseconds: 500));

  final isLoggedIn = await _authService.isLoggedIn();

  if (!mounted) return;

  if (isLoggedIn) {
    try {
      final user = await _authService.getCurrentUser();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => HomeScreen(user: user),
          ),
        );
      }
    } on SocketException {
      // Network error - keep user logged in and show offline message
      if (mounted) {
        final email = await _authService.getUserEmail();

        // Navigate to a simple offline-capable screen or show alert
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => OfflineHomeScreen(userEmail: email ?? 'User'),
          ),
        );
      }
    } on TimeoutException {
      // Similar to SocketException
      if (mounted) {
        _showNetworkErrorAndRetry();
      }
    } catch (e) {
      // Token invalid or other error - clear and go to login
      if (e.toString().contains('Unauthorized')) {
        await _authService.logout();
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        );
      }
    }
  } else {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
    );
  }
}

void _showNetworkErrorAndRetry() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Network Error'),
      content: const Text('Unable to verify your login. Please check your connection and try again.'),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _checkAuthStatus(); // Retry
          },
          child: const Text('RETRY'),
        ),
        TextButton(
          onPressed: () async {
            await _authService.logout();
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => const LoginScreen(),
                ),
              );
            }
          },
          child: const Text('LOGIN AGAIN'),
        ),
      ],
    ),
  );
}
```

**Additional imports needed**:
```dart
import 'dart:io'; // For SocketException
import 'dart:async'; // For TimeoutException
```

#### 2B. Token Refresh Interceptor

**File**: `/Users/dsteiman/Dev/stuff/xuangong/app/lib/services/api_client.dart`

This is more complex but essential for seamless "keep logged in" experience.

**Current Issue**: Line 79-80 throws on 401 without retry.

**Solution**: Add token refresh logic before throwing.

```dart
// Add new method to ApiClient
Future<http.Response> _retryWithRefresh(
  Future<http.Response> Function() request,
) async {
  final response = await request();

  // If unauthorized, try to refresh token
  if (response.statusCode == 401) {
    final refreshToken = await _storage.getRefreshToken();

    if (refreshToken != null) {
      try {
        // Call refresh token endpoint
        final refreshResponse = await http.post(
          Uri.parse(ApiConfig.refreshTokenUrl),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'refresh_token': refreshToken}),
        ).timeout(ApiConfig.timeout);

        if (refreshResponse.statusCode == 200) {
          final data = jsonDecode(refreshResponse.body);
          final tokens = data['tokens'] as Map<String, dynamic>;

          // Save new tokens
          await _storage.saveTokens(
            tokens['access_token'] as String,
            tokens['refresh_token'] as String,
          );

          // Retry original request with new token
          return await request();
        }
      } catch (e) {
        // Refresh failed, clear tokens
        await _storage.clearAll();
      }
    }
  }

  return response;
}

// Update GET method
Future<http.Response> get(String url, {bool requiresAuth = true}) async {
  return _retryWithRefresh(() async {
    final headers = await _getHeaders(includeAuth: requiresAuth);
    return await http
        .get(Uri.parse(url), headers: headers)
        .timeout(ApiConfig.timeout);
  });
}

// Apply same pattern to post(), put(), delete()
```

**Note**: This requires a refresh token endpoint in the backend. Check if this exists:
```dart
// Add to api_config.dart
static String get refreshTokenUrl => '$baseUrl/auth/refresh';
```

#### 2C. JWT Expiry Check (Optional Optimization)

**File**: `/Users/dsteiman/Dev/stuff/xuangong/app/lib/services/storage_service.dart`

**Benefit**: Avoid unnecessary network call if token is obviously expired.

```dart
import 'dart:convert';

// Add method to check if access token is expired
Future<bool> isTokenExpired() async {
  final token = await getAccessToken();
  if (token == null) return true;

  try {
    // JWT format: header.payload.signature
    final parts = token.split('.');
    if (parts.length != 3) return true;

    // Decode payload (base64url)
    final payload = parts[1];
    // Pad if necessary
    final normalized = base64Url.normalize(payload);
    final decoded = utf8.decode(base64Url.decode(normalized));
    final json = jsonDecode(decoded);

    // Check exp claim (unix timestamp)
    final exp = json['exp'] as int?;
    if (exp == null) return false; // No expiry claim

    final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    return DateTime.now().isAfter(expiry);
  } catch (e) {
    // If we can't parse, assume expired
    return true;
  }
}

// Update isLoggedIn
Future<bool> isLoggedIn() async {
  final token = await getAccessToken();
  if (token == null || token.isEmpty) return false;

  // Check if token is expired
  return !(await isTokenExpired());
}
```

**Caveat**: This is client-side check only. Server is source of truth. But it helps avoid network call for obviously expired tokens.

## User Experience Considerations

### Loading States

**Current**: Splash screen shows loading spinner for 500ms minimum.

**Recommendation**: Keep this. It provides visual feedback and prevents jarring flash of login screen.

**Enhancement**: Add subtle "Checking login..." text below spinner when verifying token:

```dart
// In SplashScreen build method
Column(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    Text(
      '玄功',
      style: TextStyle(
        fontSize: 64,
        fontWeight: FontWeight.w300,
        color: burgundy,
        letterSpacing: 8,
      ),
    ),
    const SizedBox(height: 24),
    const CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(burgundy),
    ),
    const SizedBox(height: 16),
    Text(
      'Loading...',
      style: TextStyle(
        fontSize: 14,
        color: Colors.grey.shade500,
        letterSpacing: 1,
      ),
    ),
  ],
)
```

### Error Messages

**Network Error**: Show retry option vs forcing re-login.

**Invalid Token**: Silent logout and redirect to login (current behavior in Phase 1 is good).

**Server Error**: Distinguish from auth errors. Don't clear tokens on 500 errors.

### Offline-First Consideration

Per project requirements (CLAUDE.md), the app must be offline-first for timer functions.

**Critical**: The HomeScreen requires network to load programs. This conflicts with offline-first.

**Recommendation**:
1. Implement Phase 2A network error handling
2. Consider caching User object locally so HomeScreen can render without network
3. Programs list should show cached data with "offline" indicator

**Future Enhancement**:
```dart
// Save user to local storage after successful login
await _storage.saveUserData(jsonEncode(user.toJson()));

// In SplashScreen, use cached user if network fails
if (isLoggedIn) {
  try {
    final user = await _authService.getCurrentUser();
    await _storage.saveUserData(jsonEncode(user.toJson()));
    // Navigate to HomeScreen...
  } catch (e) {
    // Try cached user
    final cachedUserData = await _storage.getUserData();
    if (cachedUserData != null) {
      final user = User.fromJson(jsonDecode(cachedUserData));
      // Navigate to HomeScreen with offline mode indicator
    }
  }
}
```

## Security Considerations

### ✅ What's Secure

1. **FlutterSecureStorage**: Excellent - uses platform encryption
2. **JWT Tokens**: Industry standard, tokens are opaque to client
3. **No Hardcoded Credentials**: Good separation via env/config

### ⚠️ Security Recommendations

#### 1. Token Storage - Already Secure ✅
FlutterSecureStorage is the right choice. No changes needed.

#### 2. Refresh Token Rotation
If implementing token refresh (Phase 2B), ensure backend rotates refresh tokens:
- Each refresh should issue new access + new refresh token
- Old refresh token should be invalidated
- Prevents token replay attacks

#### 3. Jailbreak/Root Detection (Future)
Consider adding in Phase 3:
```yaml
dependencies:
  flutter_jailbreak_detection: ^1.10.0
```

```dart
// In main() or SplashScreen
if (await FlutterJailbreakDetection.jailbroken) {
  // Show warning or disable secure features
}
```

#### 4. Certificate Pinning (Future)
For production, consider pinning API server certificate:
```yaml
dependencies:
  http_certificate_pinning: ^2.0.0
```

#### 5. Biometric Re-Authentication (Future)
For sensitive actions, add biometric check even when logged in:
```yaml
dependencies:
  local_auth: ^2.1.0
```

## Edge Cases to Handle

### 1. Token Expired During App Use
**Scenario**: User is logged in, leaves app, comes back after token expired.

**Current Behavior**: Next API call will fail with 401.

**Solution**: Phase 2B token refresh interceptor handles this automatically.

### 2. User Logs Out on Another Device
**Scenario**: User has app on phone and tablet. Logs out on phone. Opens tablet app.

**Current Behavior**: Tablet still shows logged in (local token exists).

**Solution**:
- Backend should invalidate token on logout
- Tablet will get 401 on next API call
- Phase 2B refresh will fail → auto logout

**Enhancement**: Implement token revocation list on backend.

### 3. Account Deleted While Logged In
**Scenario**: Admin deletes user account. User still has valid token.

**Current Behavior**: Depends on backend - likely 401 or 403.

**Solution**: Handle 403 same as 401 - logout and redirect to login.

### 4. Forced App Closure During Auth Check
**Scenario**: User kills app during `_checkAuthStatus()`.

**Current Behavior**: Process interrupted, no state corruption.

**Risk**: None - storage operations are atomic.

**Verification**: `mounted` checks prevent navigation after disposal.

### 5. Concurrent Token Refresh Requests
**Scenario**: Multiple API calls happen simultaneously, all get 401, all try to refresh.

**Risk**: Race condition - multiple refresh calls, only first succeeds.

**Solution**: Implement refresh token mutex:

```dart
// In ApiClient
bool _isRefreshing = false;
Completer<void>? _refreshCompleter;

Future<void> _refreshToken() async {
  // If already refreshing, wait for it
  if (_isRefreshing) {
    await _refreshCompleter?.future;
    return;
  }

  _isRefreshing = true;
  _refreshCompleter = Completer<void>();

  try {
    // Refresh logic here
    // ...
    _refreshCompleter!.complete();
  } catch (e) {
    _refreshCompleter!.completeError(e);
    rethrow;
  } finally {
    _isRefreshing = false;
    _refreshCompleter = null;
  }
}
```

## State Management Considerations

### Current: No State Management Library
The app uses **setState** and **InheritedWidget** (via MaterialApp).

**Analysis**: This is perfectly fine for current complexity.

### Do We Need State Management?

**For "Keep Logged In" Feature**: **No**

The current approach is appropriate:
- Auth state is managed by services (AuthService, StorageService)
- User object is passed via constructor to HomeScreen
- No complex auth state needs to be shared across deeply nested widgets

### When Would We Need It?

If you later implement:
1. **Global Auth State Subscription**: Multiple widgets need to react to logout
2. **Offline Queue Management**: Complex state for queued uploads
3. **Real-time Updates**: WebSocket connection state

### Recommended for Future (if needed): Riverpod

**Why Riverpod**:
- Compile-time safety (no runtime Provider errors)
- Better testability than Provider
- Simpler than Bloc for most use cases
- Good for async data fetching (FutureProvider, StreamProvider)
- Excellent for dependency injection

**Example Auth Provider**:
```dart
final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier(ref.read);
});

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  AuthNotifier(this._read) : super(const AsyncValue.loading()) {
    checkAuth();
  }

  final Reader _read;

  Future<void> checkAuth() async {
    state = const AsyncValue.loading();
    try {
      final user = await _read(authServiceProvider).getCurrentUser();
      state = AsyncValue.data(user);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
```

**But**: Don't add it now. Current approach is cleaner for this feature.

## Testing Recommendations

### Unit Tests

**File**: `test/services/auth_service_test.dart`

```dart
void main() {
  group('AuthService', () {
    late AuthService authService;
    late MockApiClient mockApiClient;
    late MockStorageService mockStorage;

    setUp(() {
      mockApiClient = MockApiClient();
      mockStorage = MockStorageService();
      authService = AuthService(
        apiClient: mockApiClient,
        storage: mockStorage,
      );
    });

    test('isLoggedIn returns true when token exists', () async {
      when(mockStorage.getAccessToken()).thenAnswer((_) async => 'token123');

      final result = await authService.isLoggedIn();

      expect(result, true);
    });

    test('getCurrentUser returns user when token valid', () async {
      when(mockApiClient.get(any)).thenAnswer((_) async =>
        http.Response('{"id":"1","email":"test@test.com"}', 200)
      );

      final user = await authService.getCurrentUser();

      expect(user.email, 'test@test.com');
    });

    test('getCurrentUser throws when token invalid', () async {
      when(mockApiClient.get(any)).thenAnswer((_) async =>
        http.Response('Unauthorized', 401)
      );

      expect(
        () => authService.getCurrentUser(),
        throwsA(isA<Exception>()),
      );
    });
  });
}
```

### Widget Tests

**File**: `test/widgets/splash_screen_test.dart`

```dart
void main() {
  group('SplashScreen', () {
    late MockAuthService mockAuthService;

    setUp(() {
      mockAuthService = MockAuthService();
    });

    testWidgets('navigates to HomeScreen when logged in', (tester) async {
      when(mockAuthService.isLoggedIn()).thenAnswer((_) async => true);
      when(mockAuthService.getCurrentUser()).thenAnswer((_) async =>
        User(id: '1', email: 'test@test.com', fullName: 'Test User')
      );

      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('navigates to LoginScreen when not logged in', (tester) async {
      when(mockAuthService.isLoggedIn()).thenAnswer((_) async => false);

      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('clears storage and goes to login on invalid token', (tester) async {
      when(mockAuthService.isLoggedIn()).thenAnswer((_) async => true);
      when(mockAuthService.getCurrentUser()).thenThrow(Exception('Unauthorized'));

      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
      await tester.pumpAndSettle();

      verify(mockAuthService.logout()).called(1);
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });
}
```

### Integration Tests

**File**: `integration_test/auth_flow_test.dart`

```dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('complete auth flow', (tester) async {
    await tester.pumpWidget(const MyApp());

    // Should start at login screen (no stored token)
    expect(find.byType(LoginScreen), findsOneWidget);

    // Login
    await tester.enterText(find.byType(TextField).first, 'test@test.com');
    await tester.enterText(find.byType(TextField).last, 'password123');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    // Should navigate to home
    expect(find.byType(HomeScreen), findsOneWidget);

    // Restart app
    await tester.restartAndRestore();

    // Should auto-login to home (token persisted)
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    // Logout
    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();

    // Should return to login
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
```

## Performance Considerations

### Token Validation Call on Every App Start

**Impact**: Adds ~200-500ms network latency to app startup.

**Acceptable?**: Yes, for several reasons:
1. Happens only once per app launch
2. Already have 500ms delay for visual feedback
3. Critical for security (validates token hasn't been revoked)
4. User expects some loading time on app start

**Optimization Options**:

#### Option A: Cache User Object (Recommended)
Store user data locally, display immediately, validate in background:

```dart
// Load cached user first
final cachedUser = await _storage.getCachedUser();
if (cachedUser != null) {
  // Navigate immediately
  Navigator.pushReplacement(...HomeScreen(user: cachedUser));

  // Validate in background
  _validateTokenInBackground();
}

Future<void> _validateTokenInBackground() async {
  try {
    final freshUser = await _authService.getCurrentUser();
    // Update home screen with fresh data
    _updateUserData(freshUser);
  } catch (e) {
    // Token invalid, logout
    await _authService.logout();
    Navigator.pushReplacement(...LoginScreen());
  }
}
```

**Pros**: Instant app start, better UX
**Cons**: Brief period where displayed data might be stale
**Trade-off**: Acceptable for user profile data (name, email don't change often)

#### Option B: Skip Validation, Rely on API Calls
Don't call `getCurrentUser()` in splash, just check token existence:

```dart
if (await _authService.isLoggedIn()) {
  // Navigate immediately, let HomeScreen's API calls validate token
  Navigator.pushReplacement(...HomeScreen());
}
```

**Pros**: Faster startup
**Cons**: Delayed error (user sees home screen briefly then kicked to login)
**Trade-off**: Poor UX, not recommended

**Recommendation**: Implement Option A in Phase 3 after Phase 1 is stable.

### Token Refresh Performance

Phase 2B token refresh adds overhead to every 401 response:
- Original request: ~200ms
- Refresh token call: ~200ms
- Retry request: ~200ms
- **Total**: ~600ms vs 200ms without refresh

**Acceptable?**: Yes, because:
1. Only happens when token expired (infrequent)
2. Alternative is forcing user to re-login (worse UX)
3. Can optimize by tracking token expiry client-side

**Optimization**: Schedule token refresh before expiry:

```dart
// In AuthService
Timer? _refreshTimer;

void _scheduleTokenRefresh(String accessToken) {
  _refreshTimer?.cancel();

  final expiry = _getTokenExpiry(accessToken);
  final refreshAt = expiry.subtract(const Duration(minutes: 5));
  final delay = refreshAt.difference(DateTime.now());

  if (delay.isNegative) return; // Already expired

  _refreshTimer = Timer(delay, () async {
    await _refreshAccessToken();
  });
}
```

## Recommended Implementation Sequence

### Sprint 1: Basic Auto-Login (2-3 hours)
1. ✅ Read existing code (DONE)
2. Implement Phase 1 changes to `_checkAuthStatus()`
3. Add import for HomeScreen
4. Test manual scenarios:
   - Fresh install → should go to login
   - After login → should go to home
   - Restart app → should go to home
   - Force token delete → should go to login
5. Commit with message: "Implement keep logged in feature"

**Deliverable**: Working auto-login, users stay logged in across app restarts.

### Sprint 2: Network Error Handling (3-4 hours)
1. Implement Phase 2A error handling
2. Add SocketException and TimeoutException imports
3. Add retry dialog
4. Test network scenarios:
   - Airplane mode startup
   - Slow 3G
   - Server timeout
5. Commit: "Add network error handling to auto-login"

**Deliverable**: Graceful handling of network issues during login check.

### Sprint 3: Token Refresh (6-8 hours)
1. Verify backend has refresh token endpoint
2. Add `refreshTokenUrl` to api_config.dart
3. Implement Phase 2B token refresh in ApiClient
4. Add mutex to prevent concurrent refreshes
5. Update all HTTP methods (get, post, put, delete)
6. Test scenarios:
   - Normal API call with valid token
   - API call with expired access token (should auto-refresh)
   - API call with expired refresh token (should logout)
7. Commit: "Add automatic token refresh"

**Deliverable**: Seamless token refresh, no unexpected logouts.

### Sprint 4: Testing & Polish (4-6 hours)
1. Write unit tests for AuthService
2. Write widget tests for SplashScreen
3. Write integration test for full auth flow
4. Add user data caching (Option A from Performance section)
5. Add loading text to splash screen
6. Commit: "Add auth flow tests and performance optimizations"

**Deliverable**: Comprehensive test coverage, production-ready feature.

## Code Changes Summary

### Files to Modify

1. **`/Users/dsteiman/Dev/stuff/xuangong/app/lib/main.dart`**
   - `_checkAuthStatus()` method (~30 lines)
   - Add import for HomeScreen
   - Optional: Add imports for SocketException, TimeoutException
   - Optional: Add retry dialog method

2. **`/Users/dsteiman/Dev/stuff/xuangong/app/lib/services/api_client.dart`** (Phase 2B)
   - Add `_retryWithRefresh()` method (~50 lines)
   - Update all HTTP methods to use retry logic (~20 lines)
   - Add mutex for concurrent refresh prevention (~30 lines)

3. **`/Users/dsteiman/Dev/stuff/xuangong/app/lib/config/api_config.dart`** (Phase 2B)
   - Add `refreshTokenUrl` getter (~1 line)

4. **`/Users/dsteiman/Dev/stuff/xuangong/app/lib/services/storage_service.dart`** (Optional)
   - Add `isTokenExpired()` method (~30 lines)
   - Add `saveUserData()` / `getUserData()` methods (~10 lines)
   - Update `isLoggedIn()` to check expiry (~5 lines)

### Estimated Total Lines of Code
- **Phase 1**: ~30 lines
- **Phase 2A**: ~60 lines
- **Phase 2B**: ~100 lines
- **Phase 2C**: ~45 lines
- **Tests**: ~200 lines

**Total**: ~435 lines for complete implementation with tests.

## Risk Assessment

| Risk | Severity | Likelihood | Mitigation |
|------|----------|------------|------------|
| Network timeout on startup | Medium | Medium | Phase 2A error handling + timeout dialog |
| Token refresh race condition | Medium | Low | Mutex implementation in Phase 2B |
| Stale cached user data | Low | High | Background validation (Option A) |
| Storage encryption failure | High | Very Low | FlutterSecureStorage handles this, no action needed |
| Backend refresh endpoint missing | High | Medium | Verify backend API before Phase 2B, fallback to current behavior |
| User stuck in login loop | Medium | Low | Proper error handling + logout on persistent 401 |

## Conclusion & Recommendation

### Recommended Approach: **Phase 1 + Phase 2A**

**Rationale**:
1. **Phase 1** provides immediate value (keep logged in functionality)
2. **Phase 2A** ensures robust network error handling (critical per offline-first requirements)
3. **Phase 2B** is valuable but requires backend coordination (implement after verifying refresh endpoint exists)
4. **Phase 2C** is optimization, not essential for MVP+1

**Estimated Effort**:
- Phase 1: 2-3 hours
- Phase 2A: 3-4 hours
- **Total: 5-7 hours for production-ready auto-login**

### Implementation Priority

**Must Have (Do Now)**:
- ✅ Phase 1: Basic auto-login

**Should Have (Do Next)**:
- ✅ Phase 2A: Network error handling
- ✅ Unit tests for AuthService

**Nice to Have (Do Later)**:
- Phase 2B: Token refresh (coordinate with backend)
- Phase 2C: JWT expiry checking
- Integration tests
- User data caching optimization

### Success Criteria

Feature is complete when:
1. ✅ User stays logged in after app restart
2. ✅ Invalid tokens are handled gracefully (logout + redirect)
3. ✅ Network errors show helpful message with retry option
4. ✅ No security vulnerabilities introduced
5. ✅ Code is tested (at minimum, unit tests)
6. ✅ No degradation in app startup performance

---

## Appendix: Exact Code for Phase 1

For the main implementation agent, here is the exact code to implement Phase 1:

### File: `/Users/dsteiman/Dev/stuff/xuangong/app/lib/main.dart`

**Add import** (around line 3, after existing imports):
```dart
import 'screens/home_screen.dart';
```

**Replace lines 103-118** (the `_checkAuthStatus` method) with:
```dart
Future<void> _checkAuthStatus() async {
  // Small delay for visual feedback
  await Future.delayed(const Duration(milliseconds: 500));

  final isLoggedIn = await _authService.isLoggedIn();

  if (!mounted) return;

  if (isLoggedIn) {
    // Token exists, try to fetch user data to validate it
    try {
      final user = await _authService.getCurrentUser();

      if (mounted) {
        // Token is valid, navigate to home
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => HomeScreen(user: user),
          ),
        );
      }
    } catch (e) {
      // Token is invalid or network error
      // Clear storage and go to login
      await _authService.logout();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        );
      }
    }
  } else {
    // No token, go to login
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
    );
  }
}
```

**That's it for Phase 1!**

The code:
- ✅ Checks for stored token
- ✅ Validates token by fetching user data
- ✅ Navigates to HomeScreen if valid
- ✅ Clears invalid tokens and goes to login
- ✅ Handles mounted state properly
- ✅ Uses existing services, no additional dependencies

**Testing checklist**:
1. Fresh install: App goes to LoginScreen ✓
2. Login with valid credentials: Goes to HomeScreen ✓
3. Close and reopen app: Goes directly to HomeScreen ✓
4. Manually delete token from device storage: Goes to LoginScreen ✓
5. Login with expired token: Clears token, goes to LoginScreen ✓

---

**End of Implementation Plan**