import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/medication.dart';
import 'models/dose_log.dart';
import 'theme/app_theme.dart';
import 'screens/main_screen.dart';
import 'services/notification_service.dart';
import 'services/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Register Hive adapters
  Hive.registerAdapter(MedicationAdapter());
  Hive.registerAdapter(DoseLogAdapter());
  Hive.registerAdapter(DoseStatusAdapter());

  // Open Hive boxes
  await Hive.openBox<Medication>('medications');
  await Hive.openBox<DoseLog>('dose_logs');

  // Initialize notifications
  await NotificationService().initialize();

  // Set up notification action callback
  final dbService = DatabaseService();
  NotificationService().onNotificationAction = (medicationId, action, scheduledTime) {
    // Find the dose log for this medication and time
    final logs = dbService.getDoseLogsForDate(scheduledTime);
    final log = logs.cast<DoseLog?>().firstWhere(
      (l) =>
          l?.medicationId == medicationId &&
          l?.scheduledTime.hour == scheduledTime.hour &&
          l?.scheduledTime.minute == scheduledTime.minute,
      orElse: () => null,
    );

    if (log != null) {
      if (action == 'take') {
        final medication = dbService.getMedication(medicationId);
        final pillsPerDose = medication?.pillsPerDose ?? 1;
        final updatedLog = log.copyWith(
          status: DoseStatus.taken,
          actionTime: DateTime.now(),
          pillsTaken: pillsPerDose,
        );
        dbService.updateDoseLog(updatedLog);
        // Decrement stock
        if (medication != null) {
          dbService.decrementStock(medicationId, pillsPerDose);
        }
      } else if (action == 'skip') {
        final updatedLog = log.copyWith(
          status: DoseStatus.skipped,
          actionTime: DateTime.now(),
        );
        dbService.updateDoseLog(updatedLog);
      }
    }
  };

  runApp(const ProviderScope(child: PillReminderApp()));
}

class PillReminderApp extends StatelessWidget {
  const PillReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pill Reminder',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainScreen(),
    );
  }
}
