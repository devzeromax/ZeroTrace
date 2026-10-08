import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_io/io.dart';

import 'package:path/path.dart' as p;

import '../../domain/scanner/scanner_models.dart';
import '../../domain/storage/storage_layout.dart';
import '../../models/app_models.dart';
import '../security/path_guard.dart';
import '../security/runtime_security_guard.dart';

/// Applies user export options and writes sanitized output locally.
class ExportEngine {
  ExportEngine(
    this._layout, {
    RuntimeSecurityGuard? securityGuard,
  }) : _securityGuard = securityGuard;

  final ZeroTraceLayout _layout;
  final RuntimeSecurityGuard? _securityGuard;

  Future<ExportResult> export({
    required ScanInput source,
    required ExportConfig config,
    required List<PrivacyFinding> findings,
  }) async {
    if (!kIsWeb) {
      await _securityGuard?.assertSensitiveOperation(operation: 'export');
      PathGuard.assertScanPathAllowed(
        rootPath: _layout.root.path,
        filePath: source.filePath,
      );
    }

    final baseName = p.basenameWithoutExtension(source.fileName);
    final ext = p.extension(source.fileName);
    final outName = '${baseName}_sanitized$ext';
    final outPath = p.join(_layout.exports.path, outName);
    return _writeOutput(
      source: source,
      config: config,
      findings: findings,
      outPath: outPath,
      outName: outName,
    );
  }

  Future<ExportResult> exportPreview({
    required ScanInput source,
    required ExportConfig config,
    required List<PrivacyFinding> findings,
  }) async {
    if (!kIsWeb) {
      await _securityGuard?.assertSensitiveOperation(operation: 'export_preview');
      PathGuard.assertScanPathAllowed(
        rootPath: _layout.root.path,
        filePath: source.filePath,
      );
    }

    final previewDir = Directory(p.join(_layout.cache.path, 'previews'));
    if (!await previewDir.exists()) {
      await previewDir.create(recursive: true);
    }

    // Unique name so Flutter's image cache does not keep a stale "after" frame
    // when the user toggles blur on/off.
    final outName =
        'preview_${DateTime.now().millisecondsSinceEpoch}_${p.basename(source.fileName)}';
    final outPath = p.join(previewDir.path, outName);
    // ponytail: drop older previews for this basename (ceiling: last 8 kept).
    try {
      final stem = p.basename(source.fileName);
      final old = previewDir
          .listSync()
          .whereType<File>()
          .where((f) => p.basename(f.path).contains(stem))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      for (final f in old.skip(8)) {
        f.deleteSync();
      }
    } catch (_) {}
    return _writeOutput(
      source: source,
      config: config,
      findings: findings,
      outPath: outPath,
      outName: outName,
    );
  }

  Future<ExportResult> _writeOutput({
    required ScanInput source,
    required ExportConfig config,
    required List<PrivacyFinding> findings,
    required String outPath,
    required String outName,
  }) async {
    final sourceFile = File(source.filePath);
    if (!await sourceFile.exists()) {
      throw ExportException('Source file not found.');
    }

    final outFile = File(outPath);
    await outFile.parent.create(recursive: true);

    final applied = findings.where((f) => f.isFixed).toList();
    if (applied.isEmpty) {
      await sourceFile.copy(outPath);
      return ExportResult(
        outputPath: outPath,
        outputFileName: outName,
        strippedMetadata: false,
        blurredRegions: false,
        appliedFixCount: 0,
      );
    }

    var stripped = false;
    var blurred = false;

    if (_isImage(source.extension)) {
      final bytes = await sourceFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        final working = img.Image.from(decoded);

        if (config.blurSensitiveAreas) {
          blurred = _blurFixedRegions(working, applied);
        }

        if (config.stripMetadata) {
          stripped = true;
        }

        final normalized = source.extension.toLowerCase();
        final List<int> output;
        if (normalized == 'png') {
          output = img.encodePng(working);
        } else if (normalized == 'webp') {
          output = img.encodeWebP(working);
        } else {
          output = img.encodeJpg(working, quality: 92);
        }
        await outFile.writeAsBytes(output, flush: true);
      } else {
        await sourceFile.copy(outPath);
      }
    } else {
      await sourceFile.copy(outPath);
    }

    if (!await outFile.exists()) {
      throw ExportException('Could not write export file.');
    }

