import 'dart:convert';

import 'package:csv/csv.dart' as csv_pkg;
import 'package:excel/excel.dart' as xlsx;

import '../core/record_spec.dart';
import '../core/validators.dart';
import '../export/export_service.dart';
import '../models/dividend_rate.dart';
import '../models/price_range.dart';
import 'picked_file.dart';

/// What came out of reading an import file.
///
/// All or nothing: if [problems] is not empty, [records] is empty and nothing
/// should be saved. Importing half a file and leaving the reader to work out
/// which half is worse than importing none of it.
class ImportReadResult<T> {
  const ImportReadResult.ok(this.records) : problems = const <String>[];

  const ImportReadResult.failed(this.problems) : records = const [];

  final List<T> records;

  /// Plain-language descriptions, each naming the row or line it is about.
  final List<String> problems;

  bool get isOk => problems.isEmpty;
}

/// Reads the files [ExportService] writes back into records.
///
/// The file type is taken from its extension. CSV and XLSX must start with the
/// header row the export writes, and TXT lines must be the record width from
/// `record_spec.dart` - which is also how a price range file dropped onto the
/// dividend rate tab is caught and named. Every field goes through the same
/// validators as the entry forms, so an import can never store something the
/// forms would have refused.
abstract final class ImportService {
  static ImportReadResult<DividendRate> readDividendRates(PickedFile file) =>
      _read(
        file: file,
        spec: const _RecordLayout(
          name: 'DIVIDEND RATE',
          header: ExportService.dividendRateHeader,
          lineWidth: DividendRateSpec.recordWidth,
        ),
        other: const _RecordLayout(
          name: 'PRICE RANGE',
          header: ExportService.priceRangeHeader,
          lineWidth: PriceRangeSpec.recordWidth,
        ),
        splitLine: (line) {
          // CCODE 10 | DATE 6 | RATE 3 with an implied decimal point.
          final dateEnd =
              DividendRateSpec.ccodeWidth + DividendRateSpec.dateWidth;
          final digits = line.substring(dateEnd);
          final whole = digits.length - DividendRateSpec.rateDecimals;
          return <String>[
            line.substring(0, DividendRateSpec.ccodeWidth),
            line.substring(DividendRateSpec.ccodeWidth, dateEnd),
            // Written back out with its dot, so the rate is checked exactly as
            // if it had been typed into the form.
            '${digits.substring(0, whole)}.${digits.substring(whole)}',
          ];
        },
        build: (fields) {
          final ccode = fields[0].trim().toUpperCase();
          final date = fields[1];
          final rate = fields[2].trim();
          final error =
              Validators.ccode(ccode, maxLength: DividendRateSpec.ccodeWidth) ??
              Validators.ddmmyy(date) ??
              Validators.divRate(rate);
          if (error != null) return (null, error);
          return (
            DividendRate(
              ccode: ccode,
              entryDate: date,
              divRate: double.parse(rate),
            ),
            null,
          );
        },
      );

  static ImportReadResult<PriceRange> readPriceRanges(PickedFile file) => _read(
    file: file,
    spec: const _RecordLayout(
      name: 'PRICE RANGE',
      header: ExportService.priceRangeHeader,
      lineWidth: PriceRangeSpec.recordWidth,
    ),
    other: const _RecordLayout(
      name: 'DIVIDEND RATE',
      header: ExportService.dividendRateHeader,
      lineWidth: DividendRateSpec.recordWidth,
    ),
    splitLine: (line) {
      // CCODE 10 | DATE 6 | LOW 5 | HIGH 5.
      const ccodeEnd = PriceRangeSpec.ccodeWidth;
      const dateEnd = ccodeEnd + PriceRangeSpec.dateWidth;
      const lowEnd = dateEnd + PriceRangeSpec.valueWidth;
      return <String>[
        line.substring(0, ccodeEnd),
        line.substring(ccodeEnd, dateEnd),
        line.substring(dateEnd, lowEnd),
        line.substring(lowEnd),
      ];
    },
    build: (fields) {
      final ccode = fields[0].trim().toUpperCase();
      final date = fields[1];
      final low = fields[2].trim();
      final high = fields[3].trim();
      final lowError = Validators.priceValue(low, fieldName: 'LOW VALUE');
      final highError = Validators.priceValue(high, fieldName: 'HIGH VALUE');
      final error =
          Validators.ccode(ccode, maxLength: PriceRangeSpec.ccodeWidth) ??
          Validators.ddmmyy(date) ??
          lowError ??
          highError ??
          Validators.highNotBelowLow(low: low, high: high);
      if (error != null) return (null, error);
      return (
        PriceRange(
          ccode: ccode,
          entryDate: date,
          lowVal: int.parse(low),
          highVal: int.parse(high),
        ),
        null,
      );
    },
  );

