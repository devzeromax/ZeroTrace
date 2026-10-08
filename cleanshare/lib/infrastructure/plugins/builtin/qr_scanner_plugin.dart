import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:universal_io/io.dart';
import 'package:uuid/uuid.dart';
import 'package:zxing2/qrcode.dart';

import '../../../domain/marketplace/marketplace_models.dart';
import '../../../domain/scanner/scanner_models.dart';
import '../../../models/app_models.dart';

/// Built-in QR code scanner — works without ONNX / native engine.
class QrScannerPlugin implements ScanPlugin {
  const QrScannerPlugin();

  static const pluginId = 'qr-protection';

  @override
  String get id => pluginId;

  @override
  String get displayName => 'QR Protection';

  @override
  String get version => '1.0.0';

  @override
  MarketplaceCategory get category => MarketplaceCategory.qrDetection;

  @override
  List<String> get capabilities => const ['qr'];

  @override
  bool get isInstalled => true;

  @override
  bool get isOperational => true;

  @override
  ScanStage? get scanStage => ScanStage.qrCodes;

  @override
  Future<PluginScanResult> scan(ScanInput input) async {
    final started = DateTime.now();
    final findings = <PluginFinding>[];
    const uuid = Uuid();

    if (!_isImage(input.extension)) {
      return _result(started, findings);
    }

    try {
      final bytes = await File(input.filePath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        return _result(started, findings);
      }

      final hit = _decodeWithRetries(decoded);
      if (hit == null) {
        return _result(started, findings);
      }

      findings.add(
        PluginFinding(
          id: uuid.v4(),
          category: 'QR Codes',
          title: 'QR code detected',
          description: hit.text.length > 120
              ? '${hit.text.substring(0, 120)}…'
              : hit.text,
          severity: RiskLevel.medium,
          confidence: 0.9,
          recommendation: 'Blur or remove the QR code before sharing.',
          region: hit.region,
          supportsBlur: true,
        ),
      );
    } catch (_) {
      // Unsupported image layout — skip quietly.
    }

    return _result(started, findings);
  }

  /// Tries multiple scales / crops / binarizers — small or low-contrast QR.
  _QrHit? _decodeWithRetries(img.Image source) {
    final hints = DecodeHints()..put<void>(DecodeHintType.tryHarder);
    final reader = QRCodeReader();
    final fullW = source.width;
    final fullH = source.height;

    final attempts = <_QrAttempt>[
      _QrAttempt(source, 0, 0, 1, 1),
    ];

    if (fullW > 1200 || fullH > 1200) {
      final resized = img.copyResize(
        source,
        width: fullW > fullH ? 1200 : null,
        height: fullH >= fullW ? 1200 : null,
      );
      attempts.add(_QrAttempt(
        resized,
        0,
        0,
        fullW / resized.width,
        fullH / resized.height,
      ));
    }

    if (fullW < 900) {
      final resized = img.copyResize(source, width: (fullW * 1.8).round());
      attempts.add(_QrAttempt(
        resized,
        0,
        0,
        fullW / resized.width,
        fullH / resized.height,
      ));
    }

    for (final frac in [0.72, 0.55]) {
      final cw = (fullW * frac).round().clamp(64, fullW);
      final ch = (fullH * frac).round().clamp(64, fullH);
      final x0 = ((fullW - cw) / 2).round();
      final y0 = ((fullH - ch) / 2).round();
      attempts.add(_QrAttempt(
        img.copyCrop(source, x: x0, y: y0, width: cw, height: ch),
        x0,
        y0,
        1,
        1,
      ));
    }

    for (final attempt in attempts) {
      final luminance = _toLuminance(attempt.image);
      for (final inverted in [false, true]) {
        final lum = inverted ? InvertedLuminanceSource(luminance) : luminance;
        for (final binarizer in [
          HybridBinarizer(lum),
          GlobalHistogramBinarizer(lum),
        ]) {
          try {
            final result = reader.decode(BinaryBitmap(binarizer), hints: hints);
            return _QrHit(
              text: result.text,
              region: _regionFromResult(
                result,
                imageW: attempt.image.width,
                imageH: attempt.image.height,
                scaleX: attempt.scaleX,
                scaleY: attempt.scaleY,
                offsetX: attempt.offsetX,
                offsetY: attempt.offsetY,
                fullW: fullW,
                fullH: fullH,
              ),
            );
          } on NotFoundException {
            continue;
          } catch (_) {
            continue;
          }
        }
      }
    }
    return null;
  }

