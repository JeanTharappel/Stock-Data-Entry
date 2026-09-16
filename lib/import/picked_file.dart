import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'file_pick.dart';

/// A file the user chose to import: its name, for messages, and its contents.
class PickedFile {
  const PickedFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// The file extensions the import accepts - the three the export produces.
const List<String> kImportExtensions = <String>['csv', 'xlsx', 'txt'];

/// Opens the browser's "choose a file" dialog. Completes with null if the user
/// cancels.
typedef FilePicker = Future<PickedFile?> Function();

/// The file picker screens use. A provider rather than a direct call so the
/// widget tests, which have no browser, can hand in a file of their own.
final filePickerProvider = Provider<FilePicker>(
  (ref) =>
      () => pickFile(extensions: kImportExtensions),
);