  // -------------------------------------------------------------------------
  // SHARED READER
  // -------------------------------------------------------------------------

  /// Position of the DATE IN WORDS column in the CSV and XLSX exports. It is
  /// there for people reading the spreadsheet; the import ignores it.
  static const int _wordsColumn = 2;

  static ImportReadResult<T> _read<T>({
    required PickedFile file,
    required _RecordLayout spec,
    required _RecordLayout other,
    required List<String> Function(String line) splitLine,
    required (T?, String?) Function(List<String> fields) build,
  }) {
    final extension = file.name.contains('.')
        ? file.name.substring(file.name.lastIndexOf('.') + 1).toLowerCase()
        : '';

    final List<_Row> rows;
    try {
      final read = switch (extension) {
        'csv' => _csvRows(file, spec, other),
        'xlsx' => _xlsxRows(file, spec, other),
        'txt' => _txtRows(file, spec, other, splitLine),
        _ => null,
      };
      if (read == null) {
        return const ImportReadResult.failed(<String>[
          'THIS IS NOT A FILE THE APP CAN IMPORT. '
              'CHOOSE A CSV, XLSX OR TXT FILE THAT THIS APP SAVED.',
        ]);
      }
      if (read.problem != null) {
        return ImportReadResult.failed(<String>[read.problem!]);
      }
      rows = read.rows;
    } on Object {
      // A damaged or mislabelled file - an XLSX that is not really a
      // workbook, text that is not UTF-8.
      return ImportReadResult.failed(<String>[
        'THE FILE ${file.name} COULD NOT BE READ. IT MAY BE DAMAGED, OR NOT '
            'REALLY A ${extension.toUpperCase()} FILE.',
      ]);
    }

    if (rows.isEmpty) {
      return const ImportReadResult.failed(<String>[
        'THERE ARE NO RECORDS IN THIS FILE.',
      ]);
    }

    final records = <T>[];
    final problems = <String>[];
    for (final row in rows) {
      if (row.problem != null) {
        problems.add('${row.label}: ${row.problem}');
        continue;
      }
      final (record, error) = build(row.fields);
      if (error != null) {
        problems.add('${row.label}: $error');
      } else {
        records.add(record as T);
      }
    }

    return problems.isEmpty
        ? ImportReadResult.ok(records)
        : ImportReadResult.failed(problems);
  }

  // -------------------------------------------------------------------------
  // FORMATS
  // -------------------------------------------------------------------------

  static _Rows _csvRows(
    PickedFile file,
    _RecordLayout spec,
    _RecordLayout other,
  ) {
    // The decoder skips the BOM the export writes.
    final table = const csv_pkg.CsvDecoder()
        .convert(utf8.decode(file.bytes))
        .map((row) => row.map((cell) => '${cell ?? ''}').toList())
        .toList();
    return _tableRows(table, spec, other);
  }

  static _Rows _xlsxRows(
    PickedFile file,
    _RecordLayout spec,
    _RecordLayout other,
  ) {
    final book = xlsx.Excel.decodeBytes(file.bytes);
    // The export writes a single sheet; use the first one whatever its name.
    final sheet = book.tables.values.firstOrNull;
    if (sheet == null) return const _Rows.problem('THIS WORKBOOK IS EMPTY.');
    final table = sheet.rows
        .map((row) => row.map((cell) => _cellText(cell?.value)).toList())
        .toList();
    return _tableRows(table, spec, other);
  }

  /// A spreadsheet cell as the text a user would see in it. Whole numbers lose
  /// any `.0` a spreadsheet program added when re-saving, so `100.0` is read
  /// back as the `100` that was exported.
  static String _cellText(xlsx.CellValue? value) => switch (value) {
    null => '',
    final xlsx.DoubleCellValue number when number.value % 1 == 0 =>
      number.value.toInt().toString(),
    _ => value.toString(),
  };

