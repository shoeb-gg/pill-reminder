import 'package:hive/hive.dart';

part 'dose_log.g.dart';

@HiveType(typeId: 1)
enum DoseStatus {
  @HiveField(0)
  taken,

  @HiveField(1)
  skipped,

  @HiveField(2)
  missed,

  @HiveField(3)
  pending,
}

@HiveType(typeId: 2)
class DoseLog extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String medicationId;

  @HiveField(2)
  final DateTime scheduledTime;

  @HiveField(3)
  DateTime? actionTime;

  @HiveField(4)
  DoseStatus status;

  @HiveField(5)
  int pillsTaken;

  DoseLog({
    required this.id,
    required this.medicationId,
    required this.scheduledTime,
    this.actionTime,
    this.status = DoseStatus.pending,
    this.pillsTaken = 0,
  });

  DoseLog copyWith({
    String? id,
    String? medicationId,
    DateTime? scheduledTime,
    DateTime? actionTime,
    DoseStatus? status,
    int? pillsTaken,
  }) {
    return DoseLog(
      id: id ?? this.id,
      medicationId: medicationId ?? this.medicationId,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      actionTime: actionTime ?? this.actionTime,
      status: status ?? this.status,
      pillsTaken: pillsTaken ?? this.pillsTaken,
    );
  }
}
