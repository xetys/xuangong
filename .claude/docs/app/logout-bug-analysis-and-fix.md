# Logout Bug Analysis & Implementation Plan

**Date**: 2025-11-05
**Issue**: After logout in production, app tries to connect to localhost instead of production API URL
**Severity**: Critical (prevents re-login after logout)

---

## Root Cause Analysis

### The Problem

1. **Production API URL storage**:
   - At app load, Docker entrypoint script injects `API_URL` via `/docker-entrypoint.d/40-envsubst-index.sh`
   - JavaScript in `app/web/index.html:42-45` reads this and stores in `localStorage['API_URL']`
   - `api_config_web.dart:7` reads `localStorage['API_URL']` to get the API endpoint

2. **Logout behavior**:
   - `AuthService.logout()` (line 41-51) calls `StorageService.clearAll()`
   - `StorageService.clearAll()` (line 49-51) calls `FlutterSecureStorage.deleteAll()`
   - **CRITICAL BUG**: On web, FlutterSecureStorage uses localStorage as its backend
   - `deleteAll()` wipes ALL localStorage items, including the application-owned `API_URL` key

3. **The failure**:
   - After logout, `api_config_web.dart:7` tries to read `localStorage['API_URL']`
   - Returns `null` because it was deleted
   - Falls back to default: `http://localhost:8080` (line 15)
   - User cannot log back in because app is pointing to wrong API

### Confirmed Behavior

Based on research and documentation:
- ✅ FlutterSecureStorage v9.0.0 on web uses localStorage for storage
- ✅ Uses WebCrypto for encryption on web platform
- ✅ `deleteAll()` removes all keys managed by FlutterSecureStorage
- ⚠️ **NAMESPACE COLLISION**: FlutterSecureStorage and direct localStorage access share the same storage space
- ⚠️ No namespacing or prefixing by default to separate app keys from library keys

---

## Analysis of Options

### Option A: Replace `deleteAll()` with Individual Key Deletions ⭐ **RECOMMENDED**

**Approach**: Explicitly delete only the keys we know about instead of using `deleteAll()`.

**Implementation**:
```dart
// storage_service.dart - Modified clearAll() method
Future<void> clearAll() async {
  // Explicitly delete only our keys, leaving API_URL untouched
  await _storage.delete(key: _keyAccessToken);
  await _storage.delete(key: _keyRefreshToken);
  await _storage.delete(key: _keyUserId);
  await _storage.delete(key: _keyUserEmail);
}
```

**Pros**:
- ✅ Surgical precision - only removes user session data
- ✅ Leaves environment configuration intact
- ✅ No changes to initialization flow
- ✅ Works consistently across all platforms
- ✅ Future-proof - adding new keys is explicit and visible
- ✅ No breaking changes to existing code

**Cons**:
- ⚠️ Must remember to update `clearAll()` when adding new storage keys
- ⚠️ If a developer adds a new key but forgets to delete it, it persists after logout

**Risk Level**: LOW

---

### Option B: Use Prefixed Keys for API_URL

**Approach**: Store `API_URL` with a special prefix that FlutterSecureStorage won't touch.

**Implementation**:
```dart
// api_config_web.dart - Modified key name
String getApiUrl() {
  try {
    // Use prefixed key that won't collide with FlutterSecureStorage
    final apiUrl = html.window.localStorage['APP_ENV_API_URL'];
    if (apiUrl != null && apiUrl.isNotEmpty) {
      return apiUrl;
    }
  } catch (e) {
    // Fall back to default
  }
  return 'http://localhost:8080';
}

// web/index.html - Modified localStorage key
<script>
  const apiUrl = '$API_URL';
  if (apiUrl && apiUrl !== '$' + 'API_URL') {
    localStorage.setItem('APP_ENV_API_URL', apiUrl);
  }
</script>
```

**Pros**:
- ✅ Separates concerns - environment config vs app data
- ✅ `deleteAll()` can be used safely
- ✅ More semantic separation

