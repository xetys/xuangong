# Admin Feature UI Improvements - Implementation Plan

**Date**: 2025-11-06
**Status**: Research Complete - Ready for Implementation

## Overview

This document provides detailed implementation plans for three Flutter UI improvements for admin users in the Xuan Gong martial arts training app.

---

## Task 1: Restore Overview Tab for Admins in Program Detail Screen

### Current Implementation

**File**: `/Users/dsteiman/Dev/stuff/xuangong/app/lib/screens/program_detail_screen.dart`

**Current Behavior**:
- Lines 44-46: Tab count is determined by `widget.program.isTemplate`
  - Templates: 1 tab (Overview only)
  - Programs: 3 tabs (Overview, Sessions, Submissions)
- Lines 141-154: TabBar is only shown for non-templates
- Lines 173-196: "Start Practice" button shown for all non-template programs
- Lines 116-139: Edit and Delete buttons shown if `widget.user != null && _canEdit()`

**Problem**:
- When admin views a student's program (non-template), they see 3 tabs including Overview
- However, the "Start Practice" button appears at the bottom, which doesn't make sense for admins
- Admins need to see program details including repetition counts in Overview tab

### Required Changes

#### 1.1 Remove "Start Practice" Button for Admins

**Location**: Lines 173-196

**Change**: Wrap the "Start Practice" button in a conditional that checks if user is student or if no user provided
```dart
// Show "Start Practice" only for students or when no user context
if (!widget.program.isTemplate && (widget.user == null || widget.user!.isStudent))
```

**Reasoning**:
- `widget.user == null`: Student viewing their own program (user context not passed)
- `widget.user!.isStudent`: Explicitly a student
- Admins have `widget.user!.isAdmin` so they won't see the button

#### 1.2 Add Repetition Count Display to Overview Tab

**Location**: Lines 202-324 in `_buildOverviewTab()`

**Current State**:
- Lines 239-252: Shows exercise count and duration as info chips
- Lines 454-470 in home_screen.dart: Shows repetitions as `${program.repetitionsCompleted ?? 0}/${program.repetitionsPlanned}`

**Change**: Add repetition count chip after duration chip (around line 252)
```dart
if (widget.program.repetitionsPlanned != null) ...[
  const SizedBox(width: 12),
  _buildInfoChip(
    Icons.repeat,
    '${widget.program.repetitionsCompleted ?? 0}/${widget.program.repetitionsPlanned}',
    burgundy,
  ),
],
```

**Reasoning**: Reuse existing pattern from home_screen.dart and student_detail_screen.dart (lines 405-421)

### Dependencies

**Backend**: No API changes needed
- Program model already has `repetitionsCompleted` and `repetitionsPlanned` fields
- Both are fetched in Program.fromJson (lines 52-53 in program.dart)

**User Role Handling**:
- User model has `isAdmin` and `isStudent` getters (lines 38-39 in user.dart)
- Can check `widget.user?.isAdmin` or `widget.user?.isStudent`

### Navigation/State

**No changes needed**:
- `widget.user` is already passed from calling screens
- HomeScreen passes `user: widget.user` (not visible in snippet, but established pattern)
- Edit and Delete already use this pattern correctly (lines 116-139)

### Recommended Step-by-Step Implementation

1. **Add repetition count display** (lines 239-252 area):
   - Add conditional check: `if (widget.program.repetitionsPlanned != null)`
   - Call `_buildInfoChip()` with Icons.repeat and formatted string
   - Use same pattern as home_screen.dart line 463

2. **Hide Start Practice button for admins** (lines 173-196):
   - Change condition from `if (!widget.program.isTemplate)`
   - To `if (!widget.program.isTemplate && (widget.user == null || widget.user!.isStudent))`

