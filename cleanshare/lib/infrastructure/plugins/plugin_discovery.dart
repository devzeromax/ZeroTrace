import 'dart:convert';

import 'package:universal_io/io.dart';

import '../../core/platform/platform_storage.dart';
import '../../infrastructure/engine/zerotrace_engine_bridge.dart';
import '../../domain/marketplace/marketplace_models.dart';
import '../../domain/scanner/scanner_models.dart';
import '../../domain/storage/storage_layout.dart';
import '../../models/app_models.dart';
import '../security/installed_pack_trust.dart';
import '../marketplace/manifest_verifier.dart';
import 'builtin/document_pdf_text_scanner.dart';
import 'builtin/developer_secrets_scanner_plugin.dart';
import 'builtin/metadata_cleaner_scanner_plugin.dart';
import 'builtin/metadata_scanner_plugin.dart';
import 'builtin/qr_scanner_plugin.dart';

/// ONNX model plugin — operational only when model file exists and runtime is linked.
class OnnxScanPlugin implements ScanPlugin {
  OnnxScanPlugin({
    required this.manifest,
    required this.packDirectory,
    required this.onnxRuntimeAvailable,
  });

  final PluginManifest manifest;
  final Directory packDirectory;
  final bool onnxRuntimeAvailable;

  @override
  String get id => manifest.id;

  @override
  String get displayName => manifest.name;

  @override
  String get version => manifest.version;

  @override
  MarketplaceCategory get category => manifest.category;

  @override
  List<String> get capabilities => manifest.capabilities;

  @override
  bool get isInstalled => true;

  @override
  bool get isOperational {
    if (!onnxRuntimeAvailable) return false;
    final model = _resolveModelPath();
    if (!model.existsSync()) return false;
    // Reject placeholder stubs until real ONNX weights are shipped.
    return model.lengthSync() > 1024;
  }

  File _resolveModelPath() {
    final relative = manifest.model.file;
    if (relative.contains('/')) {
      return File('${packDirectory.path}/$relative');
    }
    return File('${packDirectory.path}/models/$relative');
  }

  @override
  ScanStage? get scanStage => switch (manifest.category) {
        MarketplaceCategory.faceDetection => ScanStage.faces,
        MarketplaceCategory.qrDetection => ScanStage.qrCodes,
        MarketplaceCategory.licensePlateDetection => ScanStage.licensePlates,
        MarketplaceCategory.ocr => ScanStage.documents,
        MarketplaceCategory.documentScanner => ScanStage.documents,
        _ => null,
      };

  @override
  Future<PluginScanResult> scan(ScanInput input) async {
    final started = DateTime.now();
    final model = _resolveModelPath();

    // Image ONNX detectors (face/vehicle/document OCR) only handle raster images.
    // PDFs use text-layer extraction for Document Protection (not PPOCR heatmaps).
    if (!_isSupportedImage(input.filePath)) {
      if (manifest.id == 'document-protection' &&
          input.extension.toLowerCase() == 'pdf') {
        return DocumentPdfTextScanner.scan(
          input: input,
          pluginId: id,
          pluginName: displayName,
          pluginVersion: version,
        );
      }
      return PluginScanResult(
        pluginId: id,
        pluginName: displayName,
        pluginVersion: version,
        findings: const [],
        processingTime: DateTime.now().difference(started),
      );
    }

    try {
      final json = await ZeroTraceEngineBridge.runOnnxScanJsonAsync(
        filePath: input.filePath,
        modelPath: model.path,
        packId: manifest.id,
      );
      if (json == null) {
        return PluginScanResult(
          pluginId: id,
          pluginName: displayName,
          pluginVersion: version,
          findings: const [],
          processingTime: DateTime.now().difference(started),
          errorMessage:
              '$displayName could not run. Quit the app fully, then restart after updating the scanner engine.',
        );
      }

      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final engineError = decoded['error'] as String?;
      if (engineError != null && engineError.isNotEmpty) {
        return PluginScanResult(
          pluginId: id,
          pluginName: displayName,
          pluginVersion: version,
          findings: const [],
          processingTime: DateTime.now().difference(started),
          errorMessage: engineError,
        );
      }

      final rawFindings = decoded['findings'] as List<dynamic>? ?? [];
      final findings = rawFindings
          .map((f) => _findingFromJson(f as Map<String, dynamic>))
          .toList();

      return PluginScanResult(
        pluginId: id,
        pluginName: displayName,
        pluginVersion: version,
        findings: findings,
        processingTime: DateTime.now().difference(started),
      );
    } catch (e) {
      return PluginScanResult(
        pluginId: id,
        pluginName: displayName,
        pluginVersion: version,
        findings: const [],
        processingTime: DateTime.now().difference(started),
        errorMessage: e.toString(),
      );
    }
  }

  static const _imageExtensions = {
    '.jpg', '.jpeg', '.png', '.bmp', '.webp', '.tif', '.tiff', '.gif', '.ico',
    '.tga', '.pnm', '.ppm', '.pgm', '.pbm', '.heic', '.heif',
  };

  bool _isSupportedImage(String path) {
    final lower = path.toLowerCase();
    return _imageExtensions.any(lower.endsWith);
  }

