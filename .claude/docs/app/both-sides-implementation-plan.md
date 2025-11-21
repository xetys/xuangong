# Both Sides (hasSides) Functionality - Implementation Plan

**Date**: 2025-11-19
**Status**: Ready for Implementation
**Agent**: flutter-dev-expert

---

## Executive Summary

This document provides a complete implementation plan for the "Both Sides" (hasSides) functionality in the Xuan Gong Flutter app. The feature allows exercises to be performed on two sides (e.g., left leg then right leg) with potentially different durations per side.

**Current State**: Backend model exists, UI checkbox exists, duration calculation includes both sides, but practice screen doesn't execute exercises twice.

**Goal**: Make practice screen run exercises with `hasSides=true` twice in sequence with proper audio cues and visual feedback.

---

## Answers to Key Questions

### 1. State Management Approach

**RECOMMENDATION: Option A - State Variable Approach**

Use a simple `int? _currentSide` state variable (values: null, 1, or 2).

**Rationale**:
- Simpler to implement and debug
- Less memory overhead
- Easier to handle edge cases (pause, skip, exit)
- More flexible for future enhancements
- Fits existing practice screen architecture

### 2. Repetitions + Sides Interaction

**RECOMMENDATION: Option C - Sides only apply to timed and combined exercises**

**Reasoning**:
- Repetition-only exercises (`ExerciseType.repetition`) are inherently bilateral - the user naturally alternates or does both sides per rep
- For timed exercises: Play full duration on side 1, then full duration on side 2
- For combined exercises: Do all reps on side 1, then all reps on side 2
- This matches traditional martial arts practice patterns (complete form on left, then complete form on right)

**Validation Rule**: Only allow `hasSides=true` for `ExerciseType.timed` and `ExerciseType.combined`

### 3. UI Labels

**RECOMMENDATION: Generic with martial arts context**

Use "First Side" / "Second Side" (English) with future i18n support for Chinese.

**Rationale**:
- Neutral (applies to any bilateral exercise: arms, legs, directions)
- Not all exercises are strictly "left/right" (some are "front/back" or "clockwise/counterclockwise")
- Maintains minimalist design philosophy
- Easy to internationalize later

**Display Format**: "Exercise Name - First Side" / "Exercise Name - Second Side"

### 4. Duration Logic

**RECOMMENDATION: Option B - Separate durations**

- `durationSeconds`: Duration for FIRST side
- `sideDurationSeconds`: Duration for SECOND side (can be same or different)

**Rationale**:
- Backend model already designed this way
- `totalDurationMinutes` calculation already adds both (program.dart:104-116)
- Allows asymmetric training (e.g., weaker side gets more time)
- Common in physical therapy and martial arts corrections

**Default Behavior**: When `hasSides=true`, default `sideDurationSeconds` to match `durationSeconds`

### 5. Rest Period Placement

**RECOMMENDATION: Only after BOTH sides complete**

Rest happens after side 2 finishes, not between sides.

**Rationale**:
- Maintains continuous practice flow
- Matches traditional martial arts pedagogy (complete both sides before resting)
- Prevents unnecessary interruption
- Audio cue between sides provides sufficient mental transition

---

## Implementation Architecture

### State Variable Design

```dart
// Add to _PracticeScreenState
int? _currentSide; // null = single-sided, 1 = first side, 2 = second side
```

### Exercise Flow State Machine

```
START EXERCISE
    ↓
Is hasSides?
    ├─ NO → Run once → Rest → Next Exercise
    └─ YES → Set _currentSide = 1
                ↓
          Run First Side (durationSeconds)
                ↓
          Play transition audio (playStart)
                ↓
          Set _currentSide = 2
                ↓
          Run Second Side (sideDurationSeconds)
                ↓
          Set _currentSide = null
                ↓
          Rest → Next Exercise
```

---

## Detailed Implementation Steps

### Step 1: Add `sideDurationSeconds` Input Field (program_edit_screen.dart)

**Location**: After line 866 (after duration field, before repetitions field)