  /// Checks the header row, then turns each data row into fields in record
  /// order: company code, date, then the value columns.
  static _Rows _tableRows(
    List<List<String>> table,
    _RecordLayout spec,
    _RecordLayout other,
  ) {
    // Rows that are completely blank - often left at the end by a spreadsheet
    // program - are not records.
    bool isBlank(List<String> row) => row.every((cell) => cell.trim().isEmpty);

    final headerIndex = table.indexWhere((row) => !isBlank(row));
    if (headerIndex == -1) return const _Rows(<_Row>[]);

    final header = table[headerIndex];
    if (!spec.headerMatches(header)) {
      return _Rows.problem(
        other.headerMatches(header)
            ? other.wrongTabMessage(spec)
            : 'THIS FILE DOES NOT LOOK LIKE A ${spec.name} FILE SAVED BY THIS '
                  'APP. ITS FIRST ROW SHOULD BE: ${spec.header.join(', ')}.',
      );
    }

    final rows = <_Row>[];
    for (var i = headerIndex + 1; i < table.length; i++) {
      final row = table[i];
      if (isBlank(row)) continue;
      // Spreadsheet programs number rows from 1, header included.
      final label = 'ROW ${i + 1}';
      if (row.length < spec.header.length) {
        rows.add(_Row.problem(label, 'SOME OF THE COLUMNS ARE EMPTY.'));
        continue;
      }
      rows.add(
        _Row(label, <String>[
          row[0],
          _restoreDate(row[1]),
          ...row.sublist(_wordsColumn + 1, spec.header.length),
        ]),
      );
    }
    return _Rows(rows);
  }

  /// Opening an exported CSV in a spreadsheet program and saving it again
  /// turns a date like `050826` into the number `50826`. Put the lost zero
  /// back; anything else is left for the date validator to judge.
  static String _restoreDate(String raw) {
    final value = raw.trim();
    return RegExp(r'^\d{5}$').hasMatch(value) ? '0$value' : value;
  }

  static _Rows _txtRows(
    PickedFile file,
    _RecordLayout spec,
    _RecordLayout other,
    List<String> Function(String line) splitLine,
  ) {
    var text = utf8.decode(file.bytes);
    if (text.startsWith('﻿')) text = text.substring(1);

    final rows = <_Row>[];
    final lines = text.split('\n');
    var firstRecord = true;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].replaceAll('\r', '');
      if (line.trim().isEmpty) continue;
      final label = 'LINE ${i + 1}';

      // The first record's width says which kind of file this is.
      if (firstRecord) {
        firstRecord = false;
        if (line.length == other.lineWidth && line.length != spec.lineWidth) {
          return _Rows.problem(other.wrongTabMessage(spec));
        }
      }

      if (line.length != spec.lineWidth) {
        rows.add(
          _Row.problem(
            label,
            'THIS LINE IS ${line.length} CHARACTERS LONG. EVERY ${spec.name} '
            'LINE MUST BE EXACTLY ${spec.lineWidth}.',
          ),
        );
        continue;
      }
      rows.add(_Row(label, splitLine(line)));
    }
    return _Rows(rows);
  }
}

/// What the reader needs to know about one record type's files.
class _RecordLayout {
  const _RecordLayout({
    required this.name,
    required this.header,
    required this.lineWidth,
  });

  final String name;
  final List<String> header;
  final int lineWidth;

  bool headerMatches(List<String> row) {
    if (row.length < header.length) return false;
    for (var i = 0; i < header.length; i++) {
      if (row[i].trim().toUpperCase() != header[i]) return false;
    }
    return true;
  }

  /// Said when a file of this type was chosen on [intended]'s tab.
  String wrongTabMessage(_RecordLayout intended) =>
      'THIS IS A $name FILE, NOT A ${intended.name} FILE. '
      'IMPORT IT ON THE $name ENTRY TAB INSTEAD.';
}

/// One data row or line, split into fields in record order.
class _Row {
  const _Row(this.label, this.fields) : problem = null;

  const _Row.problem(this.label, this.problem) : fields = const <String>[];

  /// `ROW 3` or `LINE 3`, for messages.
  final String label;
  final List<String> fields;
  final String? problem;
}

/// Every row of a file, or one problem that stops the whole file.
class _Rows {
  const _Rows(this.rows) : problem = null;

  const _Rows.problem(this.problem) : rows = const <_Row>[];

  final List<_Row> rows;
  final String? problem;
}