  PluginFinding _findingFromJson(Map<String, dynamic> json) {
    FindingRegion? region;
    final regionJson = json['region'];
    if (regionJson is Map<String, dynamic>) {
      region = FindingRegion.fromJson(regionJson);
    }

    return PluginFinding(
      id: json['id'] as String? ?? 'onnx-$id',
      category: json['category'] as String? ?? manifest.category.id,
      title: json['title'] as String? ?? 'Detection',
      description: json['description'] as String? ?? '',
      severity: _severityFromString(json['severity'] as String? ?? 'medium'),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.75,
      recommendation: json['recommendation'] as String?,
      region: region,
      metadata: _metadataFromJson(json['metadata']),
      supportsBlur: json['supports_blur'] as bool? ?? region != null,
    );
  }

  Map<String, String> _metadataFromJson(dynamic raw) {
    if (raw is! Map) return const {};
    return raw.map(
      (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
    );
  }

  RiskLevel _severityFromString(String value) => switch (value.toLowerCase()) {
        'critical' => RiskLevel.critical,
        'high' => RiskLevel.high,
        'medium' => RiskLevel.medium,
        'low' => RiskLevel.low,
        _ => RiskLevel.none,
      };
}

/// Rules-based plugin loaded from an installed pack.
class RulesScanPlugin implements ScanPlugin {
  RulesScanPlugin({
    required this.manifest,
    required this.delegate,
  });

  final PluginManifest manifest;
  final ScanPlugin delegate;

  @override
  String get id => manifest.id;

  @override
  String get displayName => manifest.name;

  @override
  String get version => manifest.version;

  @override
  MarketplaceCategory get category => manifest.category;

  @override
  List<String> get capabilities => manifest.capabilities;

  @override
  bool get isInstalled => true;

  @override
  bool get isOperational => delegate.isOperational;

  @override
  ScanStage? get scanStage => delegate.scanStage;

  @override
  Future<PluginScanResult> scan(ScanInput input) => delegate.scan(input);
}

/// Discovers packs from disk and registers built-ins.
class PluginDiscovery {
  PluginDiscovery({
    required ZeroTraceLayout layout,
    required ManifestVerifier verifier,
    this.onnxRuntimeAvailable = false,
    InstalledPackTrustVerifier? packTrust,
  })  : _layout = layout,
        _verifier = verifier,
        _packTrust = packTrust ?? const InstalledPackTrustVerifier();

  final ZeroTraceLayout _layout;
  final ManifestVerifier _verifier;
  final InstalledPackTrustVerifier _packTrust;
  final bool onnxRuntimeAvailable;

  Future<List<ScanPlugin>> discoverAll() async {
    final plugins = <ScanPlugin>[
      const MetadataScannerPlugin(),
      const QrScannerPlugin(),
      const MetadataCleanerScannerPlugin(),
      const DeveloperSecretsScannerPlugin(),
    ];

    final registeredIds = plugins.map((p) => p.id).toSet();

    final packsRoot = _layout.packs;
    if (!PlatformStorage.supportsLocalFileSystem) return plugins;
    if (!await packsRoot.exists()) return plugins;

    await for (final entity in packsRoot.list()) {
      if (entity is! Directory) continue;

      final manifestFile = await _verifier.resolvePackManifestFile(entity);
      if (manifestFile == null) continue;

      try {
        final manifest = await _verifier.readAndValidate(manifestFile);
        if (manifest.model.format == 'builtin') continue;

        if (manifest.model.format == 'onnx' ||
            manifest.model.format == 'rules') {
          await _packTrust.assertTrustworthy(
            packDir: entity,
            manifest: manifest,
          );
        }

        if (manifest.model.format == 'rules') {
          final delegate = _builtinDelegateFor(manifest.id);
          if (delegate != null && !registeredIds.contains(manifest.id)) {
            plugins.add(
              RulesScanPlugin(manifest: manifest, delegate: delegate),
            );
            registeredIds.add(manifest.id);
          }
          continue;
        }

        if (registeredIds.contains(manifest.id)) continue;

        plugins.add(
          OnnxScanPlugin(
            manifest: manifest,
            packDirectory: entity,
            onnxRuntimeAvailable: onnxRuntimeAvailable,
          ),
        );
        registeredIds.add(manifest.id);
      } catch (e) {
        // Skip invalid pack bundles — logged at debug via manifest verifier.
      }
    }

    return plugins;
  }

  ScanPlugin? _builtinDelegateFor(String packId) => switch (packId) {
        MetadataScannerPlugin.pluginId => const MetadataScannerPlugin(),
        MetadataCleanerScannerPlugin.pluginId =>
          const MetadataCleanerScannerPlugin(),
        DeveloperSecretsScannerPlugin.pluginId =>
          const DeveloperSecretsScannerPlugin(),
        'qr-protection' || 'qr-protection-dart' => const QrScannerPlugin(),
        _ => null,
      };

  Future<List<ScanPlugin>> discoverOperational() async {
    final all = await discoverAll();
    return all.where((p) => p.isOperational).toList();
  }
}
