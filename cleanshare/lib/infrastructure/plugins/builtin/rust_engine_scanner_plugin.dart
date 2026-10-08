import 'dart:convert';

import '../../../domain/marketplace/marketplace_models.dart';
import '../../../domain/scanner/scanner_models.dart';
import '../../../models/app_models.dart';
import '../../engine/zerotrace_engine_bridge.dart';

/// Runs the bundled Rust `zerotrace_engine` scan pipeline (metadata + secrets).
class RustEngineScannerPlugin implements ScanPlugin {
  const RustEngineScannerPlugin();

  static const pluginId = 'zerotrace-engine';

  @override
  String get id => pluginId;

  @override
  String get displayName => 'ZeroTrace Engine';

  @override
  String get version {
    final caps = ZeroTraceEngineBridge.probe();
    return caps.version ?? '0.1.0';
  }

  @override
  MarketplaceCategory get category => MarketplaceCategory.metadataScanner;

  @override
  List<String> get capabilities => const [
        'metadata',
        'secrets',
        'offline',
      ];

  @override
  bool get isInstalled => true;

  @override
  bool get isOperational =>
      ZeroTraceEngineBridge.probe().nativeLibraryLoaded;

  @override
  ScanStage? get scanStage => ScanStage.metadata;

  @override
  Future<PluginScanResult> scan(ScanInput input) async {
    final started = DateTime.now();
    try {
      final json = ZeroTraceEngineBridge.runScanJson(input.filePath);
      if (json == null) {
        return PluginScanResult(
          pluginId: id,
          pluginName: displayName,
          pluginVersion: version,
          findings: const [],
          processingTime: DateTime.now().difference(started),
          errorMessage: 'Rust engine returned no result.',
        );
      }

      final decoded = jsonDecode(json) as Map<String, dynamic>;
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

  PluginFinding _findingFromJson(Map<String, dynamic> json) {
    FindingRegion? region;
    final regionJson = json['region'];
    if (regionJson is Map<String, dynamic>) {
      region = FindingRegion.fromJson(regionJson);
    }

    return PluginFinding(
      id: json['id'] as String? ?? 'zt-rust',
      category: json['category'] as String? ?? 'Unknown',
      title: json['title'] as String? ?? 'Finding',
      description: json['description'] as String? ?? '',
      severity: _severityFromString(json['severity'] as String? ?? 'medium'),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.8,
      recommendation: json['recommendation'] as String?,
      region: region,
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
