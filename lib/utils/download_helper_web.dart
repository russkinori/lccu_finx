// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:typed_data';
import 'dart:html' as html;

Future<void> downloadBytes({
  required String filename,
  required Uint8List bytes,
}) async {
  final blob = html.Blob([bytes], 'text/csv');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.document.createElement('a') as html.AnchorElement
    ..href = url
    ..download = filename;
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
