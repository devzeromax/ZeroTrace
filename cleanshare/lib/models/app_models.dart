enum RiskLevel { critical, high, medium, low, none }

enum ScanStage {
  metadata,
  faces,
  qrCodes,
  licensePlates,
  documents,
  report,
}

enum ScanStageStatus { pending, active, complete, failed, skipped }

enum WorkflowStep { upload, scan, audit, fix, export }

class PrivacyFinding {
  const PrivacyFinding({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.level,
    this.isFixed = false,
    this.recommendedAction,
    this.region,
    this.supportsBlur = false,
    this.metadata = const {},
    this.piiLabel,
  });

  final String id;
  final String category;
  final String title;
  final String description;
  final RiskLevel level;
  final bool isFixed;
  final String? recommendedAction;
  final PrivacyRegion? region;
  final bool supportsBlur;
  final Map<String, String> metadata;
  final String? piiLabel;

  bool get hasPii => piiLabel != null || metadata.containsKey('pii_label');

  PrivacyFinding copyWith({bool? isFixed}) => PrivacyFinding(
        id: id,
        category: category,
        title: title,
        description: description,
        level: level,
        isFixed: isFixed ?? this.isFixed,
        recommendedAction: recommendedAction,
        region: region,
        supportsBlur: supportsBlur,
        metadata: metadata,
        piiLabel: piiLabel,
      );
}

