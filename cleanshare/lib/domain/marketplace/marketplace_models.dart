import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
enum MarketplaceCategory {
  faceDetection,
  qrDetection,
  licensePlateDetection,
  ocr,
  documentScanner,
  metadataScanner,
  developerTools,
  futureModels,
}

extension MarketplaceCategoryX on MarketplaceCategory {
  String get id => switch (this) {
        MarketplaceCategory.faceDetection => 'face_detection',
        MarketplaceCategory.qrDetection => 'qr_detection',
        MarketplaceCategory.licensePlateDetection => 'license_plate_detection',
        MarketplaceCategory.ocr => 'ocr',
        MarketplaceCategory.documentScanner => 'document_scanner',
        MarketplaceCategory.metadataScanner => 'metadata_scanner',
        MarketplaceCategory.developerTools => 'developer_tools',
        MarketplaceCategory.futureModels => 'future_models',
      };

  String get label => switch (this) {
        MarketplaceCategory.faceDetection => 'Face Detection',
        MarketplaceCategory.qrDetection => 'QR Detection',
        MarketplaceCategory.licensePlateDetection => 'License Plate Detection',
        MarketplaceCategory.ocr => 'OCR',
        MarketplaceCategory.documentScanner => 'Document Scanner',
        MarketplaceCategory.metadataScanner => 'Metadata Scanner',
        MarketplaceCategory.developerTools => 'Developer Tools',
        MarketplaceCategory.futureModels => 'Coming Soon',
      };

  static MarketplaceCategory fromId(String id) {
    return MarketplaceCategory.values.firstWhere(
      (c) => c.id == id,
      orElse: () => MarketplaceCategory.futureModels,
    );
  }
}

/// Installation state for a marketplace entry.
enum ModelInstallState {
  notInstalled,
  downloading,
  installed,
  updateAvailable,
  failed,
}

/// Remote / bundled catalog entry shown in the marketplace.
class ModelCatalogEntry {
  const ModelCatalogEntry({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    required this.developer,
    required this.category,
    required this.sizeBytes,
    required this.downloadCount,
    required this.license,
    required this.compatibility,
    required this.builtin,
    required this.capabilities,
    required this.manifest,
    this.iconAsset,
    this.bundleAsset,
  });

  final String id;
  final String name;
  final String description;
  final String version;
  final String developer;
  final MarketplaceCategory category;
  final int sizeBytes;
  final int downloadCount;
  final String license;
  final ModelCompatibility compatibility;
  final bool builtin;
  final List<String> capabilities;
  final ModelManifestRef manifest;
  /// Optional pack cover image (bundled asset path or user override).
  final String? iconAsset;
  /// Optional bundled pack zip shipped with the app for offline install.
  final String? bundleAsset;

