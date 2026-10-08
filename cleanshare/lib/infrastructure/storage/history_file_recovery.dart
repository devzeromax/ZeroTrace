import 'package:path/path.dart' as p;
import 'package:universal_io/io.dart';

import '../../domain/storage/storage_layout.dart';

/// Locates staged/export files for history sessions saved before paths were persisted.
abstract final class HistoryFileRecovery {
  static String? resolveStagedPath(
    ZeroTraceLayout layout,
    String fileName, {
    String? savedPath,
  }) {
    if (savedPath != null && File(savedPath).existsSync()) return savedPath;
    return findStagedPath(layout, fileName);
  }

  static String? resolveExportPath(
    ZeroTraceLayout layout,
    String fileName, {
    String? savedPath,
  }) {
    if (savedPath != null && File(savedPath).existsSync()) return savedPath;
    return findExportPath(layout, fileName);
  }

  static String? findStagedPath(ZeroTraceLayout layout, String fileName) {
    final scans = layout.scans;
    if (!scans.existsSync()) return null;

    final suffix = '_${p.basename(fileName)}';
    String? best;
    var bestTs = 0;

    for (final entity in scans.listSync()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!name.endsWith(suffix)) continue;
      final ts = int.tryParse(name.split('_').first) ?? 0;
      if (ts >= bestTs) {
        bestTs = ts;
        best = entity.path;
      }
    }
    return best;
  }

  static String? findExportPath(ZeroTraceLayout layout, String fileName) {
    final base = p.basenameWithoutExtension(fileName);
    final ext = p.extension(fileName);
    final outPath = p.join(layout.exports.path, '${base}_sanitized$ext');
    return File(outPath).existsSync() ? outPath : null;
  }
}
