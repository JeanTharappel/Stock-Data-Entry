import 'package:flutter_test/flutter_test.dart';
import 'package:stock_data_entry/core/ddmmyy.dart';
import 'package:stock_data_entry/core/record_spec.dart';
import 'package:stock_data_entry/core/validators.dart';
import 'package:stock_data_entry/export/export_service.dart';
import 'package:stock_data_entry/models/dividend_rate.dart';
import 'package:stock_data_entry/models/price_range.dart';

void main() {
  group('DDMMYY dates', () {
    test('accepts a real date and windows the 2-digit year', () {
      expect(parseDdmmyy('050826'), DateTime(2026, 8, 5));
      expect(parseDdmmyy('311299'), DateTime(1999, 12, 31));
      expect(parseDdmmyy('010170'), DateTime(1970, 1, 1));
      expect(parseDdmmyy('010169'), DateTime(2069, 1, 1));
    });

    test('rejects dates that do not exist', () {
      expect(parseDdmmyy('310226'), isNull); // no 31st of February
      expect(parseDdmmyy('290225'), isNull); // 2025 is not a leap year
      expect(parseDdmmyy('290224'), isNotNull); // 2024 is
      expect(parseDdmmyy('001226'), isNull); // day zero
      expect(parseDdmmyy('051326'), isNull); // month 13
    });

    test('rejects anything that is not exactly six digits', () {
      expect(parseDdmmyy('5826'), isNull);
      expect(parseDdmmyy('05082026'), isNull);
      expect(parseDdmmyy('05AUG6'), isNull);
      expect(parseDdmmyy(null), isNull);
    });

    test('round-trips through formatting', () {
      expect(formatDdmmyy(DateTime(2026, 8, 5)), '050826');
      expect(formatDdmmyy(DateTime(1999, 12, 31)), '311299');
    });

    test('spells dates out for the reader', () {
      expect(spellOutDdmmyy('050826'), '05 AUGUST 2026');
      expect(shortSpellOutDdmmyy('311299'), '31 DEC 1999');
    });

    test('sorts unparseable dates last', () {
      expect(ddmmyySortKey('BADBAD'), greaterThan(ddmmyySortKey('311299')));
    });
  });

  group('validators', () {
    test('company code', () {
      expect(Validators.ccode('ACME'), isNull);
      expect(Validators.ccode('ABCDEFGHIJ'), isNull);
      expect(Validators.ccode(''), isNotNull);
      expect(Validators.ccode('ABCDEFGHIJK'), isNotNull); // 11 characters
      expect(Validators.ccode('ACME CORP'), isNotNull); // space not allowed
    });

    test('date parts produce the specified message', () {
      expect(Validators.dateParts(day: '05', month: '08', year: '26'), isNull);
      expect(
        Validators.dateParts(day: '31', month: '02', year: '26'),
        'DATE IS NOT VALID. ENTER AS DD MM YY.',
      );
      expect(Validators.dateParts(day: '05', month: '', year: '26'), isNotNull);
    });

    test('dividend rate fits 3 digits with 1 decimal place', () {
      expect(Validators.divRate('12.5'), isNull);
      expect(Validators.divRate('99.9'), isNull);
      expect(Validators.divRate('0'), isNull);
      expect(Validators.divRate('100.0'), isNotNull); // 4 digit positions
      expect(Validators.divRate('12.55'), isNotNull); // 2 decimal places
      expect(Validators.divRate('abc'), isNotNull);
      expect(Validators.divRate(''), isNotNull);
    });

    test('price values fit 5 digits and high is never below low', () {
      expect(Validators.priceValue('99999', fieldName: 'LOW VALUE'), isNull);
      expect(
        Validators.priceValue('100000', fieldName: 'LOW VALUE'),
        isNotNull,
      );
      expect(Validators.priceValue('12.5', fieldName: 'LOW VALUE'), isNotNull);
      expect(Validators.highNotBelowLow(low: '100', high: '100'), isNull);
      expect(Validators.highNotBelowLow(low: '100', high: '250'), isNull);
      expect(Validators.highNotBelowLow(low: '250', high: '100'), isNotNull);
    });
  });

  group('fixed-width padding', () {
    test('alphanumeric fields pad on the right', () {
      expect(padAlpha('ACME', 10), 'ACME      ');
      expect(padAlpha('ACME', 10).length, 10);
    });

    test('numeric fields zero-pad on the left', () {
      expect(padNumeric(42, 5), '00042');
      expect(padNumeric(99999, 5), '99999');
    });

    test('implied decimals drop the dot', () {
      expect(padImpliedDecimal(12.5, 3, 1), '125');
      expect(padImpliedDecimal(0, 3, 1), '000');
      expect(padImpliedDecimal(99.9, 3, 1), '999');
    });
  });

  group('TXT export matches the record spec', () {
    test('dividend rate records are 19 characters wide', () {
      final line = ExportService.dividendRateFixedWidth(<DividendRate>[
        DividendRate(ccode: 'ACME', entryDate: '050826', divRate: 12.5),
      ]);
      expect(line, 'ACME      050826125');
      expect(line.length, DividendRateSpec.recordWidth);
      expect(line.length, 19);
    });

    test('price range records are 26 characters wide', () {
      final line = ExportService.priceRangeFixedWidth(<PriceRange>[
        PriceRange(
          ccode: 'ACME',
          entryDate: '050826',
          lowVal: 120,
          highVal: 4500,
        ),
      ]);
      expect(line, 'ACME      0508260012004500');
      expect(line.length, PriceRangeSpec.recordWidth);
      expect(line.length, 26);
    });

    test('every line has the same width regardless of value length', () {
      final text = ExportService.priceRangeFixedWidth(<PriceRange>[
        PriceRange(ccode: 'A', entryDate: '010120', lowVal: 1, highVal: 2),
        PriceRange(
          ccode: 'LONGESTCODE',
          entryDate: '311299',
          lowVal: 99999,
          highVal: 99999,
        ),
      ]);
      for (final line in text.split('\r\n')) {
        expect(line.length, PriceRangeSpec.recordWidth);
      }
    });

    test('no records produces an empty file, not a blank line', () {
      expect(ExportService.dividendRateFixedWidth(<DividendRate>[]), '');
    });
  });

  group('CSV and XLSX rows', () {
    test('carry a header plus one row per record', () {
      final rows = ExportService.dividendRateRows(<DividendRate>[
        DividendRate(ccode: 'ACME', entryDate: '050826', divRate: 12.5),
      ]);
      expect(rows.first, ExportService.dividendRateHeader);
      expect(rows[1], <Object?>['ACME', '050826', '05 AUGUST 2026', '12.5']);
    });
  });
}