**Code**:
```dart
// Add controller to state class
late TextEditingController _sideDurationController;

// Initialize in initState() (around line 677)
_sideDurationController = TextEditingController(
  text: widget.exercise?.sideDurationSeconds?.toString() ?? '',
);

// Dispose in dispose() (around line 687)
_sideDurationController.dispose();

// Add UI field after main duration field (after line 866)
if (_selectedType != ExerciseType.repetition && _hasSides)
  Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: _sideDurationController,
      decoration: const InputDecoration(
        labelText: 'Second Side Duration (seconds)',
        hintText: 'Leave empty to match first side',
        border: OutlineInputBorder(),
        helperText: 'Duration for the second side of the exercise',
      ),
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value != null && value.isNotEmpty) {
          final parsed = int.tryParse(value);
          if (parsed == null) {
            return 'Please enter a valid number';
          }
          if (parsed <= 0) {
            return 'Duration must be greater than 0';
          }
        }
        return null;
      },
    ),
  ),

// Update _save() method (around line 700-716) to include sideDurationSeconds
final exercise = Exercise(
  id: widget.exercise?.id ?? '',
  programId: widget.exercise?.programId ?? '',
  name: _nameController.text,
  description: _descriptionController.text,
  orderIndex: widget.exercise?.orderIndex ?? 0,
  type: _selectedType,
  durationSeconds: _selectedType != ExerciseType.repetition
      ? int.tryParse(_durationController.text)
      : null,
  repetitions: _selectedType != ExerciseType.timed
      ? int.tryParse(_repetitionsController.text)
      : null,
  hasSides: _hasSides,
  sideDurationSeconds: _hasSides && _sideDurationController.text.isNotEmpty
      ? int.tryParse(_sideDurationController.text)
      : (_hasSides ? int.tryParse(_durationController.text) : null), // Default to main duration
  restAfterSeconds: int.tryParse(_restController.text) ?? 0,
  metadata: metadata,
);
```

**Validation Rules**:
1. Only show field when `_hasSides == true` AND `_selectedType != ExerciseType.repetition`
2. Field is optional (defaults to match `durationSeconds`)
3. If provided, must be positive integer
4. Clear field when `_hasSides` is toggled off

**UI Behavior**:
- Show/hide based on checkbox state
- Placeholder text: "Leave empty to match first side"
- Helper text explains purpose
- Auto-populate with `durationSeconds` value when checkbox checked (optional UX enhancement)

---

### Step 2: Update Practice Screen State (practice_screen.dart)

**Add State Variable** (around line 23-34):
```dart
int? _currentSide; // Tracks which side is being practiced: null, 1, or 2
```

**Initialize in initState()**: Already null by default, no action needed.

**Reset in _nextExercise()** (around line 249):
```dart
void _nextExercise() {
  if (currentExerciseIndex < widget.program.exercises.length - 1) {
    setState(() {
      currentExerciseIndex++;
      isResting = false;
      _currentSide = null; // Reset for next exercise
    });
    _startCountdown();
  } else {
    // Session completed naturally - play longgong
    _audioService.playLongGong();
    _completeSession();
  }
}
```

---

### Step 3: Modify _startExercise() Logic (practice_screen.dart)

**Replace existing _startExercise() method** (starting at line 160):

```dart
void _startExercise() {
  final exercise = widget.program.exercises[currentExerciseIndex];

  // Initialize side tracking for bilateral exercises
  if (exercise.hasSides && _currentSide == null) {
    _currentSide = 1;
  }

  // For repetition-only exercises, don't start a timer
  if (exercise.type == ExerciseType.repetition) {
    setState(() {
      phase = PracticePhase.exercise;
      isPaused = false;
    });

    // If not first exercise, play start sound
    if (_hasShownInitialCountdown && currentExerciseIndex > 0) {
      _audioService.playStart();
    }
    return;
  }

  // Determine duration based on side
  int duration;
  if (exercise.hasSides && _currentSide == 2) {
    // Second side: use sideDurationSeconds if available, else fall back to durationSeconds
    duration = exercise.sideDurationSeconds ?? exercise.durationSeconds ?? 60;
  } else {
    // First side or single-sided exercise
    duration = exercise.durationSeconds ?? 60;
  }

  setState(() {
    phase = PracticePhase.exercise;
    remainingSeconds = duration;
    isPaused = false;
    _initialExerciseDuration = duration;
    _halfTimeSoundPlayed = false;
  });

  // Play start sound for side transitions and subsequent exercises
  if (_hasShownInitialCountdown && (currentExerciseIndex > 0 || _currentSide == 2)) {
    _audioService.playStart();
  }

  _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
    if (!isPaused) {
      setState(() {
        if (remainingSeconds > 0) {
          // Play half-time sound one second earlier (at half + 1)
          final halfTime = (_initialExerciseDuration / 2).round();
          if (!_halfTimeSoundPlayed && remainingSeconds == halfTime + 1) {
            _audioService.playHalf();
            _halfTimeSoundPlayed = true;
          }

          // Play last 2 seconds sound
          if (remainingSeconds == 2) {
            _audioService.playLastTwo();
          }

          remainingSeconds--;

          // Update notification with new time
          _updateNotification();
        } else {
          _timer?.cancel();
          _handleExerciseComplete();
        }
      });
    }
  });
}

// New helper method to handle exercise completion
void _handleExerciseComplete() {
  final exercise = widget.program.exercises[currentExerciseIndex];

  // Check if we need to do the second side
  if (exercise.hasSides && _currentSide == 1) {
    // Transition to second side
    setState(() {
      _currentSide = 2;
    });
    _startExercise(); // Start second side immediately
  } else {
    // Single-sided or both sides complete, move to rest
    setState(() {
      _currentSide = null; // Reset side tracking
    });
    _startRest();
  }
}
```

