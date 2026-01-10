# Pill Reminder App - Claude Context

## Project Overview

A Flutter medication reminder application that helps users manage their medications with smart notifications, inventory tracking, and dose history logging.

## Architecture

### State Management: Riverpod
- **medication_provider.dart**: Manages medication CRUD operations and persistence
- **dose_log_provider.dart**: Manages dose history logging and queries

### Data Persistence: Hive
- **Medication Box**: Stores medication entities with auto-generated UUIDs
- **DoseLog Box**: Stores dose history with timestamps and actions (take/skip)
- Both use TypeAdapters for serialization

### Notification System: flutter_local_notifications
- **Timezone-aware scheduling**: Uses `timezone` package with `flutter_timezone` for device timezone detection
- **Fallback timezone logic**: Maps UTC offsets to timezone names when `FlutterTimezone` returns incorrect values
- **Follow-up reminders**: Schedules 12 notifications (every 15 minutes for 3 hours) per reminder slot
- **Notification tags**: Uses tags to replace old notifications instead of stacking
- **Action buttons**: Take/Skip buttons directly on notifications
- **Payload format**: Uses millisecondsSinceEpoch for timezone-safe time storage

## Core Models

### Medication
```dart
@HiveType(typeId: 0)
class Medication {
  @HiveField(0) String id;              // UUID
  @HiveField(1) String name;            // Medication name
  @HiveField(2) String dosage;          // e.g., "500mg"
  @HiveField(3) int pillsPerDose;       // Number of pills per dose
  @HiveField(4) int totalPills;         // Current stock count
  @HiveField(5) List<String> scheduledTimes;  // HH:mm format
  @HiveField(6) List<int> reminderDays; // 1=Mon, 7=Sun
  @HiveField(7) DateTime createdAt;
}
```

### DoseLog
```dart
@HiveType(typeId: 1)
class DoseLog {
  @HiveField(0) String id;              // UUID
  @HiveField(1) String medicationId;    // Reference to medication
  @HiveField(2) String medicationName;  // Denormalized for queries
  @HiveField(3) DateTime timestamp;     // When action occurred
  @HiveField(4) String action;          // 'take' or 'skip'
  @HiveField(5) DateTime scheduledTime; // Original scheduled time
}
```

## Key Features

### 1. Medication Management
- Add/Edit/Delete medications
- Inventory tracking with automatic stock deduction
- Multiple daily reminder times
- Weekday-based scheduling

### 2. Smart Notifications
- **Initial notification** at scheduled time
- **12 follow-up notifications** if not acted upon (every 15 min for 3 hours)
- **Same notification tag** ensures only one shows at a time
- **Weekly recurrence** using `DateTimeComponents.dayOfWeekAndTime` for ALL follow-ups
- **Background action handling** with dedicated isolate for Take/Skip from notifications
- **Automatic cancellation** when Take/Skip is pressed
- **Undo feature** in app UI for accidental Take/Skip (4-second window)
- **~41 reminder slots** capacity (500 Android alarm limit / 12 notifications per slot)

### 3. Dose History
- Logs every Take/Skip action with timestamp
- Filterable by date and medication
- Shows original scheduled time vs actual action time
- Persists across app restarts

### 4. Timezone Handling
The app has robust timezone handling to ensure notifications fire at correct local times:

```dart
// Primary: Try to get timezone from device
timeZoneName = await FlutterTimezone.getLocalTimezone();

// Fallback: If returns UTC incorrectly, map offset to timezone
if (timeZoneName == 'UTC') {
  final deviceOffset = DateTime.now().timeZoneOffset;
  timeZoneName = _findTimezoneByOffset(deviceOffset);
}
```

Supports common timezones:
- Asia/Dhaka (UTC+6)
- Asia/Kolkata (UTC+5:30)
- America/New_York (UTC-5)
- Europe/Paris (UTC+1)
- And more...

## Notification Flow