**Cons**:
- ⚠️ Requires coordinated changes across 2 files
- ⚠️ Existing users would lose API_URL on first deployment (one-time issue)
- ⚠️ Doesn't prevent FlutterSecureStorage from accessing that key (same namespace)

**Risk Level**: MEDIUM

---

### Option C: Use SessionStorage Instead of LocalStorage for API_URL

**Approach**: Store API_URL in sessionStorage instead of localStorage.

**Implementation**:
```dart
// api_config_web.dart
String getApiUrl() {
  try {
    final apiUrl = html.window.sessionStorage['API_URL'];
    if (apiUrl != null && apiUrl.isNotEmpty) {
      return apiUrl;
    }
  } catch (e) {
    // Fall back
  }
  return 'http://localhost:8080';
}

// web/index.html
<script>
  const apiUrl = '$API_URL';
  if (apiUrl && apiUrl !== '$' + 'API_URL') {
    sessionStorage.setItem('API_URL', apiUrl);
  }
</script>
```

**Pros**:
- ✅ Completely separate storage mechanism
- ✅ FlutterSecureStorage cannot touch sessionStorage
- ✅ `deleteAll()` is safe to use

**Cons**:
- ❌ SessionStorage cleared on browser tab close
- ❌ User must reload page from server to re-inject API_URL after opening new tab
- ❌ Poor UX - breaking PWA "feels like native" experience

**Risk Level**: HIGH (UX degradation)

---

### Option D: Store API_URL as a Global JavaScript Variable

**Approach**: Store API_URL as a `window.APP_API_URL` global instead of storage.

**Implementation**:
```dart
// api_config_web.dart
@JS('APP_API_URL')
external String? get appApiUrl;

String getApiUrl() {
  try {
    final apiUrl = appApiUrl;
    if (apiUrl != null && apiUrl.isNotEmpty) {
      return apiUrl;
    }
  } catch (e) {
    // Fall back
  }
  return 'http://localhost:8080';
}

// web/index.html
<script>
  const apiUrl = '$API_URL';
  if (apiUrl && apiUrl !== '$' + 'API_URL') {
    window.APP_API_URL = apiUrl;
  }
</script>
```

**Pros**:
- ✅ Completely immune to storage clearing
- ✅ No storage conflicts possible
- ✅ Persists for page lifetime

**Cons**:
- ❌ Lost on page reload (must re-inject)
- ❌ Requires JS interop setup
- ❌ More complex than necessary

**Risk Level**: MEDIUM

---

## Recommendation: Option A (Individual Key Deletion)

**Why Option A is best**:

1. **Simplicity**: Single-file change, minimal cognitive overhead
2. **Safety**: No risk of breaking existing functionality
3. **Clarity**: Explicit about what's being cleared during logout
4. **Platform consistency**: Works identically on iOS, Android, and Web
5. **Maintainability**: Easy to understand and modify
6. **No coordination required**: No multi-file changes or deployment choreography

**Implementation complexity**: TRIVIAL
**Testing required**: MINIMAL
**Risk of regression**: NEAR ZERO

---

## Implementation Plan

### Step 1: Modify `StorageService.clearAll()`

**File**: `/Users/dsteiman/Dev/stuff/xuangong/app/lib/services/storage_service.dart`

**Change**:
```dart
// Before (line 49-51):
Future<void> clearAll() async {
  await _storage.deleteAll();
}

// After:
Future<void> clearAll() async {
  // Delete individual keys instead of deleteAll() to preserve
  // environment configuration like API_URL in localStorage on web
  await _storage.delete(key: _keyAccessToken);
  await _storage.delete(key: _keyRefreshToken);
  await _storage.delete(key: _keyUserId);
  await _storage.delete(key: _keyUserEmail);
}
```

### Step 2: Add Future-Proofing Comment