**Key Changes**:
1. Initialize `_currentSide = 1` when exercise has sides
2. Select duration based on `_currentSide`
3. Play start audio when transitioning to side 2
4. Extract completion logic to `_handleExerciseComplete()`
5. Transition to second side before moving to rest

---

### Step 4: Update _startRest() Method (practice_screen.dart)

**No changes needed** - rest already works correctly. It runs after `_handleExerciseComplete()` which ensures both sides are done.

---

### Step 5: Add Side Indicator to UI (practice_screen.dart)

**Update exercise title display** (around line 316-350 in build method):

Find the section that displays exercise name and update it:

```dart
// Current exercise info
Text(
  exercise.name,
  style: const TextStyle(
    color: Colors.white,
    fontSize: 32,
    fontWeight: FontWeight.bold,
    height: 1.2,
  ),
  textAlign: TextAlign.center,
),

// Add side indicator below exercise name
if (exercise.hasSides && _currentSide != null) ...[
  const SizedBox(height: 8),
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.2),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
    ),
    child: Text(
      _currentSide == 1 ? 'First Side' : 'Second Side',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    ),
  ),
],
```

**Update progress indicator** (around line 337):

```dart
Text(
  _buildProgressText(),
  style: const TextStyle(
    color: Colors.white,
    fontSize: 18,
    fontWeight: FontWeight.w500,
  ),
),

// Add helper method to build progress text
String _buildProgressText() {
  final exercise = widget.program.exercises[currentExerciseIndex];
  final baseProgress = '${currentExerciseIndex + 1}/${widget.program.exercises.length}';

  if (exercise.hasSides && _currentSide != null) {
    return '$baseProgress - Side $_currentSide/2';
  }

  return baseProgress;
}
```

**Visual Design**:
- Side indicator: subtle badge with semi-transparent white background
- Positioned between exercise name and timer
- Only visible when `hasSides == true` and actively practicing
- Progress text shows "X/Y - Side 1/2" format

---

### Step 6: Update Notification Service (notification_service.dart)

**Modify notification methods** to include side information:

Update `showTimerNotification()` method signature and implementation:

```dart
Future<void> showTimerNotification({
  required String exerciseName,
  required int remainingSeconds,
  required int currentExercise,
  required int totalExercises,
  int? currentSide, // Add optional side parameter
}) async {
  // ... existing initialization code ...

  final sideText = currentSide != null ? ' - Side $currentSide/2' : '';

  await _flutterLocalNotificationsPlugin.show(
    0,
    'Practice in Progress',
    '$exerciseName$sideText\n${_formatTime(remainingSeconds)} remaining (Exercise $currentExercise/$totalExercises)',
    // ... rest of notification config ...
  );
}
```

**Update practice_screen.dart call** (around line 120):

```dart
_notificationService.showTimerNotification(
  exerciseName: exercise.name,
  remainingSeconds: remainingSeconds,
  currentExercise: current,
  totalExercises: total,
  currentSide: exercise.hasSides ? _currentSide : null, // Pass side info
);
```

---

### Step 7: Handle Skip Exercise for Sides

**Update _skipExercise() method** (around line 263):

```dart
void _skipExercise() {
  _timer?.cancel();

  // If in countdown phase, skip to exercise start
  if (phase == PracticePhase.countdown) {
    _hasShownInitialCountdown = true;
    _audioService.playStart();
    _startExercise();
    return;
  }

  final exercise = widget.program.exercises[currentExerciseIndex];

  // If on first side of bilateral exercise, skip to second side
  if (exercise.hasSides && _currentSide == 1) {
    setState(() {
      _currentSide = 2;
    });
    _audioService.playStart();
    _startExercise();
  } else {
    // Skip entire exercise (or skip second side to next exercise)
    setState(() {
      _currentSide = null;
    });
    _audioService.playStart();
    _nextExercise();
  }
}
```

