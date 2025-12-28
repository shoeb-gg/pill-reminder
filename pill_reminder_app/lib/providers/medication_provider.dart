import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/medication.dart';
import '../models/dose_log.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

// Database service provider
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

// UUID generator
const _uuid = Uuid();

// Medications provider
final medicationsProvider =
    StateNotifierProvider<MedicationsNotifier, List<Medication>>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return MedicationsNotifier(dbService);
});

class MedicationsNotifier extends StateNotifier<List<Medication>> {
  final DatabaseService _dbService;

  MedicationsNotifier(this._dbService) : super([]) {
    _loadMedications();
  }

  void _loadMedications() {
    state = _dbService.getAllMedications();
  }

  Future<void> addMedication({
    required String name,
    required String dosage,
    required int pillsPerDose,
    required List<String> scheduledTimes,
    required int currentStock,
    int lowStockThreshold = 10,
    int colorIndex = 0,
    String? notes,
    List<int>? reminderDays,
  }) async {
    final medication = Medication(
      id: _uuid.v4(),
      name: name,
      dosage: dosage,
      pillsPerDose: pillsPerDose,
      scheduledTimes: scheduledTimes,
      currentStock: currentStock,
      lowStockThreshold: lowStockThreshold,
      colorIndex: colorIndex,
      notes: notes,
      reminderDays: reminderDays,
    );

    await _dbService.addMedication(medication);
    _loadMedications();

    // Schedule notifications for this medication
    await NotificationService().scheduleMedicationReminders(medication);
  }

  Future<void> updateMedication(Medication medication) async {
    await _dbService.updateMedication(medication);
    _loadMedications();

    // Reschedule notifications for this medication
    await NotificationService().scheduleMedicationReminders(medication);
  }

  Future<void> deleteMedication(String id) async {
    // Cancel notifications before deleting
    await NotificationService().cancelMedicationReminders(id);

    await _dbService.deleteMedication(id);
    _loadMedications();
  }

  Future<void> updateStock(String medicationId, int newStock) async {
    await _dbService.updateStock(medicationId, newStock);
    _loadMedications();
  }

  Future<void> decrementStock(String medicationId, int amount) async {
    await _dbService.decrementStock(medicationId, amount);
    _loadMedications();
  }
}

// Active medications provider
final activeMedicationsProvider = Provider<List<Medication>>((ref) {
  final medications = ref.watch(medicationsProvider);
  return medications.where((m) => m.isActive).toList();
});

// Low stock medications provider
final lowStockMedicationsProvider = Provider<List<Medication>>((ref) {
  final medications = ref.watch(medicationsProvider);
  return medications.where((m) => m.isActive && m.isLowStock).toList();
});

// Dose logs provider
final doseLogsProvider =
    StateNotifierProvider<DoseLogsNotifier, List<DoseLog>>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return DoseLogsNotifier(dbService);
});

class DoseLogsNotifier extends StateNotifier<List<DoseLog>> {
  final DatabaseService _dbService;

  DoseLogsNotifier(this._dbService) : super([]);

  void loadLogsForDate(DateTime date) {
    state = _dbService.getDoseLogsForDate(date);
  }

  void loadLogsInRange(DateTime start, DateTime end) {
    state = _dbService.getDoseLogsInRange(start, end);
  }

  Future<void> addDoseLog(DoseLog log) async {
    await _dbService.addDoseLog(log);
    // Refresh the state based on the log's date
    loadLogsForDate(log.scheduledTime);
  }

  Future<void> markDoseTaken(DoseLog log, int pillsTaken, {Medication? medication}) async {
    final updatedLog = log.copyWith(
      status: DoseStatus.taken,
      actionTime: DateTime.now(),
      pillsTaken: pillsTaken,
    );
    await _dbService.updateDoseLog(updatedLog);
    loadLogsForDate(log.scheduledTime);

    // Cancel the notification for this dose
    if (medication != null) {
      _cancelNotificationForDose(log, medication);
    }
  }

  Future<void> markDoseSkipped(DoseLog log, {Medication? medication}) async {
    final updatedLog = log.copyWith(
      status: DoseStatus.skipped,
      actionTime: DateTime.now(),
    );
    await _dbService.updateDoseLog(updatedLog);
    loadLogsForDate(log.scheduledTime);

    // Cancel the notification for this dose
    if (medication != null) {
      _cancelNotificationForDose(log, medication);
    }
  }

  void _cancelNotificationForDose(DoseLog log, Medication medication) {
    // Find the time index for this scheduled time
    final scheduledTimeStr =
        '${log.scheduledTime.hour.toString().padLeft(2, '0')}:${log.scheduledTime.minute.toString().padLeft(2, '0')}';
    final timeIndex = medication.scheduledTimes.indexOf(scheduledTimeStr);

    if (timeIndex >= 0) {
      final weekday = log.scheduledTime.weekday;
      NotificationService().cancelNotificationForDose(
        medication.id,
        timeIndex,
        weekday,
      );
    }
  }

  Future<void> markDoseMissed(DoseLog log) async {
    final updatedLog = log.copyWith(
      status: DoseStatus.missed,
      actionTime: DateTime.now(),
    );
    await _dbService.updateDoseLog(updatedLog);
    loadLogsForDate(log.scheduledTime);
  }
}

// Today's doses provider
final todaysDosesProvider = Provider<List<DoseLog>>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.getDoseLogsForDate(DateTime.now());
});

// Selected date provider for history screen
final selectedDateProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

// Doses for selected date
final dosesForSelectedDateProvider = Provider<List<DoseLog>>((ref) {
  final selectedDate = ref.watch(selectedDateProvider);
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.getDoseLogsForDate(selectedDate);
});