/// Normalized bounding box (0–1) for blur/redaction export.
class PrivacyRegion {
  const PrivacyRegion({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;
}

class ScanSession {
  const ScanSession({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.fileType,
    required this.scannedAt,
    required this.riskScore,
    required this.findings,
    this.isExported = false,
    this.stagedFilePath,
    this.exportedFilePath,
  });

  final String id;
  final String fileName;
  final String fileSize;
  final String fileType;
  final DateTime scannedAt;
  final int riskScore;
  final List<PrivacyFinding> findings;
  final bool isExported;
  /// Staged source under ZeroTrace/scans/ — needed for re-export from history.
  final String? stagedFilePath;
  /// Last sanitized output under ZeroTrace/exports/.
  final String? exportedFilePath;

  ScanSession copyWith({
    String? id,
    String? fileName,
    String? fileSize,
    String? fileType,
    DateTime? scannedAt,
    int? riskScore,
    List<PrivacyFinding>? findings,
    bool? isExported,
    String? stagedFilePath,
    String? exportedFilePath,
  }) {
    return ScanSession(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      fileType: fileType ?? this.fileType,
      scannedAt: scannedAt ?? this.scannedAt,
      riskScore: riskScore ?? this.riskScore,
      findings: findings ?? this.findings,
      isExported: isExported ?? this.isExported,
      stagedFilePath: stagedFilePath ?? this.stagedFilePath,
      exportedFilePath: exportedFilePath ?? this.exportedFilePath,
    );
  }

  int get criticalCount =>
      findings.where((f) => f.level == RiskLevel.critical).length;
  int get highCount => findings.where((f) => f.level == RiskLevel.high).length;
  int get mediumCount =>
      findings.where((f) => f.level == RiskLevel.medium).length;
  int get lowCount => findings.where((f) => f.level == RiskLevel.low).length;
}

class SelectedFile {
  const SelectedFile({
    required this.name,
    required this.size,
    required this.type,
    this.sizeBytes,
    this.localPath,
  });

  final String name;
  final String size;
  final String type;
  final int? sizeBytes;
  /// Staged file path under ZeroTrace/scans/.
  final String? localPath;
}

class ExportConfig {
  const ExportConfig({
    this.stripMetadata = true,
    this.blurSensitiveAreas = true,
    this.scrubPersonalInfo = true,
  });

  final bool stripMetadata;
  final bool blurSensitiveAreas;
  final bool scrubPersonalInfo;

  ExportConfig copyWith({
    bool? stripMetadata,
    bool? blurSensitiveAreas,
    bool? scrubPersonalInfo,
  }) {
    return ExportConfig(
      stripMetadata: stripMetadata ?? this.stripMetadata,
      blurSensitiveAreas: blurSensitiveAreas ?? this.blurSensitiveAreas,
      scrubPersonalInfo: scrubPersonalInfo ?? this.scrubPersonalInfo,
    );
  }
}

/// Options for the privacy scan pass (separate from export).
class ScanConfig {
  const ScanConfig({this.deepAiScan = false});

  final bool deepAiScan;

  ScanConfig copyWith({bool? deepAiScan}) {
    return ScanConfig(deepAiScan: deepAiScan ?? this.deepAiScan);
  }
}

class WorkflowState {
  const WorkflowState({
    this.selectedFile,
    this.session,
    this.findings = const [],
    this.exportedFileName,
    this.exportedFilePath,
    this.previewAfterPath,
    this.exportConfig = const ExportConfig(),
    this.scanConfig = const ScanConfig(),
  });

  final SelectedFile? selectedFile;
  final ScanSession? session;
  final List<PrivacyFinding> findings;
  final String? exportedFileName;
  final String? exportedFilePath;
  /// Local path to generated cleaned preview under ZeroTrace/cache/previews/.
  final String? previewAfterPath;
  final ExportConfig exportConfig;
  final ScanConfig scanConfig;

  bool get hasSession => session != null;
  int get appliedFixCount => findings.where((f) => f.isFixed).length;
  int get risksFoundCount => findings.length;
  bool get hasManualFixSelection => appliedFixCount > 0;

  static bool isMetadataFinding(PrivacyFinding finding) =>
      finding.category.toLowerCase().contains('metadata');

  /// Findings still open after the user's fix toggles (+ metadata strip option).
  List<PrivacyFinding> unresolvedFindingsAtExport() {
    return findings.where((f) {
      if (f.isFixed) return false;
      if (exportConfig.stripMetadata && isMetadataFinding(f)) return false;
      return true;
    }).toList();
  }

  /// Findings passed to the export engine — respects each toggle exactly.
  List<PrivacyFinding> findingsPreparedForExport() => findings;

  int get projectedRiskScore {
    if (session == null) return 0;
    return _scorePrivacyFindings(unresolvedFindingsAtExport());
  }

  bool get canExportSafeCopy {
    if (session == null || selectedFile?.localPath == null) return false;
    if (projectedRiskScore < session!.riskScore) return true;
    if (hasManualFixSelection) return appliedFixCount > 0;
    final hasBlur = findings.any((f) => f.supportsBlur);
    final hasMetadata = findings.any(isMetadataFinding);
    return (exportConfig.blurSensitiveAreas && hasBlur) ||
        (exportConfig.stripMetadata && hasMetadata);
  }

  /// Prior export still on disk — save again without re-running the engine.
  bool get canSaveExistingExport =>
      exportedFilePath != null && exportedFilePath!.isNotEmpty;

  String? get existingExportFileName {
    if (exportedFileName != null && exportedFileName!.isNotEmpty) {
      return exportedFileName;
    }
    if (session == null) return null;
    final base = session!.fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    final ext = RegExp(r'(\.[^.]+)$').firstMatch(session!.fileName)?.group(1) ?? '';
    return '${base}_sanitized$ext';
  }

  int get scoreImprovePercent {
    if (session == null || session!.riskScore == 0) return 0;
    final improved = session!.riskScore - projectedRiskScore;
    return ((improved / session!.riskScore) * 100).round();
  }

  static int _scorePrivacyFindings(List<PrivacyFinding> items) {
    if (items.isEmpty) return 0;
    var total = 0.0;
    for (final f in items) {
      total += switch (f.level) {
        RiskLevel.critical => 28.0,
        RiskLevel.high => 18.0,
        RiskLevel.medium => 10.0,
        RiskLevel.low => 4.0,
        RiskLevel.none => 0.0,
      } *
          0.85;
    }
    return total.clamp(0, 100).round();
  }

  WorkflowState copyWith({
    SelectedFile? selectedFile,
    bool clearFile = false,
    ScanSession? session,
    bool clearSession = false,
    List<PrivacyFinding>? findings,
    String? exportedFileName,
    String? exportedFilePath,
    bool clearExport = false,
    String? previewAfterPath,
    bool clearPreview = false,
    ExportConfig? exportConfig,
    ScanConfig? scanConfig,
  }) {
    return WorkflowState(
      selectedFile: clearFile ? null : (selectedFile ?? this.selectedFile),
      session: clearSession ? null : (session ?? this.session),
      findings: findings ?? this.findings,
      exportedFileName:
          clearExport ? null : (exportedFileName ?? this.exportedFileName),
      exportedFilePath:
          clearExport ? null : (exportedFilePath ?? this.exportedFilePath),
      previewAfterPath:
          clearPreview ? null : (previewAfterPath ?? this.previewAfterPath),
      exportConfig: exportConfig ?? this.exportConfig,
      scanConfig: scanConfig ?? this.scanConfig,
    );
  }
}
