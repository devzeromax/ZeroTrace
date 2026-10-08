import 'package:universal_io/io.dart';

import '../../core/platform/platform_storage.dart';
import '../../domain/storage/storage_layout.dart';
import 'manifest_verifier.dart';

/// Why an optional ONNX pack may be installed but not scan-ready.
enum NeuralPackBlocker {
  none,
  notInstalled,
  onnxRuntimeOff,
  modelMissing,
  modelPlaceholder,
}

class NeuralPackDiagnostics {
  const NeuralPackDiagnostics({
    required this.packId,
    required this.installed,
    required this.blocker,
    this.modelBytes = 0,
    this.onnxRuntimeAvailable = false,
  });

  final String packId;
  final bool installed;
  final NeuralPackBlocker blocker;
  final int modelBytes;
  final bool onnxRuntimeAvailable;

  bool get isOperational =>
      installed && blocker == NeuralPackBlocker.none && modelBytes > 1024;

  String get displayTitle => switch (packId) {
        'face-protection' => 'Face detection pack not active',
        'vehicle-protection' => 'License plate pack not active',
        'document-protection' => 'Document OCR pack not active',
        _ => 'Neural pack not active',
      };

  String get userMessage => switch (blocker) {
        NeuralPackBlocker.none =>
          'Neural scanner is ready and will run on your next scan.',
        NeuralPackBlocker.notInstalled =>
          'Download this pack to enable on-device face detection.',
        NeuralPackBlocker.onnxRuntimeOff =>
          'Pack downloaded, but the ONNX runtime is not enabled in this build. '
          'Rebuild the engine with ONNX support to activate face detection.',
        NeuralPackBlocker.modelMissing =>
          'Pack files are missing on disk. Open Marketplace and install again, '
          'or pull to refresh — the app will restore bundled packs automatically.',
        NeuralPackBlocker.modelPlaceholder =>
          'Pack shell is installed, but full model weights are not present yet. '
          'Restart the app or re-download the pack from Marketplace.',
      };

  static Future<int> modelBytesOnDisk(
    ZeroTraceLayout layout,
    String packId,
  ) =>
      _modelBytes(layout, packId);

  static Future<bool> hasPlaceholderWeights(
    ZeroTraceLayout layout,
    String packId,
  ) async {
    final bytes = await _modelBytes(layout, packId);
    return bytes > 0 && bytes <= 1024;
  }

  /// Vehicle pack ships optional YOLOX weights for whole-car detection.
  static Future<bool> needsVehiclePackUpgrade(ZeroTraceLayout layout) async {
    if (!PlatformStorage.supportsLocalFileSystem) return false;
    final yolox = File(
      '${layout.packs.path}/vehicle-protection/models/yolox.onnx',
    );
    if (!await yolox.exists()) return true;
    return await yolox.length() <= 1024;
  }
  /// Face pack v1.1+ bundles MediaPipe BlazeFace alongside YuNet.
  static Future<bool> needsFacePackUpgrade(ZeroTraceLayout layout) async {
    if (!PlatformStorage.supportsLocalFileSystem) return false;
    final blazeface = File(
      '${layout.packs.path}/face-protection/models/blazeface.onnx',
    );
    if (!await blazeface.exists()) return true;
    return await blazeface.length() <= 1024;
  }

  static Future<NeuralPackDiagnostics> inspectPack({
    required ZeroTraceLayout layout,
    required String packId,
    required bool onnxRuntimeAvailable,
    required bool installed,
  }) async {
    if (!installed) {
      return NeuralPackDiagnostics(
        packId: packId,
        installed: false,
        blocker: NeuralPackBlocker.notInstalled,
        onnxRuntimeAvailable: onnxRuntimeAvailable,
      );
    }

    if (!onnxRuntimeAvailable) {
      return NeuralPackDiagnostics(
        packId: packId,
        installed: true,
        blocker: NeuralPackBlocker.onnxRuntimeOff,
        onnxRuntimeAvailable: false,
      );
    }

    final modelBytes = await _modelBytes(layout, packId);
    if (modelBytes == 0) {
      return NeuralPackDiagnostics(
        packId: packId,
        installed: true,
        blocker: NeuralPackBlocker.modelMissing,
        onnxRuntimeAvailable: true,
      );
    }
    if (modelBytes <= 1024) {
      return NeuralPackDiagnostics(
        packId: packId,
        installed: true,
        blocker: NeuralPackBlocker.modelPlaceholder,
        modelBytes: modelBytes,
        onnxRuntimeAvailable: true,
      );
    }

    return NeuralPackDiagnostics(
      packId: packId,
      installed: true,
      blocker: NeuralPackBlocker.none,
      modelBytes: modelBytes,
      onnxRuntimeAvailable: true,
    );
  }

  static Future<int> _modelBytes(ZeroTraceLayout layout, String packId) async {
    if (!PlatformStorage.supportsLocalFileSystem) return 0;

    final packDir = Directory('${layout.packs.path}/$packId');
    if (!await packDir.exists()) return 0;

    const verifier = ManifestVerifier();
    final manifestFile = await verifier.resolvePackManifestFile(packDir);
    if (manifestFile == null) return 0;

    try {
      final manifest = await verifier.readAndValidate(manifestFile);
      final relative = manifest.model.file;
      final modelPath = relative.contains('/')
          ? '${packDir.path}/$relative'
          : '${packDir.path}/models/$relative';
      final model = File(modelPath);
      if (!await model.exists()) return 0;
      return await model.length();
    } catch (_) {
      return 0;
    }
  }
}
