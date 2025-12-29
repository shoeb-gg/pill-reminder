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
    final medication = dbService.getMedication(medicationId);
    if (medication == null) return;

    // Create new dose log entry
    final newLog = DoseLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      medicationId: medicationId,
      scheduledTime: scheduledTime,
      actionTime: DateTime.now(),
      status: action == 'take' ? DoseStatus.taken : DoseStatus.skipped,
      pillsTaken: action == 'take' ? medication.pillsPerDose : 0,
    );

    dbService.addDoseLog(newLog);

    // Decrement stock if taken
    if (action == 'take') {
      dbService.decrementStock(medicationId, medication.pillsPerDose);
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
