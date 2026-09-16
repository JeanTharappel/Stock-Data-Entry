import 'picked_file.dart';

/// Non-web fallback. This app targets Flutter Web; the stub exists only so the
/// project still analyses and compiles for other platforms.
Future<PickedFile?> pickFile({required List<String> extensions}) {
  throw UnsupportedError(
    'Choosing files is only supported when this app runs in a web browser.',
  );
}