3. **Test scenarios**:
   - Admin viewing student program: No Start Practice button, shows repetitions
   - Student viewing own program: Shows Start Practice button, shows repetitions
   - Anyone viewing template: No Start Practice button, no repetitions (templates don't have repetitions)

---

## Task 2: Show Student's Sessions (Not Instructor's) in Sessions Tab

### Current Implementation

**File**: `/Users/dsteiman/Dev/stuff/xuangong/app/lib/screens/program_detail_screen.dart`

**Current Behavior**:
- Lines 60-85: `_loadSessions()` calls `_sessionService.listSessions(programId: widget.program.id)`
- Lines 326-542: Sessions tab displays sessions for the logged-in user (the instructor)
- No student context is available

**Problem**:
When an admin/instructor views a student's program detail screen via the "Sessions" tab, it shows the instructor's own sessions for that program, not the student's sessions.

**Note**: There's already a separate screen `student_program_detail_screen.dart` that correctly shows student sessions!

### Analysis of Existing Student Sessions View

**File**: `/Users/dsteiman/Dev/stuff/xuangong/app/lib/screens/student_program_detail_screen.dart`

**How It Works**:
- Lines 10-12: Takes both `Program program` and `User student` parameters
- Lines 54-78: `_loadSessions()` calls same API: `_sessionService.listSessions(programId: widget.program.id)`
- Lines 112-264: Displays sessions in a different layout with student info banner

**Key Insight**: The backend `listSessions` API already filters by logged-in user!

**Backend API**: `/Users/dsteiman/Dev/stuff/xuangong/app/lib/services/session_service.dart`
- Lines 39-72: `listSessions()` accepts `programId` filter
- Does NOT accept `userId` parameter
- API endpoint: `GET /sessions?program_id={programId}`

### Root Cause

The backend API endpoint `/sessions` returns sessions for the **currently authenticated user**. There's no way to request "sessions for user X" as an admin.

### Required Changes

#### Option A: Add userId Parameter to Backend API (RECOMMENDED)

**Backend Changes Required**:
1. Modify `GET /sessions` endpoint to accept optional `user_id` query parameter
2. If admin and `user_id` provided, return that user's sessions
3. If student or no `user_id`, return own sessions (existing behavior)

**Frontend Changes** (`session_service.dart`):
```dart
Future<List<SessionWithLogs>> listSessions({
  String? programId,
  String? userId,  // NEW PARAMETER
  DateTime? startDate,
  DateTime? endDate,
  int limit = 20,
  int offset = 0,
}) async {
  final queryParams = <String, String>{
    'limit': limit.toString(),
    'offset': offset.toString(),
  };
  if (programId != null) {
    queryParams['program_id'] = programId;
  }
  if (userId != null) {
    queryParams['user_id'] = userId;  // NEW
  }
  // ... rest of implementation
}
```

**Frontend Changes** (`program_detail_screen.dart`):
```dart
// Need to add student parameter to ProgramDetailScreen constructor
final User? student; // Add this field

// In _loadSessions():
final sessions = await _sessionService.listSessions(
  programId: widget.program.id,
  userId: widget.student?.id,  // Pass student ID if viewing as admin
  limit: 100,
);
```

#### Option B: Different Navigation for Admin vs Student (ALTERNATIVE)

**Changes**: Modify navigation to use different screens
- When admin taps student's program: Navigate to `StudentProgramDetailScreen` (already exists!)
- When student taps own program: Navigate to `ProgramDetailScreen` (current behavior)

**Pro**: No backend changes needed, reuse existing screen
**Con**: Different UX for admins, `StudentProgramDetailScreen` doesn't have Overview tab

### Recommended Approach: Option A

**Why**:
1. Unified UX - same screen for everyone
2. Backend change is straightforward and secure (admin permission check)
3. More flexible - could support other admin use cases

**Step-by-Step Implementation**:

1. **Backend**: Add `user_id` query parameter to `/sessions` endpoint
   - Add admin permission check
   - Filter sessions by user_id if provided
   - Document in API

2. **Frontend** (`session_service.dart`):
   - Add `String? userId` parameter to `listSessions()`
   - Add to query parameters if not null

3. **Frontend** (`program_detail_screen.dart`):
   - Add `final User? student` field to class
   - Update constructor to accept optional student
   - Pass `userId: widget.student?.id` to `listSessions()`

4. **Navigation**: Update places that navigate to ProgramDetailScreen
   - `student_detail_screen.dart` line 342: Already passes program
   - Need to also pass `student: widget.student`

5. **UI Enhancement**: Add student info banner when viewing as admin
   - Similar to `student_program_detail_screen.dart` lines 122-156
   - Show student name and context

### Dependencies

**Backend API**: New endpoint or parameter required
**Navigation**: Need to pass student context through navigation

### Testing Scenarios

1. Admin views student program Sessions tab → Shows student's sessions
2. Student views own program Sessions tab → Shows own sessions
3. Admin views template Sessions tab → No sessions (templates don't have sessions)

---

## Task 3: Add Admin Role Control to Student Edit Screen

### Current Implementation

**File**: `/Users/dsteiman/Dev/stuff/xuangong/app/lib/screens/student_edit_screen.dart`

**Current Behavior**:
- Lines 21-23: State variables include `_isActive` and `_isAdmin`
- Lines 31-32: Initialize from `widget.student` if editing
- Lines 169-188: SwitchListTile for Active status (always shown)
- Lines 179-188: SwitchListTile for Admin role - **ONLY shown when creating** (`if (!isEditing)`)
- Lines 49-66: Save logic uses `_isAdmin` for create, but doesn't pass role for update

**Problem**:
- Admin toggle only visible when creating new student
- Cannot change existing student's role from student to admin (or vice versa)
- Backend `updateUser()` doesn't accept role parameter

### User Model Analysis

**File**: `/Users/dsteiman/Dev/stuff/xuangong/app/lib/models/user.dart`

**Structure**:
- Line 5: `final String role` - Can be 'admin' or 'student'
- Lines 38-39: Helper getters `isAdmin` and `isStudent`

### UserService Analysis

**File**: `/Users/dsteiman/Dev/stuff/xuangong/app/lib/services/user_service.dart`

**Create User** (lines 28-45):
- Accepts `role` parameter (defaults to 'student')
- POST to `/users` with role in body

**Update User** (lines 48-62):
- Does NOT accept role parameter
- Only accepts: email, password, fullName, isActive
- PUT to `/users/{userId}`

### Required Changes

#### 3.1 Backend Changes Required

**Add role parameter to update endpoint**:
```go
// In user update handler
type UpdateUserRequest struct {
    Email    *string `json:"email"`
    Password *string `json:"password"`
    FullName *string `json:"full_name"`
    IsActive *bool   `json:"is_active"`
    Role     *string `json:"role"`  // NEW - validate "admin" or "student"
}
```

**Security considerations**:
- Only admins can change roles
- Cannot demote yourself (last admin protection)
- Validate role is either "admin" or "student"

#### 3.2 Frontend Changes

**File**: `user_service.dart` (lines 48-62)

**Change**: Add role parameter
```dart
Future<void> updateUser({
  required String userId,
  String? email,
  String? password,
  String? fullName,
  bool? isActive,
  String? role,  // NEW PARAMETER
}) async {
  final Map<String, dynamic> body = {};
  if (email != null) body['email'] = email;
  if (password != null) body['password'] = password;
  if (fullName != null) body['full_name'] = fullName;
  if (isActive != null) body['is_active'] = isActive;
  if (role != null) body['role'] = role;  // NEW

  await _apiClient.put('${ApiConfig.apiBase}/users/$userId', body);
}
```

**File**: `student_edit_screen.dart`

**Change 1**: Remove `if (!isEditing)` condition (line 179)
```dart
// BEFORE
if (!isEditing)
  SwitchListTile(...)

// AFTER
SwitchListTile(
  title: const Text('Admin'),
  subtitle: const Text('User has admin privileges'),
  value: _isAdmin,
  activeColor: burgundy,
  onChanged: (value) => setState(() => _isAdmin = value),
  tileColor: Colors.white,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
),
```

**Change 2**: Pass role to updateUser (lines 58-65)
```dart
// Update existing student
await _userService.updateUser(
  userId: widget.student!.id,
  email: _emailController.text.trim(),
  fullName: _fullNameController.text.trim(),
  password: _passwordController.text.isNotEmpty ? _passwordController.text : null,
  isActive: _isActive,
  role: _isAdmin ? 'admin' : 'student',  // NEW
);
```

### UI Widget Choice

**Current**: SwitchListTile (toggle)

**Alternatives Considered**:
1. **Dropdown**: More formal, clearly shows "student" vs "admin"
2. **Radio Buttons**: Good for mutually exclusive options
3. **SwitchListTile**: Simple, matches Active toggle pattern (RECOMMENDED)

**Recommendation**: Keep SwitchListTile
- Consistent with Active toggle above it
- Simple binary choice (admin = true/false)
- Less UI clutter
- Familiar pattern

### Permission Check

**Where to check current user is admin**:
- Navigation to StudentEditScreen already implies admin (only accessible from students list)
- StudentsScreen is only accessible to admins (navigation drawer check)
- No additional check needed in StudentEditScreen itself

**Optional Enhancement**: Disable role toggle if editing yourself
```dart
onChanged: widget.student?.id == currentUserId
  ? null  // Can't change own role
  : (value) => setState(() => _isAdmin = value),
```

### Dependencies

**Backend**: API change required to accept role parameter in update endpoint

**Security**: Backend must validate:
1. Only admins can change roles
2. Cannot demote last admin
3. Role must be "admin" or "student"

### Recommended Step-by-Step Implementation

1. **Backend**: Add role parameter to user update endpoint
   - Update handler struct
   - Add validation
   - Add permission checks
   - Test endpoint

2. **Frontend** (`user_service.dart`):
   - Add `String? role` parameter to `updateUser()`
   - Include in request body if not null

3. **Frontend** (`student_edit_screen.dart`):
   - Remove `if (!isEditing)` condition from Admin toggle
   - Pass `role: _isAdmin ? 'admin' : 'student'` to updateUser call
   - Optional: Add self-edit protection

4. **Testing**:
   - Create new student as admin → Works (already works)
   - Create new student as student → Works (already works)
   - Edit student, toggle admin → Persists
   - Edit student, toggle back → Persists
   - Try to demote self → Disabled or blocked by backend
   - Try to demote last admin → Blocked by backend

---

## Summary Table

| Task | Files to Modify | Backend Changes | Complexity |
|------|----------------|-----------------|------------|
| **Task 1**: Overview Tab Improvements | `program_detail_screen.dart` | None | Low |
| **Task 2**: Show Student Sessions | `program_detail_screen.dart`<br>`session_service.dart`<br>Navigation callers | Add `user_id` param to `/sessions` endpoint | Medium |
| **Task 3**: Admin Role Control | `student_edit_screen.dart`<br>`user_service.dart` | Add `role` param to user update endpoint | Low-Medium |

## Implementation Order Recommendation

1. **Task 1** - Quickest win, no backend changes
2. **Task 3** - Straightforward once backend adds parameter
3. **Task 2** - More complex due to navigation and context passing

---

## Common Patterns Identified

### User Role Checking
```dart
// User model has helpers
user.isAdmin  // Returns true if role == 'admin'
user.isStudent  // Returns true if role == 'student'

// Null-safe checking
widget.user?.isAdmin ?? false
widget.user?.isStudent ?? true  // Default to student
```

### Getting Current User
```dart
// In StatefulWidget with user context
final user = widget.user;

// If need to fetch fresh
final authService = AuthService();
final currentUser = await authService.getCurrentUser();
```

### Repetition Count Display Pattern
```dart
// From home_screen.dart and student_detail_screen.dart
if (program.repetitionsPlanned != null) ...[
  const SizedBox(width: 16),
  Icon(Icons.repeat, size: 16, color: burgundy.withValues(alpha: 0.7)),
  const SizedBox(width: 4),
  Text(
    '${program.repetitionsCompleted ?? 0}/${program.repetitionsPlanned}',
    style: TextStyle(
      fontSize: 14,
      color: burgundy.withValues(alpha: 0.7),
      fontWeight: FontWeight.w600,
    ),
  ),
],
```

### Conditional Widget Display
```dart
// Show only for specific conditions
if (condition) ...[
  Widget1(),
  Widget2(),
],

// More complex conditions
if (!program.isTemplate && (user == null || user.isStudent))
  ActionButton(),
```

---

## Files Reference

All file paths are absolute from project root: `/Users/dsteiman/Dev/stuff/xuangong/`

### Flutter Files
- `app/lib/screens/program_detail_screen.dart` - Main program detail view
- `app/lib/screens/student_program_detail_screen.dart` - Student-specific program view (reference)
- `app/lib/screens/student_edit_screen.dart` - Student create/edit form
- `app/lib/screens/student_detail_screen.dart` - Student profile with programs list
- `app/lib/services/session_service.dart` - Session API calls
- `app/lib/services/user_service.dart` - User management API calls
- `app/lib/services/auth_service.dart` - Authentication and current user
- `app/lib/models/user.dart` - User model with role helpers
- `app/lib/models/program.dart` - Program model with repetitions

### Backend Files (for reference)
- `backend/internal/handlers/session_handler.go` - Sessions endpoint
- `backend/internal/handlers/user_handler.go` - User management endpoint

---

**End of Implementation Plan**