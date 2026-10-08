// ignore_for_file: avoid_print

/// Generates bundled marketplace pack zips and prints SHA256 for catalog.json.
///
/// Run: dart run tool/build_pack_assets.dart
///
/// Rules packs are built-in (KB). ONNX packs use real weights from [tool/models/]
/// when present; otherwise a tiny placeholder stub is written (dev only).
library;

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

const _scrfdUrl =
    'https://huggingface.co/RuteNL/SCRFD-face-detection-ONNX/resolve/main/2.5g_bnkps.onnx';
const _yoloxUrl =
    'https://github.com/opencv/opencv_zoo/raw/main/models/object_detection_yolox/object_detection_yolox_2022nov.onnx';
const _ppocrRecUrl =
    'https://github.com/opencv/opencv_zoo/raw/main/models/text_recognition_crnn/text_recognition_CRNN_EN_2023feb_fp16.onnx';
const _blazefaceUrl =
    'https://huggingface.co/garavv/blazeface-onnx/resolve/main/blazeface.onnx';
const _yunetUrl =
    'https://github.com/opencv/opencv_zoo/raw/main/models/face_detection_yunet/face_detection_yunet_2023mar.onnx';
const _licensePlateUrl =
    'https://github.com/opencv/opencv_zoo/raw/main/models/license_plate_detection_yunet/license_plate_detection_lpd_yunet_2023mar.onnx';
const _ppocrUrl =
    'https://github.com/opencv/opencv_zoo/raw/main/models/text_detection_ppocr/text_detection_en_ppocrv3_2023may.onnx';

Future<void> main() async {
  final modelDir = Directory(p.join('tool', 'models'));
  if (!modelDir.existsSync()) modelDir.createSync(recursive: true);

  final faceExtras = await _resolveExtraModels(
    modelDir: modelDir,
    entries: [
      (
        fileName: 'blazeface.onnx',
        path: 'models/blazeface.onnx',
        url: _blazefaceUrl,
        packId: 'face-protection-blazeface',
        required: true,
      ),
      (
        fileName: 'scrfd.onnx',
        path: 'models/scrfd.onnx',
        url: _scrfdUrl,
        packId: 'face-protection-scrfd',
        required: false,
      ),
    ],
  );

  final vehicleExtras = await _resolveExtraModels(
    modelDir: modelDir,
    entries: [
      (
        fileName: 'yolox.onnx',
        path: 'models/yolox.onnx',
        url: _yoloxUrl,
        packId: 'vehicle-protection-yolox',
        required: false,
      ),
    ],
  );

  final documentExtras = await _resolveExtraModels(
    modelDir: modelDir,
    entries: [
      (
        fileName: 'ppocr_rec.onnx',
        path: 'models/ppocr_rec.onnx',
        url: _ppocrRecUrl,
        packId: 'document-protection-rec',
        required: false,
      ),
    ],
  );

  final packs = <_PackSpec>[
    _PackSpec(
      id: 'face-protection',
      name: 'Face Protection Pack',
      category: 'face_detection',
      format: 'onnx',
      modelFile: 'models/yunet.onnx',
      capabilities: ['faces', 'scrfd', 'ensemble'],
      iconSource: 'face-blur-ai.png',
      modelSource: await _resolveModelBytes(
        modelDir: modelDir,
        fileName: 'yunet.onnx',
        downloadUrl: _yunetUrl,
        packId: 'face-protection',
      ),
      extraModels: faceExtras.models,
      extraModelPaths: faceExtras.paths,
    ),
    _PackSpec(
      id: 'vehicle-protection',
      name: 'Vehicle Protection Pack',
      category: 'license_plate_detection',
      format: 'onnx',
      modelFile: 'models/yolov11n.onnx',
      capabilities: ['license_plates', 'vehicles', 'yolox'],
      iconSource: 'license-plate-detector.png',
      modelSource: await _resolveModelBytes(
        modelDir: modelDir,
        fileName: 'yolov11n.onnx',
        downloadUrl: _licensePlateUrl,
        packId: 'vehicle-protection',
      ),
      extraModels: vehicleExtras.models,
      extraModelPaths: vehicleExtras.paths,
    ),
    _PackSpec(
      id: 'document-protection',
      name: 'Document Protection Pack',
      category: 'document_scanner',
      format: 'onnx',
      modelFile: 'models/paddleocr.onnx',
      capabilities: ['ocr', 'documents', 'pii', 'recognition'],
      iconSource: 'ocr-engine.png',
      modelSource: await _resolveModelBytes(
        modelDir: modelDir,
        fileName: 'paddleocr.onnx',
        downloadUrl: _ppocrUrl,
        packId: 'document-protection',
      ),
      extraModels: documentExtras.models,
      extraModelPaths: documentExtras.paths,
    ),
  ];

  final outDir = Directory('assets/marketplace/packs');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);

  print('Building ONNX marketplace packs:\n');

  for (final pack in packs) {
    final modelBytes = pack.modelSource;
    final modelSha = sha256.convert(modelBytes).toString();

    final pluginManifest = {
      'id': pack.id,
      'name': pack.name,
      'version': '1.0.0',
      'developer': 'ZeroTrace',
      'category': pack.category,
      'capabilities': pack.capabilities,
      'model': {
        'format': pack.format,
        'file': pack.modelFile,
        'sha256': modelSha,
        'sizeBytes': modelBytes.length,
      },
      'minAppVersion': '1.0.0',
      'license': 'MIT',
      'entryPoint': 'scan',
    };

    final marketplaceManifest = {
      'packId': pack.id,
      'packName': pack.name,
      'version': '1.0.0',
      'description': pack.name,
      'developer': 'ZeroTrace',
      'category': pack.category,
      'capabilities': pack.capabilities,
      'supportedPlatforms': ['windows', 'macos', 'linux', 'android', 'ios'],
      'minAppVersion': '1.0.0',
      'license': 'MIT',
      'hash': modelSha,
    };

    final config = {
      'packId': pack.id,
      'version': '1.0.0',
      'blurRules': pack.id == 'face-protection',
      'vehicleRules': pack.id == 'vehicle-protection',
    };

    final archive = Archive()
      ..addFile(
        ArchiveFile(
          'manifest.json',
          utf8.encode(jsonEncode(marketplaceManifest)).length,
          utf8.encode(const JsonEncoder.withIndent('  ').convert(marketplaceManifest)),
        ),
      )
      ..addFile(
        ArchiveFile(
          'zerotrace.plugin.json',
          utf8.encode(jsonEncode(pluginManifest)).length,
          utf8.encode(const JsonEncoder.withIndent('  ').convert(pluginManifest)),
        ),
      )
      ..addFile(
        ArchiveFile(
          'config/pack.json',
          utf8.encode(jsonEncode(config)).length,
          utf8.encode(const JsonEncoder.withIndent('  ').convert(config)),
        ),
      )
      ..addFile(
        ArchiveFile(
          pack.modelFile,
          modelBytes.length,
          modelBytes,
        ),
      );
    for (var i = 0; i < pack.extraModels.length; i++) {
      final extraBytes = pack.extraModels[i];
      final extraPath = pack.extraModelPaths[i];
      archive.addFile(
        ArchiveFile(
          extraPath,
          extraBytes.length,
          extraBytes,
        ),
      );
    }
    archive.addFile(
      ArchiveFile(
        'license/MIT.txt',
        utf8.encode('MIT License — ZeroTrace Privacy Pack').length,
        utf8.encode('MIT License — ZeroTrace Privacy Pack'),
      ),
    );

    final zipBytes = ZipEncoder().encode(archive);
    final zipPath = p.join(outDir.path, '${pack.id}.zip');
    File(zipPath).writeAsBytesSync(zipBytes);

    final iconTarget = p.join(outDir.path, '${pack.id}.png');
    final iconSource = p.join(outDir.path, pack.iconSource);
    if (File(iconSource).existsSync() && !File(iconTarget).existsSync()) {
      File(iconSource).copySync(iconTarget);
    }

    print('${pack.id}:');
    print('  bundleAsset: assets/marketplace/packs/${pack.id}.zip');
    print('  modelBytes: ${modelBytes.length}');
    print('  modelSha256: $modelSha');
    print('  zipSha256: ${sha256.convert(zipBytes)}');
    print('');
  }

  print('Done. ${packs.length} ONNX packs in ${outDir.path}');
  print('Run: dart run tool/sign_catalog_packs.dart  (syncs zip SHA-256 + signatures)');
  print('Built-in scanners (metadata, QR, secrets) ship in Dart/Rust — no zip needed.');
}

