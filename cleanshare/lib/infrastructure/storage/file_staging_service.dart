import 'package:universal_io/io.dart';

import 'package:path/path.dart' as p;

import '../../domain/scanner/scanner_models.dart';
import '../../domain/storage/storage_layout.dart';
import '../security/pack_trust_constants.dart';

/// Stages user-selected files into local scan storage.
class FileStagingService {
  FileStagingService(this._layout);

  final ZeroTraceLayout _layout;

  Future<ScanInput> stageFromPicker({
    required String sourcePath,
    required String fileName,
    required int sizeBytes,
  }) async {
    _assertSize(sizeBytes);

    final ext = p.extension(fileName).replaceFirst('.', '').toLowerCase();
    final destName =
        '${DateTime.now().millisecondsSinceEpoch}_${p.basename(fileName)}';
    final destPath = p.join(_layout.scans.path, destName);

    await File(sourcePath).copy(destPath);

    return ScanInput(
      filePath: destPath,
      fileName: fileName,
      mimeType: _mimeForExtension(ext),
      sizeBytes: sizeBytes,
    );
  }

  Future<ScanInput> stageFromBytes({
    required List<int> bytes,
    required String fileName,
  }) async {
    _assertSize(bytes.length);

    final destName =
        '${DateTime.now().millisecondsSinceEpoch}_${p.basename(fileName)}';
    final destPath = p.join(_layout.scans.path, destName);
    await File(destPath).writeAsBytes(bytes);

    final ext = p.extension(fileName).replaceFirst('.', '').toLowerCase();
    return ScanInput(
      filePath: destPath,
      fileName: fileName,
      mimeType: _mimeForExtension(ext),
      sizeBytes: bytes.length,
    );
  }

  void _assertSize(int bytes) {
    if (bytes > PackTrustConstants.maxStagingBytes) {
      throw FileStagingException(
        'File exceeds ${PackTrustConstants.maxStagingBytes ~/ (1024 * 1024)} MB staging limit.',
      );
    }
  }

  String _mimeForExtension(String ext) => switch (ext) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'heic' => 'image/heic',
        'pdf' => 'application/pdf',
        _ => 'application/octet-stream',
      };
}

class FileStagingException implements Exception {
  FileStagingException(this.message);
  final String message;

  @override
  String toString() => 'FileStagingException: $message';
}
