// Lets the user choose a file from their machine.
//
// The web implementation uses `package:web` with a hidden file input, the
// mirror image of how `export/file_download.dart` saves one.
export 'file_pick_stub.dart' if (dart.library.js_interop) 'file_pick_web.dart';
