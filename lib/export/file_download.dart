// Saves bytes to the user's machine.
//
// The web implementation uses `package:web` with the anchor-download trick;
// there is no `dart:html` anywhere in this app.
export 'file_download_stub.dart'
    if (dart.library.js_interop) 'file_download_web.dart';
