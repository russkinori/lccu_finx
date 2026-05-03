// download_helper.dart
// Platform-agnostic file download helper using conditional imports.

import 'dart:convert';
import 'dart:typed_data';

// Conditionally import platform-specific implementation: web uses
// `utils/download_helper_web.dart`, otherwise `utils/download_helper_io.dart`.
import 'utils/download_helper_io.dart'
    if (dart.library.html) 'utils/download_helper_web.dart' as dl;

/// Download or share a CSV file depending on platform.
/// Returns true only when the underlying platform helper completes without
/// throwing. This avoids reporting success when the browser or share sheet
/// blocked the action.
Future<bool> downloadOrShareCsv(String content, String fileName) async {
  final bytes = Uint8List.fromList(utf8.encode(content));
  try {
    await dl.downloadBytes(filename: fileName, bytes: bytes);
    return true;
  } catch (e) {
    return false;
  }
}
