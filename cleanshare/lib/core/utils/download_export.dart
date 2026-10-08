import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:share_plus/share_plus.dart';
import 'package:universal_io/io.dart';

/// Saves or shares an exported file to a user-chosen location.
abstract final class DownloadExport {
  static Future<bool> saveToDevice({
    required String sourcePath,
    required String fileName,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) return false;

    if (kIsWeb) {
      return false;
    }

    if (Platform.isAndroid || Platform.isIOS) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(sourcePath, name: fileName)],
          subject: 'ZeroTrace sanitized file',
        ),
      );
      return true;
    }

    final destPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save sanitized file',
      fileName: fileName,
    );
    if (destPath == null || destPath.isEmpty) return false;

    await source.copy(destPath);
    return true;
  }
}
