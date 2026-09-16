import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'picked_file.dart';

/// Opens the browser's file dialog and reads the chosen file into memory.
///
/// A hidden `<input type="file">` is added, clicked, and removed again once
/// the user has chosen a file or closed the dialog. The file never leaves the
/// browser - it is read here and nowhere else.
Future<PickedFile?> pickFile({required List<String> extensions}) {
  final completer = Completer<PickedFile?>();

  final input = web.document.createElement('input') as web.HTMLInputElement
    ..type = 'file'
    ..accept = extensions.map((extension) => '.$extension').join(',')
    ..style.display = 'none';

  void finish(PickedFile? file) {
    input.remove();
    if (!completer.isCompleted) completer.complete(file);
  }

  input.onchange = ((web.Event _) {
    final file = input.files?.item(0);
    if (file == null) {
      finish(null);
      return;
    }
    file.arrayBuffer().toDart.then(
      (buffer) => finish(
        PickedFile(name: file.name, bytes: buffer.toDart.asUint8List()),
      ),
      onError: (Object error) {
        input.remove();
        if (!completer.isCompleted) completer.completeError(error);
      },
    );
  }).toJS;

  // Closing the dialog without choosing. Older browsers never send this, so
  // callers must not lock the screen while waiting.
  input.oncancel = ((web.Event _) => finish(null)).toJS;

  web.document.body!.appendChild(input);
  input.click();
  return completer.future;
}