```
1. User saves medication with reminder times
   ↓
2. scheduleMedicationReminders() called
   ↓
3. For each time + day combination:
   - Calculate next occurrence of that weekday/time
   - Schedule 12 notifications (0min, 15min, 30min, ..., 165min)
   - All use same tag: 'med_{medicationId}_{reminderIndex}'
   - ALL notifications set to recur weekly
   ↓
4. When scheduled time arrives:
   - First notification appears (i=0)
   ↓
5. If user dismisses without action:
   - 15 minutes later, next notification replaces it (i=1)
   - Continues until i=11 (3 hours total)
   ↓
6. If user taps Take/Skip:
   - Current notification dismissed immediately
   - All 12 pending notifications cancelled
   - Existing pending DoseLog updated (or new one created)
   - Stock updated (if Take)
```

## Notification ID Generation

```dart
// For follow-up notifications
int _generateFollowUpId(String medicationId, int reminderIndex, int followUpIndex) {
  final hash = medicationId.hashCode.abs();
  return (hash % 1000) * 100000 + reminderIndex * 1000 + followUpIndex;
}

// reminderIndex = timeIndex * 7 + weekday
// This ensures unique IDs per medication, time slot, day, and follow-up
```

## Important Implementation Details

### 1. Stock Management
- Stock decreases ONLY when "Take" button is pressed on notification
- Does NOT decrease when manually logging in dose history
- Uses callback from NotificationService to MedicationProvider

### 2. Notification Permissions
Required permissions on Android 13+:
- `POST_NOTIFICATIONS`: For showing notifications
- `SCHEDULE_EXACT_ALARM`: For precise timing (medication-critical)

### 3. Background Notification Handling
```dart
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  // Entry point for when app is terminated
  // Initializes Hive in background isolate
  // Handles Take/Skip actions without opening app
  // Updates database and cancels follow-up notifications
}
```

### 4. Release Build Configuration
**ProGuard/R8 Settings** (android/app/build.gradle.kts):
```kotlin
release {
    isMinifyEnabled = false          // Prevents timezone data stripping
    isShrinkResources = false
    proguardFiles(...)               // Keeps notification classes
}
```

**ProGuard Rules** (android/app/proguard-rules.pro):
- Keeps flutter_local_notifications classes
- Preserves timezone data for release builds

### 4. Time Formatting
- All times stored in HH:mm format (24-hour)
- UI displays in 12-hour format with AM/PM (`h:mm a`)
- Timezone-aware scheduling using `tz.TZDateTime`

## File Structure

```
lib/
├── main.dart
│   - App initialization
│   - Hive setup
│   - Provider overrides
│   - Notification callback setup
│
├── models/
│   ├── medication.dart          # @HiveType(typeId: 0)
│   ├── medication.g.dart        # Generated adapter
│   ├── dose_log.dart            # @HiveType(typeId: 1)
│   └── dose_log.g.dart          # Generated adapter
│
├── providers/
│   ├── medication_provider.dart
│   │   - addMedication()
│   │   - updateMedication()
│   │   - deleteMedication()
│   │   - decrementStock()       # Called from notification action
│   │
│   └── dose_log_provider.dart
│       - logDose()
│       - getDoseLogs()
│       - getLogsForDate()
│       - getLogsForMedication()
│
├── screens/
│   ├── home_screen.dart
│   │   - Medication list
│   │   - Add medication button
│   │   - Bottom navigation
│   │
│   ├── add_medication_screen.dart
│   │   - Medication form
│   │   - Time picker
│   │   - Weekday selector
│   │
│   ├── edit_medication_screen.dart
│   │   - Pre-filled form
│   │   - Stock adjustment
│   │   - Delete option
│   │
│   ├── dose_history_screen.dart
│   │   - Date filter
│   │   - Medication filter
│   │   - History list
│   │
│   └── settings_screen.dart
│       - Test notification buttons (for debugging)
│       - App version
│
├── services/
│   └── notification_service.dart
│       - initialize()
│       - scheduleMedicationReminders()
│       - _scheduleWeeklyNotificationWithFollowUps()
│       - _cancelFollowUpReminders()
│       - _onNotificationTapped()
│       - _findTimezoneByOffset()
│
└── widgets/
    ├── medication_card.dart
    │   - Display medication info
    │   - Quick actions (edit/delete)
    │
    └── inventory_card.dart
        - Stock level display
        - Visual indicator
```