    return ExportResult(
      outputPath: outPath,
      outputFileName: outName,
      strippedMetadata: stripped && config.stripMetadata,
      blurredRegions: blurred,
      appliedFixCount: applied.length,
    );
  }

  bool _blurFixedRegions(img.Image image, List<PrivacyFinding> applied) {
    var changed = false;
    for (final finding in applied) {
      final region = finding.region;
      if (region == null || !finding.supportsBlur) continue;

      final expanded = _expandRegion(
        region,
        margin: _isFaceFinding(finding)
            ? 0.20
            : _isPlateFinding(finding)
                ? 0.12
                : 0.08,
      );

      final x = (expanded.x * image.width).round().clamp(0, image.width - 1);
      final y = (expanded.y * image.height).round().clamp(0, image.height - 1);
      final w =
          (expanded.width * image.width).round().clamp(8, image.width - x);
      final h =
          (expanded.height * image.height).round().clamp(8, image.height - y);

      try {
        if (_isFaceFinding(finding) ||
            _isPlateFinding(finding) ||
            _isDocumentFinding(finding) ||
            _isQrFinding(finding)) {
          _pixelateRegion(
            image,
            x,
            y,
            w,
            h,
            blockDivisor: _isFaceFinding(finding)
                ? 5
                : _isQrFinding(finding)
                    ? 6
                    : 8,
          );
        } else {
          final patch = img.copyCrop(image, x: x, y: y, width: w, height: h);
          final radius = ((w < h ? w : h) ~/ 4).clamp(6, 28);
          final blurred = img.gaussianBlur(patch, radius: radius);
          img.compositeImage(image, blurred, dstX: x, dstY: y);
        }
        changed = true;
      } catch (_) {
        img.fillRect(
          image,
          x1: x,
          y1: y,
          x2: x + w,
          y2: y + h,
          color: img.ColorRgb8(40, 40, 40),
        );
        changed = true;
      }
    }
    return changed;
  }

  bool _isFaceFinding(PrivacyFinding finding) =>
      finding.category.toLowerCase().contains('face');

  bool _isPlateFinding(PrivacyFinding finding) {
    final cat = finding.category.toLowerCase();
    return cat.contains('license') || cat.contains('plate');
  }

  bool _isDocumentFinding(PrivacyFinding finding) {
    final cat = finding.category.toLowerCase();
    return cat.contains('document') ||
        cat.contains('confidential') ||
        finding.piiLabel != null;
  }

  bool _isQrFinding(PrivacyFinding finding) {
    final cat = finding.category.toLowerCase();
    return cat.contains('qr') || cat.contains('barcode');
  }

  PrivacyRegion _expandRegion(PrivacyRegion region, {required double margin}) {
    final padX = region.width * margin;
    final padY = region.height * margin;
    final x = (region.x - padX).clamp(0.0, 1.0);
    final y = (region.y - padY).clamp(0.0, 1.0);
    final x2 = (region.x + region.width + padX).clamp(0.0, 1.0);
    final y2 = (region.y + region.height + padY).clamp(0.0, 1.0);
    return PrivacyRegion(
      x: x,
      y: y,
      width: (x2 - x).clamp(0.02, 1.0),
      height: (y2 - y).clamp(0.02, 1.0),
    );
  }

  void _pixelateRegion(
    img.Image image,
    int x,
    int y,
    int w,
    int h, {
    int blockDivisor = 8,
  }) {
    final block = (w < h ? w : h) ~/ blockDivisor;
    final blockSize = block.clamp(8, 32);
    for (var py = y; py < y + h; py += blockSize) {
      for (var px = x; px < x + w; px += blockSize) {
        final bw = (px + blockSize > x + w) ? (x + w - px) : blockSize;
        final bh = (py + blockSize > y + h) ? (y + h - py) : blockSize;
        if (bw <= 0 || bh <= 0) continue;

        var r = 0, g = 0, b = 0, count = 0;
        for (var dy = 0; dy < bh; dy++) {
          for (var dx = 0; dx < bw; dx++) {
            final pixel = image.getPixel(px + dx, py + dy);
            r += pixel.r.toInt();
            g += pixel.g.toInt();
            b += pixel.b.toInt();
            count++;
          }
        }
        if (count == 0) continue;
        final color = img.ColorRgb8(
          (r / count).round(),
          (g / count).round(),
          (b / count).round(),
        );
        img.fillRect(
          image,
          x1: px,
          y1: py,
          x2: px + bw,
          y2: py + bh,
          color: color,
        );
      }
    }
  }

  bool _isImage(String ext) =>
      {'jpg', 'jpeg', 'png', 'heic', 'webp', 'tif', 'tiff'}
          .contains(ext.toLowerCase());
}

class ExportResult {
  const ExportResult({
    required this.outputPath,
    required this.outputFileName,
    required this.strippedMetadata,
    required this.blurredRegions,
    required this.appliedFixCount,
  });

  final String outputPath;
  final String outputFileName;
  final bool strippedMetadata;
  final bool blurredRegions;
  final int appliedFixCount;
}

class ExportException implements Exception {
  ExportException(this.message);
  final String message;

  @override
  String toString() => 'ExportException: $message';
}
