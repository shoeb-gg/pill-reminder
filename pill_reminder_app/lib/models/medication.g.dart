// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medication.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MedicationAdapter extends TypeAdapter<Medication> {
  @override
  final int typeId = 0;

  @override
  Medication read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Medication(
      id: fields[0] as String,
      name: fields[1] as String,
      dosage: fields[2] as String,
      pillsPerDose: fields[3] as int,
      scheduledTimes: (fields[4] as List).cast<String>(),
      currentStock: fields[5] as int,
      lowStockThreshold: fields[6] as int,
      colorIndex: fields[7] as int,
      notes: fields[8] as String?,
      isActive: fields[9] as bool,
      createdAt: fields[10] as DateTime?,
      reminderDays: (fields[11] as List?)?.cast<int>(),
    );
  }

  @override
  void write(BinaryWriter writer, Medication obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.dosage)
      ..writeByte(3)
      ..write(obj.pillsPerDose)
      ..writeByte(4)
      ..write(obj.scheduledTimes)
      ..writeByte(5)
      ..write(obj.currentStock)
      ..writeByte(6)
      ..write(obj.lowStockThreshold)
      ..writeByte(7)
      ..write(obj.colorIndex)
      ..writeByte(8)
      ..write(obj.notes)
      ..writeByte(9)
      ..write(obj.isActive)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.reminderDays);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
