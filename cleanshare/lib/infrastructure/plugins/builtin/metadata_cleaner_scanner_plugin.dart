import 'package:universal_io/io.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/marketplace/marketplace_models.dart';
import '../../../domain/scanner/scanner_models.dart';
import '../../../models/app_models.dart';

/// Advanced metadata rules — PDF, Office, and container metadata.
class MetadataCleanerScannerPlugin implements ScanPlugin {
  const MetadataCleanerScannerPlugin();

  static const pluginId = 'metadata-cleaner';

  @override
  String get id => pluginId;

  @override
  String get displayName => 'Metadata Cleaner';

  @override
  String get version => '1.0.0';

  @override
  MarketplaceCategory get category => MarketplaceCategory.metadataScanner;

  @override
  List<String> get capabilities => const ['metadata_advanced'];

  @override
  bool get isInstalled => true;

  @override
  bool get isOperational => true;

  @override
  ScanStage? get scanStage => ScanStage.metadata;

  static const _pdfMarkers = {
    '/Producer': ('PDF producer identified', RiskLevel.medium),
    '/Creator': ('PDF creator app identified', RiskLevel.medium),
    '/Author': ('PDF author name embedded', RiskLevel.high),
    '/Title': ('PDF title metadata embedded', RiskLevel.low),
    '/Subject': ('PDF subject metadata embedded', RiskLevel.low),
    '/Keywords': ('PDF keywords embedded', RiskLevel.low),
    '/CreationDate': ('PDF creation date embedded', RiskLevel.medium),
    '/ModDate': ('PDF modification date embedded', RiskLevel.medium),
  };

  @override
  Future<PluginScanResult> scan(ScanInput input) async {
    final started = DateTime.now();
    final findings = <PluginFinding>[];
    const uuid = Uuid();

    try {
      final bytes = await File(input.filePath).readAsBytes();
      final ext = input.extension.toLowerCase();

      if (ext == 'pdf') {
        final sample = String.fromCharCodes(bytes.take(65536));
        final hits = <String, (String, RiskLevel)>{
          for (final entry in _pdfMarkers.entries)
            if (sample.contains(entry.key)) entry.key: entry.value,
        };

        if (hits.isNotEmpty) {
          final highest = _highestSeverity(hits.values.map((e) => e.$2));
          final markerList = hits.keys.map((k) => k.replaceFirst('/', '')).join(', ');
          final titles = hits.values.map((e) => e.$1).toList();

          if (hits.length == 1) {
            final only = hits.entries.first;
            findings.add(
              PluginFinding(
                id: uuid.v4(),
                category: 'Metadata',
                title: only.value.$1,
                description: 'Found ${only.key} in document header.',
                severity: only.value.$2,
                confidence: 0.82,
                recommendation: 'Enable “Remove metadata” on export.',
                metadata: {'marker': only.key},
              ),
            );
          } else {
            findings.add(
              PluginFinding(
                id: uuid.v4(),
                category: 'Metadata',
                title: 'PDF metadata embedded (${hits.length} fields)',
                description:
                    'Found ${hits.length} metadata fields: $markerList. '
                    '${titles.take(2).join('; ')}${titles.length > 2 ? '…' : ''}',
                severity: highest,
                confidence: 0.88,
                recommendation: 'Enable “Remove metadata” on export — strips all ${hits.length} fields at once.',
                metadata: {
                  'markers': hits.keys.join(','),
                  'field_count': '${hits.length}',
                },
              ),
            );
          }
        }
      }

      if (ext == 'zip' || ext == 'docx' || ext == 'xlsx' || ext == 'pptx') {
        final sample = String.fromCharCodes(bytes.take(8192));
        if (sample.contains('docProps') || sample.contains('core.xml')) {
          findings.add(
            PluginFinding(
              id: uuid.v4(),
              category: 'Metadata',
              title: 'Office document properties present',
              description:
                  'Embedded author, company, or revision metadata may be included.',
              severity: RiskLevel.medium,
              confidence: 0.75,
              recommendation: 'Sanitize document properties before sharing.',
            ),
          );
        }
      }
    } catch (e) {
      return PluginScanResult(
        pluginId: id,
        pluginName: displayName,
        pluginVersion: version,
        findings: findings,
        processingTime: DateTime.now().difference(started),
        errorMessage: e.toString(),
      );
    }

    return PluginScanResult(
      pluginId: id,
      pluginName: displayName,
      pluginVersion: version,
      findings: findings,
      processingTime: DateTime.now().difference(started),
    );
  }

  static RiskLevel _highestSeverity(Iterable<RiskLevel> levels) {
    for (final level in const [
      RiskLevel.critical,
      RiskLevel.high,
      RiskLevel.medium,
      RiskLevel.low,
      RiskLevel.none,
    ]) {
      if (levels.contains(level)) return level;
    }
    return RiskLevel.none;
  }
}
