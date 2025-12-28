import 'package:hive/hive.dart';

part 'medication.g.dart';

@HiveType(typeId: 0)
class Medication extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String dosage;

  @HiveField(3)
  int pillsPerDose;

  @HiveField(4)
  List<String> scheduledTimes; // Stored as "HH:mm" strings

  @HiveField(5)
  int currentStock;

  @HiveField(6)
  int lowStockThreshold;

  @HiveField(7)
  int colorIndex;

  @HiveField(8)
  String? notes;

  @HiveField(9)
  bool isActive;

  @HiveField(10)
  DateTime createdAt;

  @HiveField(11)
  List<int> reminderDays; // 1=Mon, 2=Tue, ..., 7=Sun

  Medication({
    required this.id,
    required this.name,
    required this.dosage,
    this.pillsPerDose = 1,
    required this.scheduledTimes,
    required this.currentStock,
    this.lowStockThreshold = 10,
    this.colorIndex = 0,
    this.notes,
    this.isActive = true,
    DateTime? createdAt,
    List<int>? reminderDays,
  })  : createdAt = createdAt ?? DateTime.now(),
        reminderDays = reminderDays ?? []; // Default: no days selected

  bool get isLowStock => currentStock <= lowStockThreshold;

  Medication copyWith({
    String? id,
    String? name,
    String? dosage,
    int? pillsPerDose,
    List<String>? scheduledTimes,
    int? currentStock,
    int? lowStockThreshold,
    int? colorIndex,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    List<int>? reminderDays,
  }) {
    return Medication(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      pillsPerDose: pillsPerDose ?? this.pillsPerDose,
      scheduledTimes: scheduledTimes ?? this.scheduledTimes,
      currentStock: currentStock ?? this.currentStock,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      colorIndex: colorIndex ?? this.colorIndex,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      reminderDays: reminderDays ?? this.reminderDays,
    );
  }
}
