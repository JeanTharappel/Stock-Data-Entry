/// Field widths and value ranges taken from the original COBOL-style flat-file
/// record descriptions. Everything that needs to know "how wide is this field"
/// reads it from here, so the forms, the validators and the fixed-width TXT
/// export can never drift apart.
library;

/// DIVIDEND-RATE record.
///
/// ```
/// 01  DIVIDEND-RATE-REC.
///     05  DR-CCODE       PIC X(10).
///     05  DR-DATE        PIC 9(6).      *> DDMMYY
///     05  DR-RATE        PIC 9(2)V9.    *> 3 digits, 1 implied decimal
/// ```
abstract final class DividendRateSpec {
  static const int ccodeWidth = 10;
  static const int dateWidth = 6;

  /// Total digit positions for the rate (integer digits + decimal digits).
  static const int rateWidth = 3;

  /// Digits after the decimal point.
  static const int rateDecimals = 1;

  /// Largest storable rate: 99.9 for a 3-digit / 1-decimal field.
  static double get maxRate =>
      (_pow10(rateWidth) - 1) / _pow10(rateDecimals).toDouble();

  static const int recordWidth = ccodeWidth + dateWidth + rateWidth;
}

/// PRICE-RANGE record.
///
/// ```
/// 01  PRICE-RANGE-REC.
///     05  PR-CCODE       PIC X(10).
///     05  PR-DATE        PIC 9(6).      *> DDMMYY
///     05  PR-LOW         PIC 9(5).
///     05  PR-HIGH        PIC 9(5).
/// ```
abstract final class PriceRangeSpec {
  static const int ccodeWidth = 10;
  static const int dateWidth = 6;
  static const int valueWidth = 5;

  /// Largest storable low/high value: 99999 for a 5-digit field.
  static int get maxValue => _pow10(valueWidth) - 1;

  static const int recordWidth =
      ccodeWidth + dateWidth + valueWidth + valueWidth;
}

int _pow10(int n) {
  var result = 1;
  for (var i = 0; i < n; i++) {
    result *= 10;
  }
  return result;
}

/// Left-justified, space-padded alphanumeric field (COBOL `PIC X(n)`).
String padAlpha(String value, int width) {
  final trimmed = value.length > width ? value.substring(0, width) : value;
  return trimmed.padRight(width);
}

/// Right-justified, zero-padded numeric field (COBOL `PIC 9(n)`).
///
/// Values wider than the field keep their low-order digits, matching how a
/// COBOL `MOVE` into a smaller numeric field truncates on the left. Validation
/// should stop this happening in the first place.
String padNumeric(int value, int width) {
  final digits = value.abs().toString();
  if (digits.length > width) {
    return digits.substring(digits.length - width);
  }
  return digits.padLeft(width, '0');
}

/// Zero-padded numeric field with an *implied* decimal point
/// (COBOL `PIC 9(n)V9(d)`), e.g. 12.5 with width 3 / 1 decimal -> `125`.
String padImpliedDecimal(double value, int width, int decimals) {
  final scaled = (value.abs() * _pow10(decimals)).round();
  return padNumeric(scaled, width);
}
