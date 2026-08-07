import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Hands [bytes] to the browser as a download.
///
/// Wraps the bytes in a Blob, points a hidden `<a download>` at an object URL
/// for it, clicks it, then releases the URL again so the blob can be collected.
Future<void> downloadBytes({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  final blob = web.Blob(
    <JSUint8Array>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);

  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName
    ..style.display = 'none';

  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();

  // Give the browser a turn to start the download before revoking the URL.
  await Future<void>.delayed(Duration.zero);
  web.URL.revokeObjectURL(url);
}