**Behavior**:
- First skip: Move from side 1 → side 2
- Second skip: Move to next exercise
- Provides granular control for practitioners

---

### Step 8: Update Program Detail Display (program_detail_screen.dart)

**Show side duration in exercise cards**:

Find where exercises are displayed (likely in a ListView) and update to show both durations:

```dart
// In exercise card/tile display
if (exercise.hasSides) ...[
  Row(
    children: [
      Icon(Icons.repeat, size: 16, color: Colors.grey[600]),
      const SizedBox(width: 4),
      Text(
        'Both sides: ${_formatDuration(exercise.durationSeconds)} + ${_formatDuration(exercise.sideDurationSeconds)}',
        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
      ),
    ],
  ),
] else ...[
  Text(
    exercise.displayDuration,
    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
  ),
],

// Helper method
String _formatDuration(int? seconds) {
  if (seconds == null) return '0s';
  final min = seconds ~/ 60;
  final sec = seconds % 60;
  if (min > 0) {
    return sec > 0 ? '${min}m ${sec}s' : '${min}m';
  }
  return '${sec}s';
}
```

---

## Edge Cases to Handle

### 1. Pause During Side Transition
**Scenario**: User pauses during side 1 or side 2
**Solution**: Already handled - pause works on timer, `_currentSide` state preserved

### 2. Exit During Second Side
**Scenario**: User exits practice during side 2
**Solution**: Already handled - exit dialog cancels timer and navigates away

### 3. Background During Side Transition
**Scenario**: App backgrounds during side transition
**Solution**: Notification already includes side info, continues normally

### 4. Skip on Second Side
**Scenario**: User skips while on second side
**Solution**: Skip button moves to next exercise (both sides considered complete)

### 5. Missing sideDurationSeconds
**Scenario**: `hasSides=true` but `sideDurationSeconds` is null
**Solution**: Fall back to `durationSeconds` value (line 169 in updated code)

### 6. Repetition Exercise with hasSides
**Scenario**: Backend data has `ExerciseType.repetition` with `hasSides=true`
**Solution**:
- Frontend validation prevents this in editor
- Practice screen skips side logic for repetition type (already handled)
- Display shows "Both sides" badge but doesn't affect practice flow

### 7. Combined Exercise with Sides
**Scenario**: `ExerciseType.combined` with `hasSides=true`
**Solution**:
- Side 1: Do all reps for specified duration
- Side 2: Do all reps for side duration
- Half-time bell plays at 50% of EACH side independently

---

## Audio Transition Recommendation

**Use `playStart()` for side transitions**

**Rationale**:
1. **Semantic Meaning**: Start sound signals "begin new activity" - perfect for starting second side
2. **Consistency**: Same sound used for starting exercises after rest
3. **Mental Cue**: Practitioners already associate this sound with "begin now"
4. **Audio Palette**: Keeps sound vocabulary minimal and intentional
5. **Implementation**: No new audio file needed, uses existing asset

**Alternative Considered**: Create new "switch sides" sound
- Rejected: Adds complexity, requires new asset, potentially confusing
- Could revisit in future if user feedback indicates need

---

## Testing Checklist

### Unit Tests (Future Enhancement)
- [ ] Exercise model serializes `hasSides` and `sideDurationSeconds` correctly
- [ ] Program `totalDurationMinutes` includes both sides
- [ ] Side duration defaults to main duration when null

### Widget Tests (Future Enhancement)
- [ ] Side indicator displays "First Side" / "Second Side"
- [ ] Progress text shows "X/Y - Side 1/2" format
- [ ] Duration input field appears/disappears with checkbox

### Manual Testing (Critical)
- [ ] Create exercise with `hasSides=true`, both durations equal
- [ ] Practice exercise - verify runs twice
- [ ] Verify start sound plays between sides
- [ ] Verify half-time bell plays during each side independently
- [ ] Verify rest only happens after both sides
- [ ] Skip during first side - should go to second side
- [ ] Skip during second side - should go to next exercise
- [ ] Pause during each side - verify timer stops correctly
- [ ] Exit during second side - verify clean exit
- [ ] Create exercise with different side durations
- [ ] Verify notification shows side info when backgrounded
- [ ] Create combined exercise with sides - verify reps work correctly
- [ ] Verify program duration display includes both sides
- [ ] Verify empty `sideDurationSeconds` defaults to `durationSeconds`

