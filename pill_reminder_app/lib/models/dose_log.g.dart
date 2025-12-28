// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dose_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DoseLogAdapter extends TypeAdapter<DoseLog> {
  @override
  final int typeId = 2;

  @override
  DoseLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DoseLog(
      id: fields[0] as String,
      medicationId: fields[1] as String,
      scheduledTime: fields[2] as DateTime,
      actionTime: fields[3] as DateTime?,
      status: fields[4] as DoseStatus,
      pillsTaken: fields[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, DoseLog obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.medicationId)
      ..writeByte(2)
      ..write(obj.scheduledTime)
      ..writeByte(3)
      ..write(obj.actionTime)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.pillsTaken);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DoseLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DoseStatusAdapter extends TypeAdapter<DoseStatus> {
  @override
  final int typeId = 1;

  @override
  DoseStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return DoseStatus.taken;
      case 1:
        return DoseStatus.skipped;
      case 2:
        return DoseStatus.missed;
      case 3:
        return DoseStatus.pending;
      default:
        return DoseStatus.taken;
    }
  }

  @override
  void write(BinaryWriter writer, DoseStatus obj) {
    switch (obj) {
      case DoseStatus.taken:
        writer.writeByte(0);
        break;
      case DoseStatus.skipped:
        writer.writeByte(1);
        break;
      case DoseStatus.missed:
        writer.writeByte(2);
        break;
      case DoseStatus.pending:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DoseStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
