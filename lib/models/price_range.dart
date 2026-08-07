import 'package:hive_ce/hive.dart';

part 'price_range.g.dart';

/// One record of the PRICE-RANGE file.
@HiveType(typeId: 2)
class PriceRange extends HiveObject {
  PriceRange({
    required this.ccode,
    required this.entryDate,
    required this.lowVal,
    required this.highVal,
  });

  /// Company code, up to 10 characters, always stored upper-case.
  @HiveField(0)
  String ccode;

  /// Entry date as 6 characters, `DDMMYY`.
  @HiveField(1)
  String entryDate;

  /// Lowest price in the range. 5 digits, so 0 - 99999.
  @HiveField(2)
  int lowVal;

  /// Highest price in the range. 5 digits, never below [lowVal].
  @HiveField(3)
  int highVal;

  /// Identity used for the duplicate check: company code + date.
  String get identityKey => '$ccode|$entryDate';

  @override
  String toString() =>
      'PriceRange(ccode: $ccode, entryDate: $entryDate, '
      'lowVal: $lowVal, highVal: $highVal)';
}
