import '../../models/app_models.dart';
import '../marketplace/marketplace_models.dart';

/// Input to the scanner pipeline — always a local file path.
class ScanInput {
  const ScanInput({
    required this.filePath,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    this.deepAiScan = false,
  });

  final String filePath;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  /// Thorough mode: stronger text and PII review; still suppresses photo noise.
  final bool deepAiScan;

  String get extension {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }
}

/// Bounding region for a visual finding (normalized 0–1).
class FindingRegion {
  const FindingRegion({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };

  factory FindingRegion.fromJson(Map<String, dynamic> json) {
    return FindingRegion(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
    );
  }
}

/// Single finding from one scanner plugin.
class PluginFinding {
  const PluginFinding({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.severity,
    required this.confidence,
    this.region,
    this.recommendation,
    this.metadata = const {},
    this.supportsBlur = false,
  });

  final String id;
  final String category;
  final String title;
  final String description;
  final RiskLevel severity;
  final double confidence;
  final FindingRegion? region;
  final String? recommendation;
  final Map<String, String> metadata;
  final bool supportsBlur;

  PrivacyFinding toPrivacyFinding() => PrivacyFinding(
        id: id,
        category: category,
        title: title,
        description: description,
        level: severity,
        recommendedAction: recommendation ??
            (region != null ? 'Enable blur to hide this sensitive area' : null),
        region: region == null
            ? null
            : PrivacyRegion(
                x: region!.x,
                y: region!.y,
                width: region!.width,
                height: region!.height,
              ),
        supportsBlur: supportsBlur || region != null,
        metadata: metadata,
        piiLabel: metadata['pii_label'],
      );
}

/// Result from a single plugin execution.
class PluginScanResult {
  const PluginScanResult({
    required this.pluginId,
    required this.pluginName,
    required this.pluginVersion,
    required this.findings,
    required this.processingTime,
    this.errorMessage,
  });

  final String pluginId;
  final String pluginName;
  final String pluginVersion;
  final List<PluginFinding> findings;
  final Duration processingTime;
  final String? errorMessage;

  bool get succeeded => errorMessage == null;
}

/// Aggregated pipeline output.
class ScanPipelineResult {
  const ScanPipelineResult({
    required this.sessionId,
    required this.fileName,
    required this.fileSize,
    required this.fileType,
    required this.scannedAt,
    required this.riskScore,
    required this.findings,
    required this.pluginResults,
    required this.totalDuration,
  });

  final String sessionId;
  final String fileName;
  final String fileSize;
  final String fileType;
  final DateTime scannedAt;
  final int riskScore;
  final List<PluginFinding> findings;
  final List<PluginScanResult> pluginResults;
  final Duration totalDuration;

  ScanSession toScanSession() => ScanSession(
        id: sessionId,
        fileName: fileName,
        fileSize: fileSize,
        fileType: fileType,
        scannedAt: scannedAt,
        riskScore: riskScore,
        findings: findings.map((f) => f.toPrivacyFinding()).toList(),
      );
}

/// Progress event emitted during scanning.
class ScanProgressEvent {
  const ScanProgressEvent({
    required this.stage,
    required this.progress,
    required this.activePluginId,
    required this.message,
  });

  final ScanStage stage;
  final double progress;
  final String? activePluginId;
  final String message;
}

/// Contract for scanner plugins — built-in, ONNX, or third-party SDK.
abstract class ScanPlugin {
  String get id;
  String get displayName;
  String get version;
  MarketplaceCategory get category;
  List<String> get capabilities;

  /// Plugin is registered (manifest present or built-in).
  bool get isInstalled;

  /// Plugin can execute scans right now (runtime + model ready).
  bool get isOperational;

  /// Maps to UI scan stage for progress display.
  ScanStage? get scanStage;

  Future<PluginScanResult> scan(ScanInput input);
}
