import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../models/medication.dart';

// Callback for handling notification actions in background
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  // This will be handled when app opens
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

      // If it returns UTC but device offset suggests otherwise, find the correct timezone
      if (timeZoneName == 'UTC') {
        final deviceOffset = DateTime.now().timeZoneOffset;
        if (deviceOffset.inMinutes != 0) {
          timeZoneName = _findTimezoneByOffset(deviceOffset);
        }
      }
    } catch (e) {
      // Fallback based on device offset
      final deviceOffset = DateTime.now().timeZoneOffset;
      timeZoneName = _findTimezoneByOffset(deviceOffset);
    }

    tz.setLocalLocation(tz.getLocation(timeZoneName));

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
    // Handle notification action buttons
    if (response.payload != null && response.actionId != null) {
      final payload = json.decode(response.payload!);
      final medicationId = payload['medicationId'] as String;
      final scheduledTime = DateTime.parse(payload['scheduledTime'] as String);
      final action = response.actionId!;

      if (action == 'take' || action == 'skip') {
        // Cancel this specific notification
        if (response.id != null) {
          _notifications.cancel(response.id!);
        }

        // Trigger callback to update dose log
        onNotificationAction?.call(medicationId, action, scheduledTime);
      }
    }
  }

  Future<void> scheduleMedicationReminders(Medication medication) async {
    // Cancel existing notifications for this medication
    await cancelMedicationReminders(medication.id);

    // Don't schedule if no reminder days selected
    if (medication.reminderDays.isEmpty) {
      return;
    }

    // Schedule notification for each time slot
    for (int i = 0; i < medication.scheduledTimes.length; i++) {
      final timeStr = medication.scheduledTimes[i];
      final timeParts = timeStr.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      // Schedule for each reminder day
      for (final day in medication.reminderDays) {
        final notificationId = _generateNotificationId(medication.id, i, day);

        await _scheduleWeeklyNotification(
          id: notificationId,
          title: 'Time to take ${medication.name}',
          body: '${medication.pillsPerDose} ${medication.pillsPerDose == 1 ? 'pill' : 'pills'}${medication.dosage.isNotEmpty ? ' - ${medication.dosage}' : ''}',
          hour: hour,
          minute: minute,
          weekday: day,
          medicationId: medication.id,
        );
      }
    }
  }

  Future<void> _scheduleWeeklyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required int weekday,
    required String medicationId,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = _nextInstanceOfWeekdayTime(now, weekday, hour, minute);

    // Create payload with medication info
    final payload = json.encode({
      'medicationId': medicationId,
      'scheduledTime': scheduledDate.toIso8601String(),
    });

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
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
          ongoing: true, // Can't be swiped away
          autoCancel: false, // Don't dismiss on tap
          actions: <AndroidNotificationAction>[
            const AndroidNotificationAction(
              'take',
              'Take',
              showsUserInterface: true,
            ),
            const AndroidNotificationAction(
              'skip',
              'Skip',
              showsUserInterface: true,
            ),
          ],
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: payload,
    );
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
