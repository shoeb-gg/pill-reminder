import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/medication.dart';
import '../models/dose_log.dart';
import '../services/database_service.dart';

// Callback for handling notification actions in background
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  debugPrint('NotificationService: Background notification tap - actionId: ${response.actionId}');

  // Handle the action in background
  if (response.payload != null && response.actionId != null) {
    try {
      final payload = json.decode(response.payload!);
      final medicationId = payload['medicationId'] as String;
      final scheduledTimeMillis = payload['scheduledTime'] as int;
      final scheduledTime = DateTime.fromMillisecondsSinceEpoch(scheduledTimeMillis);
      final reminderIndex = payload['reminderIndex'] as int? ?? 0;
      final action = response.actionId!;

      debugPrint('NotificationService: Background - medicationId: $medicationId, action: $action');

      if (action == 'take' || action == 'skip') {
        // Initialize Hive in background isolate
        await Hive.initFlutter();
        Hive.registerAdapter(MedicationAdapter());
        Hive.registerAdapter(DoseLogAdapter());
        Hive.registerAdapter(DoseStatusAdapter());
        await Hive.openBox<Medication>('medications');
        await Hive.openBox<DoseLog>('dose_logs');

        final dbService = DatabaseService();
        final medication = dbService.getMedication(medicationId);
        if (medication == null) return;

        final now = DateTime.now();

        // Find existing pending dose log
        final todayLogs = dbService.getDoseLogsForDate(scheduledTime);
        final existingLog = todayLogs.cast<DoseLog?>().firstWhere(
          (log) =>
              log!.medicationId == medicationId &&
              log.scheduledTime.hour == scheduledTime.hour &&
              log.scheduledTime.minute == scheduledTime.minute &&
              log.status == DoseStatus.pending,
          orElse: () => null,
        );

        if (existingLog != null) {
          existingLog.status = action == 'take' ? DoseStatus.taken : DoseStatus.skipped;
          existingLog.actionTime = now;
          existingLog.pillsTaken = action == 'take' ? medication.pillsPerDose : 0;
          dbService.updateDoseLog(existingLog);
        } else {
          final newLog = DoseLog(
            id: '${medicationId}_${scheduledTime.millisecondsSinceEpoch}',
            medicationId: medicationId,
            scheduledTime: scheduledTime,
            actionTime: now,
            status: action == 'take' ? DoseStatus.taken : DoseStatus.skipped,
            pillsTaken: action == 'take' ? medication.pillsPerDose : 0,
          );
          dbService.addDoseLog(newLog);
        }

        if (action == 'take') {
          dbService.decrementStock(medicationId, medication.pillsPerDose);
        }

        // Cancel follow-up notifications
        final tag = 'med_${medicationId}_$reminderIndex';
        final notificationService = NotificationService();
        await notificationService._cancelFollowUpReminders(medicationId, reminderIndex, tag);

        debugPrint('NotificationService: Background action completed');
      }
    } catch (e) {
      debugPrint('NotificationService: Background error: $e');
    }
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Callback for when user takes/skips from notification
  Function(String medicationId, String action, DateTime scheduledTime)? onNotificationAction;

  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone
    tz_data.initializeTimeZones();

    String timeZoneName;
    try {
      timeZoneName = await FlutterTimezone.getLocalTimezone();
      debugPrint('NotificationService: FlutterTimezone returned: $timeZoneName');

      // If it returns UTC but device offset suggests otherwise, find the correct timezone
      if (timeZoneName == 'UTC') {
        final deviceOffset = DateTime.now().timeZoneOffset;
        if (deviceOffset.inMinutes != 0) {
          timeZoneName = _findTimezoneByOffset(deviceOffset);
          debugPrint('NotificationService: Using offset-based timezone: $timeZoneName');
        }
      }
    } catch (e) {
      debugPrint('NotificationService: FlutterTimezone error: $e');
      // Fallback based on device offset
      final deviceOffset = DateTime.now().timeZoneOffset;
      timeZoneName = _findTimezoneByOffset(deviceOffset);
      debugPrint('NotificationService: Fallback timezone: $timeZoneName');
    }

    try {
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint('NotificationService: Failed to set timezone $timeZoneName: $e');
      // Ultimate fallback - use UTC
      tz.setLocalLocation(tz.UTC);
      debugPrint('NotificationService: Using UTC as fallback');
    }

    // Android settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // Initialize
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Request permissions for Android 13+
    await _requestPermissions();

    _initialized = true;
  }

  Future<void> _requestPermissions() async {
    final androidPlugin =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('NotificationService: Notification tapped - actionId: ${response.actionId}, payload: ${response.payload}');

    // Handle notification action buttons
    if (response.payload != null && response.actionId != null) {
      try {
        final payload = json.decode(response.payload!);
        final medicationId = payload['medicationId'] as String;
        final scheduledTimeMillis = payload['scheduledTime'] as int;
        final scheduledTime = DateTime.fromMillisecondsSinceEpoch(scheduledTimeMillis);
        final reminderIndex = payload['reminderIndex'] as int? ?? 0;
        final action = response.actionId!;

        debugPrint('NotificationService: Parsed - medicationId: $medicationId, action: $action, scheduledTime: $scheduledTime');

        if (action == 'take' || action == 'skip') {
          // Dismiss the current notification and cancel all follow-ups
          final tag = 'med_${medicationId}_$reminderIndex';

          // Cancel by ID with tag to dismiss displayed notification
          if (response.id != null) {
            _notifications.cancel(response.id!, tag: tag);
          }

          // Cancel all follow-up reminders for this dose
          _cancelFollowUpReminders(medicationId, reminderIndex, tag);

          // Trigger callback to update dose log
          debugPrint('NotificationService: Calling onNotificationAction callback');
          onNotificationAction?.call(medicationId, action, scheduledTime);
        }
      } catch (e) {
        debugPrint('NotificationService: Error handling notification tap: $e');
      }
    }
  }

  Future<void> _cancelFollowUpReminders(String medicationId, int reminderIndex, String tag) async {
    // Cancel all follow-up notifications (12 reminders over 3 hours)
    for (int i = 0; i < 12; i++) {
      final followUpId = _generateFollowUpId(medicationId, reminderIndex, i);
      await _notifications.cancel(followUpId, tag: tag);
    }
  }

  int _generateFollowUpId(String medicationId, int reminderIndex, int followUpIndex) {
    final hash = medicationId.hashCode.abs();
    return (hash % 1000) * 100000 + reminderIndex * 1000 + followUpIndex;
  }

  Future<void> scheduleMedicationReminders(Medication medication) async {
    // Cancel existing notifications for this medication
    await cancelMedicationReminders(medication.id);

    // Don't schedule if no reminder days selected
    if (medication.reminderDays.isEmpty) {
      debugPrint('NotificationService: No reminder days for ${medication.name}');
      return;
    }

    debugPrint('NotificationService: Scheduling ${medication.name}');
    debugPrint('NotificationService: Times: ${medication.scheduledTimes}');
    debugPrint('NotificationService: Days: ${medication.reminderDays}');

    // Schedule notification for each time slot
    for (int i = 0; i < medication.scheduledTimes.length; i++) {
      final timeStr = medication.scheduledTimes[i];
      final timeParts = timeStr.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      // Schedule for each reminder day
      for (final day in medication.reminderDays) {
        final reminderIndex = i * 7 + day;

        await _scheduleWeeklyNotificationWithFollowUps(
          medicationName: medication.name,
          pillsPerDose: medication.pillsPerDose,
          dosage: medication.dosage,
          hour: hour,
          minute: minute,
          weekday: day,
          medicationId: medication.id,
          reminderIndex: reminderIndex,
        );
      }
    }
  }

  Future<void> _scheduleWeeklyNotificationWithFollowUps({
    required String medicationName,
    required int pillsPerDose,
    required String dosage,
    required int hour,
    required int minute,
    required int weekday,
    required String medicationId,
    required int reminderIndex,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = _nextInstanceOfWeekdayTime(now, weekday, hour, minute);

    debugPrint('NotificationService: Scheduling $medicationName for weekday $weekday at $hour:$minute');
    debugPrint('NotificationService: Next occurrence: $scheduledDate');
    debugPrint('NotificationService: Current time: $now');

    final title = 'Time to take $medicationName';
    final body = '$pillsPerDose ${pillsPerDose == 1 ? 'pill' : 'pills'}${dosage.isNotEmpty ? ' - $dosage' : ''}';

    // Schedule initial notification + 11 follow-ups (every 15 min for 3 hours)
    // Android has a limit of 500 concurrent alarms
    // 12 notifications per slot = ~41 reminder slots capacity
    for (int i = 0; i < 12; i++) {
      final followUpDate = scheduledDate.add(Duration(minutes: i * 15));
      final followUpId = _generateFollowUpId(medicationId, reminderIndex, i);

      final payload = json.encode({
        'medicationId': medicationId,
        'scheduledTime': scheduledDate.millisecondsSinceEpoch,
        'reminderIndex': reminderIndex,
      });

      await _notifications.zonedSchedule(
        followUpId,
        i == 0 ? title : 'Reminder: $title',
        i == 0 ? body : 'You haven\'t taken your medication yet.',
        followUpDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'medication_reminders',
            'Medication Reminders',
            channelDescription: 'Notifications for medication reminders',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            enableVibration: true,
            playSound: true,
            tag: 'med_${medicationId}_$reminderIndex', // Same tag replaces previous notification
            actions: <AndroidNotificationAction>[
              const AndroidNotificationAction(
                'take',
                'Take',
              ),
              const AndroidNotificationAction(
                'skip',
                'Skip',
              ),
            ],
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime, // Make ALL recurring
        payload: payload,
      );
    }
  }

  tz.TZDateTime _nextInstanceOfWeekdayTime(
    tz.TZDateTime now,
    int weekday,
    int hour,
    int minute,
  ) {
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // Find next occurrence of the weekday
    while (scheduledDate.weekday != weekday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // If the time has passed today, schedule for next week
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }

    return scheduledDate;
  }

  int _generateNotificationId(String medicationId, int timeIndex, int day) {
    // Generate a unique ID based on medication, time index, and day
    final hash = medicationId.hashCode.abs();
    return (hash % 10000) * 100 + timeIndex * 10 + day;
  }

  /// Find a timezone name based on UTC offset
  String _findTimezoneByOffset(Duration offset) {
    final offsetHours = offset.inHours;
    final offsetMinutes = offset.inMinutes % 60;

    // Map common offsets to timezone names
    final offsetMap = {
      6 * 60: 'Asia/Dhaka',        // UTC+6
      5 * 60 + 30: 'Asia/Kolkata', // UTC+5:30
      5 * 60: 'Asia/Karachi',      // UTC+5
      8 * 60: 'Asia/Singapore',    // UTC+8
      9 * 60: 'Asia/Tokyo',        // UTC+9
      7 * 60: 'Asia/Bangkok',      // UTC+7
      3 * 60: 'Europe/Moscow',     // UTC+3
      1 * 60: 'Europe/Paris',      // UTC+1
      0: 'UTC',                    // UTC+0
      -5 * 60: 'America/New_York', // UTC-5
      -6 * 60: 'America/Chicago',  // UTC-6
      -7 * 60: 'America/Denver',   // UTC-7
      -8 * 60: 'America/Los_Angeles', // UTC-8
    };

    final totalMinutes = offsetHours * 60 + offsetMinutes;
    return offsetMap[totalMinutes] ?? 'UTC';
  }

  Future<void> cancelMedicationReminders(String medicationId) async {
    // Cancel all possible notifications for this medication
    // We generate IDs for all possible combinations
    for (int timeIndex = 0; timeIndex < 10; timeIndex++) {
      for (int day = 1; day <= 7; day++) {
        final id = _generateNotificationId(medicationId, timeIndex, day);
        await _notifications.cancel(id);
      }
    }
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Cancel a specific notification for a medication at a given time
  Future<void> cancelNotificationForDose(
    String medicationId,
    int timeIndex,
    int weekday,
  ) async {
    final id = _generateNotificationId(medicationId, timeIndex, weekday);
    await _notifications.cancel(id);
  }

  /// Get the notification ID for external use
  int getNotificationId(String medicationId, int timeIndex, int weekday) {
    return _generateNotificationId(medicationId, timeIndex, weekday);
  }

  Future<void> showTestNotification() async {
    await _notifications.show(
      0,
      'Test Notification',
      'Notifications are working!',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'medication_reminders',
          'Medication Reminders',
          channelDescription: 'Notifications for medication reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  /// Schedule a test notification 5 seconds from now
  Future<void> scheduleTestNotification() async {
    final scheduledDate = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5));

    await _notifications.zonedSchedule(
      999,
      'Scheduled Test',
      'This notification was scheduled 5 seconds ago!',
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'medication_reminders',
          'Medication Reminders',
          channelDescription: 'Notifications for medication reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
