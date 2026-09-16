import 'ddmmyy.dart';

/// What the INQUIRY tab searches for: one company, between two dates.
///
/// Both dates are inclusive, so FROM 01/01/26 TO 31/12/26 is the whole of
/// 2026. Matching compares real calendar dates, not the `DDMMYY` text - as
/// text, `311225` would sort after `010126`.
class InquiryCriteria {
  InquiryCriteria({
    required String ccode,
    required this.fromDate,
    required this.toDate,
  }) : ccode = ccode.trim().toUpperCase();

  /// Company code, upper-case to match how records are stored.
  final String ccode;

  /// First date to include, as `DDMMYY`.
  final String fromDate;

  /// Last date to include, as `DDMMYY`.
  final String toDate;

  /// True when a record with this company code and date belongs in the
  /// results. A record whose stored date cannot be read never matches.
  bool matches({required String ccode, required String entryDate}) {
    if (ccode != this.ccode) return false;
    final date = parseDdmmyy(entryDate);
    final from = parseDdmmyy(fromDate);
    final to = parseDdmmyy(toDate);
    if (date == null || from == null || to == null) return false;
    return !date.isBefore(from) && !date.isAfter(to);
  }

  /// The search in words, e.g. `ACME FROM 01 JANUARY 2026 TO 31 DECEMBER 2026`.
  String describe() =>
      '$ccode FROM ${spellOutDdmmyy(fromDate)} TO ${spellOutDdmmyy(toDate)}';
}
