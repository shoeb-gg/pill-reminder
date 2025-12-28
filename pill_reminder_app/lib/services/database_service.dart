import 'package:hive/hive.dart';
import '../models/medication.dart';
import '../models/dose_log.dart';

class DatabaseService {
  static const String medicationsBoxName = 'medications';
  static const String doseLogsBoxName = 'dose_logs';

  Box<Medication> get medicationsBox => Hive.box<Medication>(medicationsBoxName);
  Box<DoseLog> get doseLogsBox => Hive.box<DoseLog>(doseLogsBoxName);

  // Medication CRUD operations
  Future<void> addMedication(Medication medication) async {
    await medicationsBox.put(medication.id, medication);
  }

  Future<void> updateMedication(Medication medication) async {
    await medicationsBox.put(medication.id, medication);
  }

  Future<void> deleteMedication(String id) async {
    await medicationsBox.delete(id);
    // Also delete related dose logs
    final logsToDelete = doseLogsBox.values
        .where((log) => log.medicationId == id)
        .map((log) => log.id)
        .toList();
    for (final logId in logsToDelete) {
      await doseLogsBox.delete(logId);
    }
  }

  Medication? getMedication(String id) {
    return medicationsBox.get(id);
  }

  List<Medication> getAllMedications() {
    return medicationsBox.values.toList();
  }

  List<Medication> getActiveMedications() {
    return medicationsBox.values.where((m) => m.isActive).toList();
  }

  List<Medication> getLowStockMedications() {
    return medicationsBox.values.where((m) => m.isActive && m.isLowStock).toList();
  }

  // Dose log operations
  Future<void> addDoseLog(DoseLog log) async {
    await doseLogsBox.put(log.id, log);
  }

  Future<void> updateDoseLog(DoseLog log) async {
    await doseLogsBox.put(log.id, log);
  }

  Future<void> deleteDoseLog(String id) async {
    await doseLogsBox.delete(id);
  }

  List<DoseLog> getDoseLogsForDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return doseLogsBox.values.where((log) {
      return log.scheduledTime.isAfter(startOfDay) &&
          log.scheduledTime.isBefore(endOfDay);
    }).toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
  }

  List<DoseLog> getDoseLogsForMedication(String medicationId) {
    return doseLogsBox.values
        .where((log) => log.medicationId == medicationId)
        .toList()
      ..sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
  }

  List<DoseLog> getDoseLogsInRange(DateTime start, DateTime end) {
    return doseLogsBox.values.where((log) {
      return log.scheduledTime.isAfter(start) && log.scheduledTime.isBefore(end);
    }).toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
  }

  // Update medication stock
  Future<void> decrementStock(String medicationId, int amount) async {
    final medication = getMedication(medicationId);
    if (medication != null) {
      medication.currentStock = (medication.currentStock - amount).clamp(0, 9999);
      await updateMedication(medication);
    }
  }

  Future<void> updateStock(String medicationId, int newStock) async {
    final medication = getMedication(medicationId);
    if (medication != null) {
      medication.currentStock = newStock.clamp(0, 9999);
      await updateMedication(medication);
    }
  }
}
