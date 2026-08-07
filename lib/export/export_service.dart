import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart' as csv_pkg;
import 'package:excel/excel.dart' as xlsx;

import '../core/ddmmyy.dart';
import '../core/record_spec.dart';
import '../models/dividend_rate.dart';
import '../models/price_range.dart';
import 'file_download.dart';

enum ExportFormat {
  csv('CSV', 'csv', 'text/csv'),
  xlsx(
    'XLSX',
    'xlsx',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  ),
  txt('TXT', 'txt', 'text/plain');

  const ExportFormat(this.label, this.extension, this.mimeType);

  final String label;
  final String extension;
  final String mimeType;
}

/// Builds the three export formats and hands them to the browser.
///
/// CSV and XLSX are for reading - they carry a spelled-out date column so a
/// spreadsheet never has to be decoded by eye. TXT is the faithful one: it
/// reproduces the original fixed-width record layout, byte for byte.
abstract final class ExportService {
  // -------------------------------------------------------------------------
  // DIVIDEND RATE
  // -------------------------------------------------------------------------

  static const List<String> dividendRateHeader = <String>[
    'CCODE',
    'ENTRY DATE (DDMMYY)',
    'DATE IN WORDS',
    'DIVIDEND RATE',
  ];

  static List<List<Object?>> dividendRateRows(List<DividendRate> records) => [
    dividendRateHeader,
    for (final record in records)
      <Object?>[
        record.ccode,
        record.entryDate,
        spellOutDdmmyy(record.entryDate),
        record.divRate.toStringAsFixed(DividendRateSpec.rateDecimals),
      ],
  ];

  /// One fixed-width line per record:
  /// `CCODE` 10 chars, `DATE` 6 chars, `RATE` 3 digits with an implied
  /// decimal point (12.5 is written `125`), total 19 characters.
  static String dividendRateFixedWidth(List<DividendRate> records) {
    final lines = records.map((record) {
      return padAlpha(record.ccode, DividendRateSpec.ccodeWidth) +
          padAlpha(record.entryDate, DividendRateSpec.dateWidth) +
          padImpliedDecimal(
            record.divRate,
            DividendRateSpec.rateWidth,
            DividendRateSpec.rateDecimals,
          );
    });
    return lines.join('\r\n');
  }

  static Future<void> exportDividendRates(
    List<DividendRate> records,
    ExportFormat format,
  ) {
    final fileName = _fileName('dividend_rate', format);
    return switch (format) {
      ExportFormat.csv => _download(
        _csvBytes(dividendRateRows(records)),
        fileName,
        format,
      ),
      ExportFormat.xlsx => _download(
        _xlsxBytes('DIVIDEND RATE', dividendRateRows(records)),
        fileName,
        format,
      ),
      ExportFormat.txt => _download(
        _textBytes(dividendRateFixedWidth(records)),
        fileName,
        format,
      ),
    };
  }

  // -------------------------------------------------------------------------
  // PRICE RANGE
  // -------------------------------------------------------------------------

  static const List<String> priceRangeHeader = <String>[
    'CCODE',
    'ENTRY DATE (DDMMYY)',
    'DATE IN WORDS',
    'LOW VALUE',
    'HIGH VALUE',
  ];

  static List<List<Object?>> priceRangeRows(List<PriceRange> records) => [
    priceRangeHeader,
    for (final record in records)
      <Object?>[
        record.ccode,
        record.entryDate,
        spellOutDdmmyy(record.entryDate),
        record.lowVal,
        record.highVal,
      ],
  ];

  /// One fixed-width line per record:
  /// `CCODE` 10 chars, `DATE` 6 chars, `LOW` 5 digits, `HIGH` 5 digits,
  /// total 26 characters.
  static String priceRangeFixedWidth(List<PriceRange> records) {
    final lines = records.map((record) {
      return padAlpha(record.ccode, PriceRangeSpec.ccodeWidth) +
          padAlpha(record.entryDate, PriceRangeSpec.dateWidth) +
          padNumeric(record.lowVal, PriceRangeSpec.valueWidth) +
          padNumeric(record.highVal, PriceRangeSpec.valueWidth);
    });
    return lines.join('\r\n');
  }

  static Future<void> exportPriceRanges(
    List<PriceRange> records,
    ExportFormat format,
  ) {
    final fileName = _fileName('price_range', format);
    return switch (format) {
      ExportFormat.csv => _download(
        _csvBytes(priceRangeRows(records)),
        fileName,
        format,
      ),
      ExportFormat.xlsx => _download(
        _xlsxBytes('PRICE RANGE', priceRangeRows(records)),
        fileName,
        format,
      ),
      ExportFormat.txt => _download(
        _textBytes(priceRangeFixedWidth(records)),
        fileName,
        format,
      ),
    };
  }

  // -------------------------------------------------------------------------
  // ENCODERS
  // -------------------------------------------------------------------------

  /// A BOM is written so Excel opens the file as UTF-8 rather than guessing.
  static Uint8List _csvBytes(List<List<Object?>> rows) {
    const encoder = csv_pkg.CsvEncoder(addBom: true);
    return Uint8List.fromList(utf8.encode(encoder.convert(rows)));
  }

  static Uint8List _xlsxBytes(String sheetName, List<List<Object?>> rows) {
    final book = xlsx.Excel.createExcel();
    // createExcel() always starts with a sheet called "Sheet1"; rename it
    // rather than adding a second one and deleting the first.
    book.rename(book.getDefaultSheet()!, sheetName);
    final sheet = book[sheetName];

    for (final row in rows) {
      sheet.appendRow(row.map(_toCellValue).toList());
    }

    final encoded = book.encode();
    if (encoded == null) {
      throw StateError('The spreadsheet could not be built.');
    }
    return Uint8List.fromList(encoded);
  }

  static xlsx.CellValue? _toCellValue(Object? value) => switch (value) {
    null => null,
    final int v => xlsx.IntCellValue(v),
    final double v => xlsx.DoubleCellValue(v),
    _ => xlsx.TextCellValue(value.toString()),
  };

  /// A trailing newline is included so the last record is a complete line,
  /// which is what a sequential file reader expects.
  static Uint8List _textBytes(String content) =>
      Uint8List.fromList(utf8.encode(content.isEmpty ? '' : '$content\r\n'));

  // -------------------------------------------------------------------------
  // PLUMBING
  // -------------------------------------------------------------------------

  static Future<void> _download(
    Uint8List bytes,
    String fileName,
    ExportFormat format,
  ) => downloadBytes(
    bytes: bytes,
    fileName: fileName,
    mimeType: format.mimeType,
  );

  /// e.g. `dividend_rate_20260806_1432.csv` - timestamped so repeated exports
  /// do not silently overwrite each other in the downloads folder.
  static String _fileName(String base, ExportFormat format) {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp =
        '${now.year}${two(now.month)}${two(now.day)}'
        '_${two(now.hour)}${two(now.minute)}';
    return '${base}_$stamp.${format.extension}';
  }
}
