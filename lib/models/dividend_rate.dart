import 'package:hive_ce/hive.dart';

part 'dividend_rate.g.dart';

/// One record of the DIVIDEND-RATE file.
///
/// Extends [HiveObject] so each record carries the box key it was stored
/// under, which is what the EDIT and DELETE buttons act on.
@HiveType(typeId: 1)
class DividendRate extends HiveObject {
  DividendRate({
    required this.ccode,
    required this.entryDate,
    required this.divRate,
  });

  /// Company code, up to 10 characters, always stored upper-case.
  @HiveField(0)
  String ccode;

  /// Entry date as 6 characters, `DDMMYY`.
  @HiveField(1)
  String entryDate;

  /// Dividend rate. 3 digit positions with 1 decimal place, so 0.0 - 99.9.
  @HiveField(2)
  double divRate;

  /// Identity used for the duplicate check: company code + date.
  String get identityKey => '$ccode|$entryDate';

  @override
  String toString() =>
      'DividendRate(ccode: $ccode, entryDate: $entryDate, divRate: $divRate)';
}
