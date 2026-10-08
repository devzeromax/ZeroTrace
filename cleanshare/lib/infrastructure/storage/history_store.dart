import 'dart:convert';

import '../../core/platform/platform_storage.dart';
import '../../domain/storage/storage_layout.dart';
import '../../models/app_models.dart';
import '../security/secure_settings_cipher.dart';

/// Persists scan history encrypted at rest (Keychain / Keystore backed key).
class HistoryStore {
  HistoryStore(
    this._layout, {
    SecureSettingsCipher? cipher,
  }) : _cipher = cipher ?? SecureSettingsCipher();

  final ZeroTraceLayout _layout;
  final SecureSettingsCipher _cipher;

  Future<List<ScanSession>> readAll() async {
    final file = _layout.historyIndex();
    if (!await file.exists()) return [];

    if (PlatformStorage.supportsLocalFileSystem) {
      final encrypted = await _cipher.readEncryptedFile(file);
      if (encrypted != null) {
        return _parseSessions(encrypted);
      }
    }

    final legacy = await file.readAsString();
    return _parseSessions(legacy);
  }

  Future<void> writeAll(List<ScanSession> sessions) async {
    final file = _layout.historyIndex();
    final payload = jsonEncode(sessions.map(_sessionToJson).toList());

    if (PlatformStorage.supportsLocalFileSystem) {
      await _cipher.writeEncryptedFile(file, payload);
      return;
    }
    await file.writeAsString(payload);
  }

  List<ScanSession> _parseSessions(String raw) {
    final json = jsonDecode(raw) as List<dynamic>;
    return json
        .map((e) => _sessionFromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> upsert(ScanSession session) async {
    final all = await readAll();
    final next = [
      session,
      ...all.where((s) => s.id != session.id),
    ];
    await writeAll(next);
  }

  Future<void> remove(String id) async {
    final all = await readAll();
    await writeAll(all.where((s) => s.id != id).toList());
  }

  Future<void> clear() async {
    final file = _layout.historyIndex();
    if (await file.exists()) await file.delete();
  }

  Map<String, dynamic> _sessionToJson(ScanSession s) => {
        'id': s.id,
        'fileName': s.fileName,
        'fileSize': s.fileSize,
        'fileType': s.fileType,
        'scannedAt': s.scannedAt.toIso8601String(),
        'riskScore': s.riskScore,
        'isExported': s.isExported,
        if (s.stagedFilePath != null) 'stagedFilePath': s.stagedFilePath,
        if (s.exportedFilePath != null) 'exportedFilePath': s.exportedFilePath,
        'findings': s.findings
            .map(
              (f) => {
                'id': f.id,
                'category': f.category,
                'title': f.title,
                'description': f.description,
                'level': f.level.name,
                'isFixed': f.isFixed,
                'recommendedAction': f.recommendedAction,
                'supportsBlur': f.supportsBlur,
                if (f.region != null)
                  'region': {
                    'x': f.region!.x,
                    'y': f.region!.y,
                    'width': f.region!.width,
                    'height': f.region!.height,
                  },
                if (f.metadata.isNotEmpty) 'metadata': f.metadata,
                if (f.piiLabel != null) 'piiLabel': f.piiLabel,
              },
            )
            .toList(),
      };

  ScanSession _sessionFromJson(Map<String, dynamic> json) {
    final findings = (json['findings'] as List<dynamic>)
        .map((e) => _findingFromJson(e as Map<String, dynamic>))
        .toList();

    return ScanSession(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      fileSize: json['fileSize'] as String,
      fileType: json['fileType'] as String,
      scannedAt: DateTime.parse(json['scannedAt'] as String),
      riskScore: json['riskScore'] as int,
      isExported: json['isExported'] as bool? ?? false,
      stagedFilePath: json['stagedFilePath'] as String?,
      exportedFilePath: json['exportedFilePath'] as String?,
      findings: findings,
    );
  }

  PrivacyFinding _findingFromJson(Map<String, dynamic> json) {
    PrivacyRegion? region;
    final regionJson = json['region'];
    if (regionJson is Map<String, dynamic>) {
      region = PrivacyRegion(
        x: (regionJson['x'] as num).toDouble(),
        y: (regionJson['y'] as num).toDouble(),
        width: (regionJson['width'] as num).toDouble(),
        height: (regionJson['height'] as num).toDouble(),
      );
    }

    final metadataRaw = json['metadata'];
    final metadata = metadataRaw is Map
        ? metadataRaw.map(
            (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
          )
        : const <String, String>{};

    return PrivacyFinding(
      id: json['id'] as String,
      category: json['category'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      level: RiskLevel.values.byName(json['level'] as String),
      isFixed: json['isFixed'] as bool? ?? false,
      recommendedAction: json['recommendedAction'] as String?,
      region: region,
      supportsBlur: json['supportsBlur'] as bool? ?? region != null,
      metadata: metadata,
      piiLabel: json['piiLabel'] as String?,
    );
  }
}