**Add comment to class** (after line 14):
```dart
// IMPORTANT: When adding new storage keys, remember to update clearAll()
// to explicitly delete the new key. Do NOT use deleteAll() as it clears
// environment configuration (like API_URL) on web platform.
```

### Step 3: Testing

**Manual test sequence**:
1. Build web app: `flutter build web`
2. Deploy to test environment
3. Login as test user
4. Verify API calls work
5. Logout
6. Verify redirect to login screen
7. **Critical test**: Login again with same credentials
8. **Expected**: Login succeeds (API URL still points to production)
9. **Previously failed here**: Would try localhost and fail

**Verification**:
```javascript
// In browser console after logout:
console.log(localStorage.getItem('API_URL'));
// Should output: "https://xuangong-prod.stytex.cloud" (or whatever prod URL is)
// NOT null or undefined
```

---

## Potential Side Effects

### Positive Side Effects
- ✅ More intentional about what data persists vs. what's cleared
- ✅ Forces developers to think about logout behavior when adding keys
- ✅ Improves code documentation through explicit listing

### Risks & Mitigations

**Risk 1**: Developer adds new key but forgets to update `clearAll()`
**Likelihood**: MEDIUM
**Impact**: LOW (old data persists after logout)
**Mitigation**:
- Add prominent comment in code (Step 2)
- Code review checklist item
- Could add unit test to verify all keys are handled

**Risk 2**: Different platforms behave differently
**Likelihood**: VERY LOW
**Impact**: MEDIUM
**Mitigation**: The change uses platform-agnostic FlutterSecureStorage API; behavior is consistent

**Risk 3**: Performance degradation from multiple deletes vs. `deleteAll()`
**Likelihood**: NONE
**Impact**: NONE
**Rationale**: 4 delete operations vs 1 deleteAll is negligible; logout is not a hot path

---

## Alternative: Option A Plus Defensive Check

If you want extra safety, combine Option A with a defensive initialization check:

```dart
// api_config_web.dart - Enhanced with auto-restore
String getApiUrl() {
  try {
    final apiUrl = html.window.localStorage['API_URL'];
    if (apiUrl != null && apiUrl.isNotEmpty) {
      return apiUrl;
    }

    // DEFENSIVE: If missing, check if we're in a deployment
    // (This would require adding a fallback URL as build constant)
    // For now, we'll just fall back to localhost as before
  } catch (e) {
    // Fall back to default
  }
  return 'http://localhost:8080';
}
```

But this is probably overkill - **Option A alone is sufficient**.

---

## Rollout Plan

### Phase 1: Deploy Fix (Zero Risk)
1. Make change to `storage_service.dart` (Option A)
2. Test locally with `flutter run -d chrome --web-port=8081`
3. Verify login → logout → login cycle works
4. Build: `flutter build web`
5. Deploy as new alpha version
6. Test in production environment
7. If successful, promote to production

### Phase 2: Monitor (Post-Deployment)
1. Check production logs for any auth errors
2. Monitor user reports
3. Verify no localStorage-related errors in Sentry/logging

### Phase 3: Document (Knowledge Capture)
1. Update `.claude/tasks/context/decisions.md` with this decision
2. Add to known issues log if any edge cases discovered
3. Update recent-work.md with completion

---

## Code Changes Summary

**Files to modify**: 1
**Lines changed**: ~8
**New files**: 0
**Breaking changes**: None
**Database migrations**: None
**API changes**: None

**Estimated time**: 5 minutes implementation + 10 minutes testing = 15 minutes total

---

## Conclusion

The logout bug is caused by FlutterSecureStorage's `deleteAll()` clearing the entire localStorage namespace on web, including the application-injected `API_URL` configuration.

**The fix is simple**: Replace `deleteAll()` with explicit deletion of individual keys.

This approach:
- ✅ Fixes the immediate bug
- ✅ Requires minimal code changes
- ✅ Has zero risk of breaking other functionality
- ✅ Works consistently across all platforms
- ✅ Is easy to test and verify

**Status**: Ready for implementation by main agent.