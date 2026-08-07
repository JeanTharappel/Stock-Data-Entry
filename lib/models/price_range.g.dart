// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'price_range.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PriceRangeAdapter extends TypeAdapter<PriceRange> {
  @override
  final typeId = 2;

  @override
  PriceRange read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PriceRange(
      ccode: fields[0] as String,
      entryDate: fields[1] as String,
      lowVal: (fields[2] as num).toInt(),
      highVal: (fields[3] as num).toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, PriceRange obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.ccode)
      ..writeByte(1)
      ..write(obj.entryDate)
      ..writeByte(2)
      ..write(obj.lowVal)
      ..writeByte(3)
      ..write(obj.highVal);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PriceRangeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
