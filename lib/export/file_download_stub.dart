import 'dart:typed_data';

/// Non-web fallback. This app targets Flutter Web; the stub exists only so the
/// project still analyses and compiles for other platforms.
Future<void> downloadBytes({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) {
  throw UnsupportedError(
    'Saving files is only supported when this app runs in a web browser.',
  );
}
