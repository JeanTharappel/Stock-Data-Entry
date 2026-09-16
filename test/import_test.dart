import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xlsx;
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_data_entry/export/export_service.dart';
import 'package:stock_data_entry/import/import_service.dart';
import 'package:stock_data_entry/import/picked_file.dart';
import 'package:stock_data_entry/models/dividend_rate.dart';
import 'package:stock_data_entry/models/price_range.dart';

/// Import is only worth having if what the app exports comes back unchanged,
/// so most of these feed real export output straight back in.
void main() {
  final dividends = <DividendRate>[
    DividendRate(ccode: 'ACME', entryDate: '050826', divRate: 12.5),
    DividendRate(ccode: 'B-2.CO', entryDate: '311299', divRate: 0),
    DividendRate(ccode: 'ABCDEFGHIJ', entryDate: '010170', divRate: 99.9),
  ];
  final prices = <PriceRange>[
    PriceRange(ccode: 'ACME', entryDate: '050826', lowVal: 120, highVal: 4500),
    PriceRange(ccode: 'ZED', entryDate: '290224', lowVal: 0, highVal: 99999),
  ];

  PickedFile file(String name, List<int> bytes) =>
      PickedFile(name: name, bytes: Uint8List.fromList(bytes));

  PickedFile text(String name, String content) =>
      file(name, utf8.encode(content));

  List<String> dividendValues(List<DividendRate> records) => [
    for (final r in records) '${r.ccode}|${r.entryDate}|${r.divRate}',
  ];

  List<String> priceValues(List<PriceRange> records) => [
    for (final r in records)
      '${r.ccode}|${r.entryDate}|${r.lowVal}|${r.highVal}',
  ];

  group('what the app exports comes back unchanged', () {
    for (final format in ExportFormat.values) {
      test('dividend rates as ${format.label}', () {
        final result = ImportService.readDividendRates(
          file(
            'dividend_rate.${format.extension}',
            ExportService.dividendRateBytes(dividends, format),
          ),
        );
        expect(result.problems, isEmpty);
        expect(dividendValues(result.records), dividendValues(dividends));
      });

      test('price ranges as ${format.label}', () {
        final result = ImportService.readPriceRanges(
          file(
            'price_range.${format.extension}',
            ExportService.priceRangeBytes(prices, format),
          ),
        );
        expect(result.problems, isEmpty);
        expect(priceValues(result.records), priceValues(prices));
      });
    }

    test('the file extension is read whatever its case', () {
      final result = ImportService.readDividendRates(
        file(
          'BACKUP.CSV',
          ExportService.dividendRateBytes(dividends, ExportFormat.csv),
        ),
      );
      expect(result.isOk, isTrue);
    });
  });

  group('the wrong kind of file is named, not half-read', () {
    for (final format in ExportFormat.values) {
      test('a price range ${format.label} on the dividend rate tab', () {
        final result = ImportService.readDividendRates(
          file(
            'price_range.${format.extension}',
            ExportService.priceRangeBytes(prices, format),
          ),
        );
        expect(result.records, isEmpty);
        expect(result.problems, <String>[
          'THIS IS A PRICE RANGE FILE, NOT A DIVIDEND RATE FILE. '
              'IMPORT IT ON THE PRICE RANGE ENTRY TAB INSTEAD.',
        ]);
      });
    }

    test('a file type the export never makes', () {
      final result = ImportService.readPriceRanges(text('notes.pdf', 'x'));
      expect(result.problems.single, contains('CHOOSE A CSV, XLSX OR TXT'));
    });

    test('a CSV that did not come from this app', () {
      final result = ImportService.readPriceRanges(
        text('other.csv', 'NAME,AGE\nBOB,40\n'),
      );
      expect(result.problems.single, contains('ITS FIRST ROW SHOULD BE'));
    });

    test('a damaged XLSX', () {
      final result = ImportService.readDividendRates(
        text('broken.xlsx', 'this is not a workbook'),
      );
      expect(result.problems.single, contains('COULD NOT BE READ'));
    });

    test('a file with a header and nothing else', () {
      final result = ImportService.readDividendRates(
        file(
          'empty.csv',
          ExportService.dividendRateBytes([], ExportFormat.csv),
        ),
      );
      expect(result.problems.single, 'THERE ARE NO RECORDS IN THIS FILE.');
    });
  });

  group('bad rows stop the whole import and say where they are', () {
    test('every bad CSV row is listed by its spreadsheet row number', () {
      final result = ImportService.readDividendRates(
        text(
          'dividend_rate.csv',
          '${ExportService.dividendRateHeader.join(',')}\n'
              'ACME,050826,,12.5\n'
              'ACME,310226,,12.5\n' // no 31st of February
              'ACME,050826,,123.4\n', // wider than the field
        ),
      );
      expect(result.records, isEmpty);
      expect(result.problems, <Object>[
        'ROW 3: DATE IS NOT VALID. ENTER AS DD MM YY.',
        startsWith('ROW 4: DIVIDEND RATE IS TOO BIG.'),
      ]);
    });

    test('a price range with high below low is refused like the form does', () {
      final result = ImportService.readPriceRanges(
        text('price_range.txt', 'ACME      0508260050000100\r\n'),
      );
      expect(
        result.problems.single,
        startsWith('LINE 1: HIGH VALUE IS SMALLER'),
      );
    });

    test('a TXT line of the wrong width', () {
      final result = ImportService.readDividendRates(
        text('dividend_rate.txt', 'ACME      050826125\r\nACME 050826125\r\n'),
      );
      expect(
        result.problems.single,
        'LINE 2: THIS LINE IS 14 CHARACTERS LONG. '
        'EVERY DIVIDEND RATE LINE MUST BE EXACTLY 19.',
      );
    });

    test('a row with columns missing', () {
      final result = ImportService.readPriceRanges(
        text(
          'price_range.csv',
          '${ExportService.priceRangeHeader.join(',')}\nACME,050826\n',
        ),
      );
      expect(result.problems.single, 'ROW 2: SOME OF THE COLUMNS ARE EMPTY.');
    });
  });

  group('changes a spreadsheet program makes on re-saving are tolerated', () {
    test('a date that lost its leading zero', () {
      final result = ImportService.readDividendRates(
        text(
          'dividend_rate.csv',
          '${ExportService.dividendRateHeader.join(',')}\r\n'
              'ACME,50826,05 AUGUST 2026,12.5\r\n',
        ),
      );
      expect(result.records.single.entryDate, '050826');
    });

    test('blank rows, lower-case codes and a semicolon separator', () {
      final result = ImportService.readPriceRanges(
        text(
          'price_range.csv',
          '${ExportService.priceRangeHeader.join(';')}\n'
              '\n'
              'acme;050826;;100;250\n'
              ';;;;\n',
        ),
      );
      expect(result.problems, isEmpty);
      expect(priceValues(result.records), <String>['ACME|050826|100|250']);
    });

    test('numbers stored as decimals in an XLSX', () {
      final book = xlsx.Excel.createExcel();
      final sheet = book[book.getDefaultSheet()!];
      sheet.appendRow([
        for (final heading in ExportService.priceRangeHeader)
          xlsx.TextCellValue(heading),
      ]);
      sheet.appendRow([
        xlsx.TextCellValue('ACME'),
        xlsx.DoubleCellValue(50826),
        null,
        xlsx.DoubleCellValue(100),
        xlsx.DoubleCellValue(250),
      ]);

      final result = ImportService.readPriceRanges(
        file('price_range.xlsx', book.encode()!),
      );
      expect(result.problems, isEmpty);
      expect(priceValues(result.records), <String>['ACME|050826|100|250']);
    });
  });
}
