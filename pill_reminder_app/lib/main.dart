import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/medication.dart';
import 'models/dose_log.dart';
import 'theme/app_theme.dart';
import 'screens/main_screen.dart';

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
