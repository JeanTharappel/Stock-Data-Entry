// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dividend_rate.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DividendRateAdapter extends TypeAdapter<DividendRate> {
  @override
  final typeId = 1;

  @override
  DividendRate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DividendRate(
      ccode: fields[0] as String,
      entryDate: fields[1] as String,
      divRate: (fields[2] as num).toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, DividendRate obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.ccode)
      ..writeByte(1)
      ..write(obj.entryDate)
      ..writeByte(2)
      ..write(obj.divRate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DividendRateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