  FindingRegion? _regionFromResult(
    Result result, {
    required int imageW,
    required int imageH,
    required double scaleX,
    required double scaleY,
    required int offsetX,
    required int offsetY,
    required int fullW,
    required int fullH,
  }) {
    if (result.resultPoints.isEmpty || fullW <= 0 || fullH <= 0) {
      // Fallback: cover center of the decoded view so export still redacts.
      final side = (imageW < imageH ? imageW : imageH) * 0.35;
      final cx = offsetX + imageW / 2.0;
      final cy = offsetY + imageH / 2.0;
      final x1 = (cx - side / 2).clamp(0, fullW.toDouble());
      final y1 = (cy - side / 2).clamp(0, fullH.toDouble());
      final x2 = (cx + side / 2).clamp(0, fullW.toDouble());
      final y2 = (cy + side / 2).clamp(0, fullH.toDouble());
      return FindingRegion(
        x: x1 / fullW,
        y: y1 / fullH,
        width: (x2 - x1) / fullW,
        height: (y2 - y1) / fullH,
      );
    }
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (final p in result.resultPoints) {
      final x = offsetX + p.x * scaleX;
      final y = offsetY + p.y * scaleY;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
    // Finder points sit inside the code — pad so blur covers the full QR.
    final padX = (maxX - minX) * 0.22;
    final padY = (maxY - minY) * 0.22;
    minX = (minX - padX).clamp(0, fullW.toDouble());
    minY = (minY - padY).clamp(0, fullH.toDouble());
    maxX = (maxX + padX).clamp(0, fullW.toDouble());
    maxY = (maxY + padY).clamp(0, fullH.toDouble());
    final w = maxX - minX;
    final h = maxY - minY;
    if (w < 8 || h < 8) return null;
    return FindingRegion(
      x: minX / fullW,
      y: minY / fullH,
      width: w / fullW,
      height: h / fullH,
    );
  }

  /// RGBLuminanceSource expects packed ARGB ints, not precomputed luminance.
  LuminanceSource _toLuminance(img.Image image) {
    final rgba = image.getBytes(order: img.ChannelOrder.rgba);
    return RGBLuminanceSource(
      image.width,
      image.height,
      Int32List.fromList(
        List<int>.generate(
          image.width * image.height,
          (i) {
            final o = i * 4;
            final r = rgba[o];
            final g = rgba[o + 1];
            final b = rgba[o + 2];
            final a = rgba[o + 3];
            return (a << 24) | (r << 16) | (g << 8) | b;
          },
        ),
      ),
    );
  }

  PluginScanResult _result(DateTime started, List<PluginFinding> findings) {
    return PluginScanResult(
      pluginId: id,
      pluginName: displayName,
      pluginVersion: version,
      findings: findings,
      processingTime: DateTime.now().difference(started),
    );
  }

  bool _isImage(String ext) =>
      {'jpg', 'jpeg', 'png', 'webp', 'bmp', 'heic'}.contains(ext.toLowerCase());
}

class _QrHit {
  const _QrHit({required this.text, required this.region});
  final String text;
  final FindingRegion? region;
}

class _QrAttempt {
  const _QrAttempt(
    this.image,
    this.offsetX,
    this.offsetY,
    this.scaleX,
    this.scaleY,
  );
  final img.Image image;
  final int offsetX;
  final int offsetY;
  final double scaleX;
  final double scaleY;
}
