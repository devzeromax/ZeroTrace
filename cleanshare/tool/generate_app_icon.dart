// ignore_for_file: avoid_print

/// Builds square launcher assets from [assets/branding/logo_mark.png].
///
/// Centers the visible logo mass inside Android/iOS safe zones so adaptive
/// icons are not clipped or lopsided on home screens.
///
/// Run from cleanshare/:
///   dart run tool/generate_app_icon.dart
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const _canvasSize = 1024;
const _foregroundFill = 0.72; // fits inside adaptive-icon safe circle
const _legacyFill = 0.88; // legacy square mipmaps can use more canvas

Future<void> main() async {
  final source = File('assets/branding/logo_mark.png');
  if (!await source.exists()) {
    throw StateError('Missing ${source.path}');
  }

  final decoded = img.decodePng(await source.readAsBytes());
  if (decoded == null) {
    throw StateError('Could not decode ${source.path}');
  }

  final bounds = _visibleBounds(decoded);
  if (bounds == null) {
    throw StateError('Logo appears empty in ${source.path}');
  }

  final cropped = img.copyCrop(
    decoded,
    x: bounds.left,
    y: bounds.top,
    width: bounds.width,
    height: bounds.height,
  );

  final foreground = _composeSquare(
    cropped,
    fillFactor: _foregroundFill,
    background: img.ColorRgba8(0, 0, 0, 0),
  );
  final legacy = _composeSquare(
    cropped,
    fillFactor: _legacyFill,
    background: img.ColorRgba8(0, 0, 0, 255),
  );

  final outDir = Directory('assets/branding');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);

  final foregroundPath = File('assets/branding/app_icon_foreground.png');
  final legacyPath = File('assets/branding/app_icon.png');

  await foregroundPath.writeAsBytes(img.encodePng(foreground));
  await legacyPath.writeAsBytes(img.encodePng(legacy));

  print('Wrote ${foregroundPath.path} (${foreground.width}x${foreground.height})');
  print('Wrote ${legacyPath.path} (${legacy.width}x${legacy.height})');
  print('Source crop: ${bounds.width}x${bounds.height} from ${decoded.width}x${decoded.height}');
}

img.Image _composeSquare(
  img.Image source, {
  required double fillFactor,
  required img.Color background,
}) {
  final canvas = img.Image(width: _canvasSize, height: _canvasSize);
  img.fill(canvas, color: background);

  final maxSide = math.max(source.width, source.height);
  final target = (_canvasSize * fillFactor).round();
  final scale = target / maxSide;
  final scaledW = (source.width * scale).round().clamp(1, _canvasSize);
  final scaledH = (source.height * scale).round().clamp(1, _canvasSize);
  final resized = img.copyResize(
    source,
    width: scaledW,
    height: scaledH,
    interpolation: img.Interpolation.cubic,
  );

  final offsetX = ((_canvasSize - scaledW) / 2).round();
  final offsetY = ((_canvasSize - scaledH) / 2).round();
  img.compositeImage(canvas, resized, dstX: offsetX, dstY: offsetY);
  return canvas;
}

class _Bounds {
  const _Bounds({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final int left;
  final int top;
  final int width;
  final int height;
}

_Bounds? _visibleBounds(img.Image image) {
  var minX = image.width;
  var minY = image.height;
  var maxX = -1;
  var maxY = -1;

  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      final a = pixel.a.toInt();
      if (a < 12) continue;
      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();
      if (r < 8 && g < 8 && b < 8) continue;

      minX = math.min(minX, x);
      minY = math.min(minY, y);
      maxX = math.max(maxX, x);
      maxY = math.max(maxY, y);
    }
  }

  if (maxX < minX || maxY < minY) return null;

  const pad = 8;
  final left = math.max(0, minX - pad);
  final top = math.max(0, minY - pad);
  final right = math.min(image.width - 1, maxX + pad);
  final bottom = math.min(image.height - 1, maxY + pad);

  return _Bounds(
    left: left,
    top: top,
    width: right - left + 1,
    height: bottom - top + 1,
  );
}