  factory ModelCatalogEntry.fromJson(Map<String, dynamic> json) {
    return ModelCatalogEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      version: json['version'] as String,
      developer: json['developer'] as String,
      category: MarketplaceCategoryX.fromId(json['category'] as String),
      sizeBytes: json['sizeBytes'] as int,
      downloadCount: json['downloadCount'] as int? ?? 0,
      license: json['license'] as String,
      compatibility: ModelCompatibility.fromJson(
        json['compatibility'] as Map<String, dynamic>,
      ),
      builtin: json['builtin'] as bool? ?? false,
      capabilities: (json['capabilities'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      manifest: ModelManifestRef.fromJson(
        json['manifest'] as Map<String, dynamic>,
      ),
      iconAsset: json['iconAsset'] as String?,
      bundleAsset: json['bundleAsset'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'version': version,
        'developer': developer,
        'category': category.id,
        'sizeBytes': sizeBytes,
        'downloadCount': downloadCount,
        'license': license,
        'compatibility': compatibility.toJson(),
        'builtin': builtin,
        'capabilities': capabilities,
        'manifest': manifest.toJson(),
        if (iconAsset != null) 'iconAsset': iconAsset,
        if (bundleAsset != null) 'bundleAsset': bundleAsset,
      };
}

class ModelCompatibility {
  const ModelCompatibility({
    required this.minAppVersion,
    required this.platforms,
  });

  final String minAppVersion;
  final List<String> platforms;

  factory ModelCompatibility.fromJson(Map<String, dynamic> json) {
    return ModelCompatibility(
      minAppVersion: json['minAppVersion'] as String,
      platforms: (json['platforms'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'minAppVersion': minAppVersion,
        'platforms': platforms,
      };

  bool get supportsCurrentPlatform {
    if (kIsWeb) return platforms.contains('web');
    final os = Platform.operatingSystem;
    return platforms.contains(os);
  }
}

/// Reference to downloadable or built-in model payload.
class ModelManifestRef {
  const ModelManifestRef({
    required this.format,
    required this.pluginId,
    this.modelFile,
    this.sha256,
    this.downloadUrl,
    this.signature,
  });

  final String format;
  final String pluginId;
  final String? modelFile;
  final String? sha256;
  final String? downloadUrl;
  final String? signature;

  factory ModelManifestRef.fromJson(Map<String, dynamic> json) {
    return ModelManifestRef(
      format: json['format'] as String,
      pluginId: json['pluginId'] as String,
      modelFile: json['modelFile'] as String?,
      sha256: json['sha256'] as String?,
      downloadUrl: json['downloadUrl'] as String?,
      signature: json['signature'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'format': format,
        'pluginId': pluginId,
        if (modelFile != null) 'modelFile': modelFile,
        if (sha256 != null) 'sha256': sha256,
        if (downloadUrl != null) 'downloadUrl': downloadUrl,
        if (signature != null) 'signature': signature,
      };

  bool get isOnnx => format == 'onnx';
  bool get isRules => format == 'rules';
  bool get isBuiltin => format == 'builtin';
}

/// Catalog helpers for marketplace presentation.
extension ModelCatalogEntryX on ModelCatalogEntry {
  /// Large ONNX packs — only needed for face blur, plates, or document OCR.
  bool get isOptionalNeuralPack => manifest.isOnnx;

  /// KB/built-in scanners ship with the app.
  bool get isIncludedScanner => builtin || manifest.isRules || !manifest.isOnnx;

  String get packBriefLabel => switch (id) {
        'face-protection' => 'Blur faces before sharing photos',
        'vehicle-protection' => 'Find license plates and vehicles in images',
        'document-protection' => 'Detect and redact sensitive text in documents',
        _ => category.label,
      };

  /// @deprecated Use [packBriefLabel].
  String get neuralUseCaseLabel => packBriefLabel;
}

/// Installed plugin manifest on disk (`zerotrace.plugin.json`).
class PluginManifest {
  const PluginManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.developer,
    required this.category,
    required this.capabilities,
    required this.model,
    required this.minAppVersion,
    required this.license,
    this.signature,
    this.artifactSha256,
  });

  final String id;
  final String name;
  final String version;
  final String developer;
  final MarketplaceCategory category;
  final List<String> capabilities;
  final PluginModelSpec model;
  final String minAppVersion;
  final String license;
  final String? signature;

  /// SHA-256 of the signed pack archive (zip). Differs from [model.sha256].
  final String? artifactSha256;

  factory PluginManifest.fromJson(Map<String, dynamic> json) {
    return PluginManifest(
      id: json['id'] as String,
      name: json['name'] as String,
      version: json['version'] as String,
      developer: json['developer'] as String,
      category: MarketplaceCategoryX.fromId(json['category'] as String),
      capabilities: (json['capabilities'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      model: PluginModelSpec.fromJson(json['model'] as Map<String, dynamic>),
      minAppVersion: json['minAppVersion'] as String,
      license: json['license'] as String,
      signature: json['signature'] as String?,
      artifactSha256: json['artifactSha256'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'version': version,
        'developer': developer,
        'category': category.id,
        'capabilities': capabilities,
        'model': model.toJson(),
        'minAppVersion': minAppVersion,
        'license': license,
        if (signature != null) 'signature': signature,
        if (artifactSha256 != null) 'artifactSha256': artifactSha256,
      };
}

class PluginModelSpec {
  const PluginModelSpec({
    required this.format,
    required this.file,
    required this.sha256,
    required this.sizeBytes,
  });

  final String format;
  final String file;
  final String sha256;
  final int sizeBytes;

  factory PluginModelSpec.fromJson(Map<String, dynamic> json) {
    return PluginModelSpec(
      format: json['format'] as String,
      file: json['file'] as String,
      sha256: json['sha256'] as String,
      sizeBytes: json['sizeBytes'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'format': format,
        'file': file,
        'sha256': sha256,
        'sizeBytes': sizeBytes,
      };
}

/// Runtime install record persisted locally.
class InstalledModelRecord {
  const InstalledModelRecord({
    required this.id,
    required this.version,
    required this.installedAt,
    required this.pluginDirectory,
    required this.state,
    this.updateVersion,
  });

  final String id;
  final String version;
  final DateTime installedAt;
  final String pluginDirectory;
  final ModelInstallState state;
  final String? updateVersion;

  InstalledModelRecord copyWith({
    String? version,
    DateTime? installedAt,
    String? pluginDirectory,
    ModelInstallState? state,
    String? updateVersion,
    bool clearUpdate = false,
  }) {
    return InstalledModelRecord(
      id: id,
      version: version ?? this.version,
      installedAt: installedAt ?? this.installedAt,
      pluginDirectory: pluginDirectory ?? this.pluginDirectory,
      state: state ?? this.state,
      updateVersion: clearUpdate ? null : (updateVersion ?? this.updateVersion),
    );
  }

  factory InstalledModelRecord.fromJson(Map<String, dynamic> json) {
    return InstalledModelRecord(
      id: json['id'] as String,
      version: json['version'] as String,
      installedAt: DateTime.parse(json['installedAt'] as String),
      pluginDirectory: json['pluginDirectory'] as String,
      state: ModelInstallState.values.byName(json['state'] as String),
      updateVersion: json['updateVersion'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'version': version,
        'installedAt': installedAt.toIso8601String(),
        'pluginDirectory': pluginDirectory,
        'state': state.name,
        if (updateVersion != null) 'updateVersion': updateVersion,
      };
}
