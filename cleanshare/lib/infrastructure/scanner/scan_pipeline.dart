import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';

import '../../domain/scanner/scanner_models.dart';
import '../../models/app_models.dart';
import '../../domain/storage/storage_layout.dart';
import '../plugins/plugin_discovery.dart';
import '../security/path_guard.dart';
import '../security/runtime_security_guard.dart';
import 'finding_enricher.dart';
import 'finding_normalizer.dart';
import 'risk_scorer.dart';

/// Orchestrates independent scanner plugins and aggregates results.
class ScanPipeline {
  ScanPipeline({
    required PluginDiscovery discovery,
    required RiskScorer riskScorer,
    required ZeroTraceLayout layout,
    RuntimeSecurityGuard? securityGuard,
  })  : _discovery = discovery,
        _riskScorer = riskScorer,
        _layout = layout,
        _securityGuard = securityGuard,
        _normalizer = const FindingNormalizer(),
        _enricher = const FindingEnricher();

  final PluginDiscovery _discovery;
  final RiskScorer _riskScorer;
  final ZeroTraceLayout _layout;
  final RuntimeSecurityGuard? _securityGuard;
  final FindingNormalizer _normalizer;
  final FindingEnricher _enricher;
  static const _uuid = Uuid();

  Stream<ScanProgressEvent> run(ScanInput input) async* {
    if (!kIsWeb) {
      await _securityGuard?.assertSensitiveOperation(operation: 'scan');
      PathGuard.assertScanPathAllowed(
        rootPath: _layout.root.path,
        filePath: input.filePath,
      );
    }

    final started = DateTime.now();
    final plugins = await _discovery.discoverOperational();
    final pluginResults = <PluginScanResult>[];
    final allFindings = <PluginFinding>[];

    if (plugins.isEmpty) {
      yield const ScanProgressEvent(
        stage: ScanStage.report,
        progress: 1,
        activePluginId: null,
        message: 'No scanners available.',
      );
      _lastResult = ScanPipelineResult(
        sessionId: _uuid.v4(),
        fileName: input.fileName,
        fileSize: _formatBytes(input.sizeBytes),
        fileType: input.extension.toUpperCase(),
        scannedAt: DateTime.now(),
        riskScore: 0,
        findings: const [],
        pluginResults: const [],
        totalDuration: DateTime.now().difference(started),
      );
      return;
    }

    for (var i = 0; i < plugins.length; i++) {
      final plugin = plugins[i];
      final stage = plugin.scanStage ?? ScanStage.metadata;
      final baseProgress = i / plugins.length;

      yield ScanProgressEvent(
        stage: stage,
        progress: baseProgress,
        activePluginId: plugin.id,
        message: _stageMessage(stage),
      );

      final result = await plugin.scan(input);
      pluginResults.add(result);
      allFindings.addAll(result.findings);

      yield ScanProgressEvent(
        stage: stage,
        progress: (i + 1) / plugins.length,
        activePluginId: plugin.id,
        message: result.succeeded
            ? '${plugin.displayName} complete'
            : '${plugin.displayName} failed',
      );
    }

    yield const ScanProgressEvent(
      stage: ScanStage.report,
      progress: 1,
      activePluginId: null,
      message: 'Building your report…',
    );

    final normalized = _normalizer.normalize(allFindings);
    final enriched = _enricher.enrich(normalized);
    final filtered = _normalizer.filterDocumentFalsePositives(
      enriched,
      extension: input.extension,
      deepScan: input.deepAiScan,
    );
    final riskScore = _riskScorer.score(filtered);
    final duration = DateTime.now().difference(started);

    _lastResult = ScanPipelineResult(
      sessionId: _uuid.v4(),
      fileName: input.fileName,
      fileSize: _formatBytes(input.sizeBytes),
      fileType: input.extension.toUpperCase(),
      scannedAt: DateTime.now(),
      riskScore: riskScore,
      findings: filtered,
      pluginResults: pluginResults,
      totalDuration: duration,
    );
  }

  ScanPipelineResult? _lastResult;

  ScanPipelineResult? get lastResult => _lastResult;

  String _stageMessage(ScanStage stage) => switch (stage) {
        ScanStage.metadata => 'Checking metadata…',
        ScanStage.faces => 'Scanning for faces…',
        ScanStage.qrCodes => 'Reading QR codes…',
        ScanStage.licensePlates => 'Detecting license plates…',
        ScanStage.documents => 'Reading document text…',
        ScanStage.report => 'Building your report…',
      };

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
