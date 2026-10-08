import 'package:universal_io/io.dart';

import 'package:uuid/uuid.dart';

import '../../../domain/marketplace/marketplace_models.dart';
import '../../../domain/scanner/scanner_models.dart';
import '../../../models/app_models.dart';

/// Regex-based secrets scanner for developer artifacts.
class DeveloperSecretsScannerPlugin implements ScanPlugin {
  const DeveloperSecretsScannerPlugin();

  static const pluginId = 'developer-protection';

  @override
  String get id => pluginId;

  @override
  String get displayName => 'Developer Protection Pack';

  @override
  String get version => '1.0.0';

  @override
  MarketplaceCategory get category => MarketplaceCategory.developerTools;

  @override
  List<String> get capabilities => const ['secrets'];

  @override
  bool get isInstalled => true;

  @override
  bool get isOperational => true;

  @override
  ScanStage? get scanStage => ScanStage.metadata;

  static final _patterns = <_SecretPattern>[
    _SecretPattern(
      name: 'AWS Access Key',
      pattern: RegExp(r'AKIA[0-9A-Z]{16}'),
      severity: RiskLevel.critical,
    ),
    _SecretPattern(
      name: 'GitHub Token',
      pattern: RegExp(r'ghp_[A-Za-z0-9]{36,}'),
      severity: RiskLevel.critical,
    ),
    _SecretPattern(
      name: 'GitHub OAuth',
      pattern: RegExp(r'gho_[A-Za-z0-9]{36,}'),
      severity: RiskLevel.critical,
    ),
    _SecretPattern(
      name: 'JWT Token',
      pattern: RegExp(r'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'),
      severity: RiskLevel.high,
    ),
    _SecretPattern(
      name: 'Generic API Key',
      pattern: RegExp(
        r'''(api[_-]?key|secret[_-]?key)\s*[:=]\s*["']?[A-Za-z0-9-]{16,}''',
        caseSensitive: false,
      ),
      severity: RiskLevel.high,
    ),
  ];

  @override
  Future<PluginScanResult> scan(ScanInput input) async {
    final started = DateTime.now();
    final findings = <PluginFinding>[];
    const uuid = Uuid();

    if (!_isTextLike(input.extension)) {
      return PluginScanResult(
        pluginId: id,
        pluginName: displayName,
        pluginVersion: version,
        findings: findings,
        processingTime: DateTime.now().difference(started),
      );
    }

    try {
      final content = await File(input.filePath).readAsString();
      for (final rule in _patterns) {
        final match = rule.pattern.firstMatch(content);
        if (match == null) continue;

        findings.add(
          PluginFinding(
            id: uuid.v4(),
            category: 'Developer Tools',
            title: '${rule.name} detected',
            description:
                'A ${rule.name.toLowerCase()} pattern was found in this file.',
            severity: rule.severity,
            confidence: 0.9,
            recommendation: 'Rotate the credential and remove it before sharing.',
            metadata: {'offset': '${match.start}'},
          ),
        );
      }
    } catch (_) {
      // Binary or unreadable — skip silently.
    }

    return PluginScanResult(
      pluginId: id,
      pluginName: displayName,
      pluginVersion: version,
      findings: findings,
      processingTime: DateTime.now().difference(started),
    );
  }

  bool _isTextLike(String ext) => {
        'txt',
        'md',
        'json',
        'env',
        'yaml',
        'yml',
        'dart',
        'ts',
        'js',
        'py',
        'pdf',
      }.contains(ext.toLowerCase());
}

class _SecretPattern {
  const _SecretPattern({
    required this.name,
    required this.pattern,
    required this.severity,
  });

  final String name;
  final RegExp pattern;
  final RiskLevel severity;
}