---

## Files to Modify

### 1. app/lib/screens/program_edit_screen.dart
**Changes**: Add `sideDurationSeconds` input field, controller, validation
**Lines**: ~655 (controller init), ~681 (dispose), ~866 (UI field), ~700-716 (save logic)
**Risk**: Low - isolated to exercise editor dialog

### 2. app/lib/screens/practice_screen.dart
**Changes**: Add `_currentSide` state, modify `_startExercise()`, add `_handleExerciseComplete()`, update UI display, update `_skipExercise()`
**Lines**: ~23 (state var), ~160-220 (exercise logic), ~316+ (UI display), ~263 (skip)
**Risk**: Medium - core practice logic, requires careful testing

### 3. app/lib/services/notification_service.dart
**Changes**: Add `currentSide` parameter to `showTimerNotification()`
**Lines**: Method signature and notification text
**Risk**: Low - optional parameter, backward compatible

### 4. app/lib/screens/program_detail_screen.dart (Optional Enhancement)
**Changes**: Display both side durations in exercise list
**Lines**: Exercise card/tile display section
**Risk**: Very Low - display only, can be skipped for MVP

---

## Implementation Order

1. **Phase 1 - Backend Support** ✅ (Already Complete)
   - Model fields exist
   - Serialization works
   - Duration calculation includes both sides

2. **Phase 2 - Editor UI** (Implement First)
   - Add `sideDurationSeconds` input field
   - Add controller and validation
   - Test: Create exercises with both sides enabled

3. **Phase 3 - Practice Logic** (Implement Second)
   - Add `_currentSide` state variable
   - Modify `_startExercise()` and `_handleExerciseComplete()`
   - Update `_skipExercise()` for side awareness
   - Test: Run exercises with both sides

4. **Phase 4 - UI Feedback** (Implement Third)
   - Add side indicator badge
   - Update progress text
   - Update notification service
   - Test: Visual feedback during practice

5. **Phase 5 - Polish** (Implement Last)
   - Update program detail display
   - Add helper text and tooltips
   - Comprehensive edge case testing

---

## Success Criteria

- ✅ Exercise editor allows setting `sideDurationSeconds`
- ✅ Practice screen runs exercise twice when `hasSides=true`
- ✅ Start audio cue plays between sides
- ✅ Side indicator shows "First Side" / "Second Side"
- ✅ Progress shows "X/Y - Side 1/2"
- ✅ Rest happens only after both sides
- ✅ Skip moves from side 1 → side 2 → next exercise
- ✅ Notification includes side information
- ✅ Program duration includes both sides
- ✅ No regressions in single-sided exercises
- ✅ Half-time bell plays correctly for each side

---

## Future Enhancements (Out of Scope)

1. **Side-Specific Instructions**: Allow different descriptions for each side
2. **Visual Side Indicator**: Show left/right icon or animation
3. **Side Swap Sound**: Dedicated "switch sides" audio cue
4. **Internationalization**: Translate "First Side" / "Second Side" to German/Chinese
5. **Rest Between Sides**: Optional rest period between sides (currently not supported)
6. **Statistics**: Track which side had better performance/consistency
7. **Asymmetric Repetitions**: Different rep counts per side (currently same reps both sides)

---

## Notes for Implementation

1. **Martial Arts Context**: This feature is essential for traditional forms practice where students must master movements on both sides equally
2. **Asymmetric Training**: Allowing different durations supports corrective training (weaker side gets more practice time)
3. **Flow Preservation**: No rest between sides maintains the meditative flow of continuous practice
4. **Audio Semantics**: Reusing start sound reinforces the mental model "start sound = begin new segment"
5. **Minimalist UI**: Side indicator is subtle and only appears when relevant, maintaining the app's clean aesthetic

---

## Questions Answered Summary

| Question | Answer |
|----------|--------|
| State Management | Option A: State variable `_currentSide` |
| Reps + Sides | Option C: Sides only for timed/combined |
| UI Labels | "First Side" / "Second Side" (generic) |
| Duration Logic | Option B: Separate durations per side |
| Rest Placement | Only after both sides complete |
| Implementation | Option A: State variable approach |
| Audio Transition | Reuse `playStart()` sound |

---

**End of Implementation Plan**

This plan is ready for the main development agent to implement. All architectural decisions have been made, edge cases identified, and code snippets provided for each modification point.