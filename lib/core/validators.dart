import 'ddmmyy.dart';
import 'record_spec.dart';

/// Field validation for both record types.
///
/// Every message is written to be read out loud and understood without any
/// technical vocabulary, and is returned in capitals to match the rest of the
/// interface. A `null` return means the value is acceptable.

abstract final class Validators {
  // -------------------------------------------------------------------------
  // COMPANY CODE
  // -------------------------------------------------------------------------

  /// Characters allowed in a company code.
  static final RegExp ccodePattern = RegExp(r'^[A-Z0-9.\-]+$');

  static String? ccode(String? raw, {int maxLength = 10}) {
    final value = (raw ?? '').trim().toUpperCase();
    if (value.isEmpty) {
      return 'COMPANY CODE IS MISSING. TYPE THE COMPANY CODE.';
    }
    if (value.length > maxLength) {
      return 'COMPANY CODE IS TOO LONG. '
          'USE $maxLength LETTERS OR NUMBERS AT MOST.';
    }
    if (!ccodePattern.hasMatch(value)) {
      return 'COMPANY CODE CAN ONLY USE LETTERS, NUMBERS, '
          'A FULL STOP OR A DASH.';
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // DATE (entered as three separate boxes: DD, MM, YY)
  // -------------------------------------------------------------------------

  static const String dateErrorMessage =
      'DATE IS NOT VALID. ENTER AS DD MM YY.';

  /// Validates the three date boxes together. They only make sense as a set,
  /// so one clear message is shown for the whole group rather than three.
  ///
  /// [fieldName] names the date in the message, for screens with more than
  /// one date on them.
  static String? dateParts({
    required String? day,
    required String? month,
    required String? year,
    String fieldName = 'DATE',
  }) {
    final dd = (day ?? '').trim();
    final mm = (month ?? '').trim();
    final yy = (year ?? '').trim();
    final notValid = '$fieldName IS NOT VALID. ENTER AS DD MM YY.';

    if (dd.isEmpty && mm.isEmpty && yy.isEmpty) {
      return '$fieldName IS MISSING. ENTER THE DAY, THE MONTH AND THE YEAR.';
    }
    if (dd.isEmpty || mm.isEmpty || yy.isEmpty) {
      return '$fieldName IS NOT COMPLETE. '
          'FILL IN THE DAY, THE MONTH AND THE YEAR.';
    }

    final dayNum = int.tryParse(dd);
    final monthNum = int.tryParse(mm);
    final yearNum = int.tryParse(yy);
    if (dayNum == null || monthNum == null || yearNum == null) {
      return notValid;
    }
    if (yy.length > 2 || dd.length > 2 || mm.length > 2) {
      return notValid;
    }

    if (buildDate(day: dayNum, month: monthNum, year: expandYear(yearNum)) ==
        null) {
      return notValid;
    }
    return null;
  }

  /// Cross-field rule for a date range: the TO date can equal the FROM date
  /// but never come before it. Both are `DDMMYY`; reported under TO DATE.
  static String? toNotBeforeFrom({required String? from, required String? to}) {
    final fromDate = parseDdmmyy(from);
    final toDate = parseDdmmyy(to);
    if (fromDate == null || toDate == null) return null;
    if (toDate.isBefore(fromDate)) {
      return 'TO DATE IS BEFORE THE FROM DATE. '
          'THE TO DATE MUST BE ${spellOutDdmmyy(from)} OR LATER.';
    }
    return null;
  }

  /// Validates an already-composed 6-character `DDMMYY` value.
  static String? ddmmyy(String? raw) =>
      parseDdmmyy(raw) == null ? dateErrorMessage : null;

  // -------------------------------------------------------------------------
  // DIVIDEND RATE - 3 digit positions, 1 decimal place, so 0.0 to 99.9
  // -------------------------------------------------------------------------

  static String? divRate(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) {
      return 'DIVIDEND RATE IS MISSING. TYPE A NUMBER, FOR EXAMPLE 12.5';
    }
    if (!RegExp(r'^\d*\.?\d*$').hasMatch(value) || value == '.') {
      return 'DIVIDEND RATE MUST BE A NUMBER, FOR EXAMPLE 12.5';
    }

    final dotIndex = value.indexOf('.');
    final wholePart = dotIndex == -1 ? value : value.substring(0, dotIndex);
    final decimalPart = dotIndex == -1 ? '' : value.substring(dotIndex + 1);

    if (decimalPart.length > DividendRateSpec.rateDecimals) {
      return 'DIVIDEND RATE CAN HAVE ONLY '
          '${DividendRateSpec.rateDecimals} NUMBER AFTER THE DOT.';
    }

    final wholeDigits =
        DividendRateSpec.rateWidth - DividendRateSpec.rateDecimals;
    if (wholePart.replaceFirst(RegExp(r'^0+(?=\d)'), '').length > wholeDigits) {
      return 'DIVIDEND RATE IS TOO BIG. '
          'THE LARGEST YOU CAN ENTER IS ${_formatMaxRate()}';
    }

    final parsed = double.tryParse(value);
    if (parsed == null) {
      return 'DIVIDEND RATE MUST BE A NUMBER, FOR EXAMPLE 12.5';
    }
    if (parsed > DividendRateSpec.maxRate) {
      return 'DIVIDEND RATE IS TOO BIG. '
          'THE LARGEST YOU CAN ENTER IS ${_formatMaxRate()}';
    }
    return null;
  }

  static String _formatMaxRate() =>
      DividendRateSpec.maxRate.toStringAsFixed(DividendRateSpec.rateDecimals);

  // -------------------------------------------------------------------------
  // PRICE RANGE - 5 digits each, high must not be below low
  // -------------------------------------------------------------------------

  static String? priceValue(String? raw, {required String fieldName}) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) {
      return '$fieldName IS MISSING. TYPE A WHOLE NUMBER.';
    }
    if (!RegExp(r'^\d+$').hasMatch(value)) {
      return '$fieldName MUST BE A WHOLE NUMBER WITH NO DOT.';
    }
    if (value.replaceFirst(RegExp(r'^0+(?=\d)'), '').length >
        PriceRangeSpec.valueWidth) {
      return '$fieldName IS TOO BIG. '
          'THE LARGEST YOU CAN ENTER IS ${PriceRangeSpec.maxValue}.';
    }
    final parsed = int.tryParse(value);
    if (parsed == null || parsed > PriceRangeSpec.maxValue) {
      return '$fieldName IS TOO BIG. '
          'THE LARGEST YOU CAN ENTER IS ${PriceRangeSpec.maxValue}.';
    }
    return null;
  }

  /// Cross-field rule: the high value can equal the low value but never
  /// fall below it. Reported under the HIGH field.
  static String? highNotBelowLow({
    required String? low,
    required String? high,
  }) {
    final lowNum = int.tryParse((low ?? '').trim());
    final highNum = int.tryParse((high ?? '').trim());
    if (lowNum == null || highNum == null) return null;
    if (highNum < lowNum) {
      return 'HIGH VALUE IS SMALLER THAN THE LOW VALUE. '
          'THE HIGH VALUE MUST BE $lowNum OR MORE.';
    }
    return null;
  }
}
