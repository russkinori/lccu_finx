import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';

Future<void> downloadBytes({
  required String filename,
  required Uint8List bytes,
}) async {
  // Fallback for non-web platforms: present a share sheet which includes save options
  final xfile = XFile.fromData(bytes, name: filename, mimeType: 'text/csv');
  final params = ShareParams(
    text: 'Download',
    subject: filename,
    files: [xfile],
  );
  await SharePlus.instance.share(params);
}