## Testing Notifications

The app includes test notification buttons in Settings screen:
1. **Test Notification (Instant)**: Immediate notification
2. **Test Scheduled (5 sec)**: Notification after 5 seconds

Use these to verify notification permissions and functionality.

## Common Issues & Solutions

### Issue: Notifications not appearing
**Solution**:
1. Check notification permissions
2. Check exact alarm permissions
3. Disable battery optimization for app
4. Verify timezone is set correctly

### Issue: Stock not decreasing
**Solution**: User must tap "Take" button on notification, not just dismiss

### Issue: Timezone showing UTC
**Solution**: The fallback logic uses device offset to determine correct timezone

### Issue: Multiple notifications stacking
**Solution**: All notifications use the same tag, they should replace each other

## Dependencies

```yaml
dependencies:
  flutter_riverpod: ^2.6.1          # State management
  hive: ^2.2.3                      # Local database
  hive_flutter: ^1.1.0              # Hive Flutter integration
  flutter_local_notifications: ^18.0.1  # Notifications
  timezone: ^0.10.0                 # Timezone data
  flutter_timezone: ^3.0.1          # Device timezone detection
  intl: ^0.19.0                     # Date formatting
  uuid: ^4.5.1                      # UUID generation

dev_dependencies:
  build_runner: ^2.4.13             # Code generation
  hive_generator: ^2.0.1            # Hive adapter generation
```

## Build Commands

```bash
# Install dependencies
flutter pub get

# Generate Hive adapters
flutter pub run build_runner build --delete-conflicting-outputs

# Clean generated files
flutter pub run build_runner clean

# Run app
flutter run

# Build APK
flutter build apk --release

# Build App Bundle
flutter build appbundle --release
```

## Code Generation

When adding new Hive models:
1. Add `@HiveType(typeId: X)` to class
2. Add `@HiveField(X)` to each field
3. Import `hive` package
4. Add `part 'filename.g.dart';`
5. Run `flutter pub run build_runner build --delete-conflicting-outputs`

## API Surface

### NotificationService Public Methods
```dart
Future<void> initialize()
Future<void> scheduleMedicationReminders(Medication medication)
Future<void> cancelMedicationReminders(String medicationId)
Future<void> cancelAllNotifications()
Future<void> showTestNotification()
Future<void> scheduleTestNotification()
```

### MedicationProvider Public Methods
```dart
void addMedication(Medication medication)
void updateMedication(Medication medication)
void deleteMedication(String id)
void decrementStock(String medicationId, int amount)
```

### DoseLogProvider Public Methods
```dart
void logDose(String medicationId, String medicationName, String action, DateTime scheduledTime)
List<DoseLog> getDoseLogs()
List<DoseLog> getLogsForDate(DateTime date)
List<DoseLog> getLogsForMedication(String medicationId)
```

## Future Enhancements

Potential improvements:
- [ ] Push notifications when running low on stock
- [ ] Export dose history to CSV
- [ ] Medication refill reminders
- [ ] Multiple user profiles
- [ ] Cloud sync
- [ ] Widget for home screen
- [ ] Customizable reminder intervals
- [ ] Snooze functionality
- [ ] Dark mode

## Notes for AI Assistants

- When modifying notification logic, remember to update both the scheduling (12 notifications) and cancellation (12 cancellations) loops
- Stock changes should ONLY happen in `decrementStock()` method, called from notification callback
- All times are stored in 24-hour format but displayed in 12-hour format (use `DateFormat('h:mm a')`)
- Timezone handling has fallback logic - don't remove it
- Notification tags are critical for the "replace" behavior
- Use `matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime` for ALL notifications (not just i=0)
- Payload uses millisecondsSinceEpoch for timezone-safe storage - don't use ISO8601 strings
- Notification callback finds and updates existing pending DoseLog instead of creating duplicates
- Background notification actions run in separate isolate - must initialize Hive independently
- Release builds require minification disabled to preserve timezone data
- Undo feature stores previous state before modifications for 4-second rollback window
