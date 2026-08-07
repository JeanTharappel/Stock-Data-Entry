/// Everything to do with the 6-character `DDMMYY` date field.
///
/// The original file spec stores a 2-digit year, so a windowing rule is
/// required to turn it back into a real year. We use the common COBOL
/// convention:
///
///   * `00`-`69` -> 2000-2069
///   * `70`-`99` -> 1970-1999
library;

/// Years `yy` <= this pivot are treated as 20yy, the rest as 19yy.
const int kCenturyPivot = 69;

const List<String> _monthNames = <String>[
  'JANUARY',
  'FEBRUARY',
  'MARCH',
  'APRIL',
  'MAY',
  'JUNE',
  'JULY',
  'AUGUST',
  'SEPTEMBER',
  'OCTOBER',
  'NOVEMBER',
  'DECEMBER',
];

/// Turns a 2-digit year into a 4-digit year using [kCenturyPivot].
int expandYear(int yy) => yy <= kCenturyPivot ? 2000 + yy : 1900 + yy;

/// Parses `DDMMYY` into a real [DateTime], or returns `null` when the string
/// is not exactly 6 digits or does not describe a date that actually exists
/// (e.g. `310226`, `000000`, `321299`).
DateTime? parseDdmmyy(String? raw) {
  if (raw == null || raw.length != 6) return null;
  if (!RegExp(r'^\d{6}$').hasMatch(raw)) return null;

  final day = int.parse(raw.substring(0, 2));
  final month = int.parse(raw.substring(2, 4));
  final year = expandYear(int.parse(raw.substring(4, 6)));

  return buildDate(day: day, month: month, year: year);
}

/// Builds a [DateTime] only if day/month/year name a date that really exists.
/// `DateTime(2026, 2, 31)` silently rolls over to March 3rd, so we check that
/// the constructed date still has the parts we asked for.
DateTime? buildDate({required int day, required int month, required int year}) {
  if (month < 1 || month > 12) return null;
  if (day < 1 || day > 31) return null;

  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

/// Formats a [DateTime] back into the 6-character `DDMMYY` storage form.
String formatDdmmyy(DateTime date) {
  final dd = date.day.toString().padLeft(2, '0');
  final mm = date.month.toString().padLeft(2, '0');
  final yy = (date.year % 100).toString().padLeft(2, '0');
  return '$dd$mm$yy';
}

/// Builds the 6-character storage form straight from the three form fields.
String composeDdmmyy(String dd, String mm, String yy) =>
    '${dd.padLeft(2, '0')}${mm.padLeft(2, '0')}${yy.padLeft(2, '0')}';

/// A long, unambiguous rendering for on-screen confirmation,
/// e.g. `05 AUGUST 2026`. Elderly users should never have to decode `050826`.
String spellOutDdmmyy(String? ddmmyy) {
  final date = parseDdmmyy(ddmmyy);
  if (date == null) return '';
  final dd = date.day.toString().padLeft(2, '0');
  return '$dd ${_monthNames[date.month - 1]} ${date.year}';
}

/// A short, still-unambiguous rendering for table cells, e.g. `05 AUG 2026`.
String shortSpellOutDdmmyy(String? ddmmyy) {
  final date = parseDdmmyy(ddmmyy);
  if (date == null) return ddmmyy ?? '';
  final dd = date.day.toString().padLeft(2, '0');
  return '$dd ${_monthNames[date.month - 1].substring(0, 3)} ${date.year}';
}

/// Sort key for a `DDMMYY` string. Unparseable values sort last so a bad row
/// can never hide at the top of the table.
int ddmmyySortKey(String ddmmyy) {
  final date = parseDdmmyy(ddmmyy);
  if (date == null) return 1 << 40;
  return date.millisecondsSinceEpoch;
}
