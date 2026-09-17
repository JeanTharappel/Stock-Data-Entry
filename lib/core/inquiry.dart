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

/// The other inquiry: one calendar month, every company.
///
/// The month is given as `MM` and `YY`, the same two parts the stored date
/// carries, and the 2-digit year is widened by the same century rule the rest
/// of the app uses - so `08` `26` means August 2026.
class MonthInquiry {
  MonthInquiry({required this.month, required int twoDigitYear})
    : year = expandYear(twoDigitYear);

  /// 1 for January through 12 for December.
  final int month;

  /// The full 4-digit year.
  final int year;

  /// True when a record stored on [entryDate] falls in this month.
  bool matches(String entryDate) {
    final date = parseDdmmyy(entryDate);
    if (date == null) return false;
    return date.month == month && date.year == year;
  }

  /// The month in words, e.g. `AUGUST 2026`.
  String describe() => '${monthName(month)} $year';
}