Future<List<int>> _resolveModelBytes({
  required Directory modelDir,
  required String fileName,
  required String downloadUrl,
  required String packId,
}) async {
  final local = File(p.join(modelDir.path, fileName));
  if (await local.exists()) {
    final bytes = await local.readAsBytes();
    if (bytes.length > 1024) return bytes;
  }

  stdout.writeln('Downloading $fileName for $packId...');
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(downloadUrl));
    final response = await request.close();
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode} for $downloadUrl');
    }
    final bytes = await response.fold<List<int>>(
      <int>[],
      (previous, element) => previous..addAll(element),
    );
    if (bytes.length <= 1024) {
      throw StateError('Downloaded model for $packId is too small (${bytes.length} bytes).');
    }
    await local.writeAsBytes(bytes, flush: true);
    return bytes;
  } finally {
    client.close(force: true);
  }
}

typedef _ExtraEntry = ({
  String fileName,
  String path,
  String url,
  String packId,
  bool required,
});

class _ExtraBundle {
  const _ExtraBundle({required this.models, required this.paths});
  final List<List<int>> models;
  final List<String> paths;
}

Future<_ExtraBundle> _resolveExtraModels({
  required Directory modelDir,
  required List<_ExtraEntry> entries,
}) async {
  final models = <List<int>>[];
  final paths = <String>[];
  for (final entry in entries) {
    try {
      final bytes = await _resolveModelBytes(
        modelDir: modelDir,
        fileName: entry.fileName,
        downloadUrl: entry.url,
        packId: entry.packId,
      );
      models.add(bytes);
      paths.add(entry.path);
    } catch (e) {
      if (entry.required) rethrow;
      stdout.writeln('WARN: optional model ${entry.fileName} skipped: $e');
    }
  }
  return _ExtraBundle(models: models, paths: paths);
}

class _PackSpec {
  const _PackSpec({
    required this.id,
    required this.name,
    required this.category,
    required this.format,
    required this.modelFile,
    required this.capabilities,
    required this.iconSource,
    required this.modelSource,
    this.extraModels = const [],
    this.extraModelPaths = const [],
  });

  final String id;
  final String name;
  final String category;
  final String format;
  final String modelFile;
  final List<String> capabilities;
  final String iconSource;
  final List<int> modelSource;
  final List<List<int>> extraModels;
  final List<String> extraModelPaths;
}
