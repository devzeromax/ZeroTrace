import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_io/io.dart';

import '../data/demo_data.dart';
import '../infrastructure/storage/history_file_recovery.dart';
import '../infrastructure/storage/history_store.dart';
import '../infrastructure/storage/zerotrace_paths.dart';
import '../models/app_models.dart';
import 'engine_providers.dart';
final workflowProvider =
    NotifierProvider<WorkflowNotifier, WorkflowState>(WorkflowNotifier.new);

final historyProvider =
    NotifierProvider<HistoryNotifier, List<ScanSession>>(HistoryNotifier.new);

/// True until the first disk read for [historyProvider] finishes.
final historyHydratingProvider = StateProvider<bool>((ref) => true);

class WorkflowNotifier extends Notifier<WorkflowState> {
  @override
  WorkflowState build() => const WorkflowState();

  void selectFile(SelectedFile? file) {
    state = state.copyWith(
      selectedFile: file,
      clearSession: true,
      findings: const [],
      clearExport: true,
      clearPreview: true,
    );
  }

  /// Completes scan from the real pipeline result.
  void completeScanFromPipeline(ScanPipelineResult result) {
    final file = state.selectedFile;
    if (file == null) return;

    final session = result.toScanSession();
    // Production default: auto-enable blur for every spatial detection (faces, plates, etc.)
    final findings = session.findings
        .map((f) => f.supportsBlur ? f.copyWith(isFixed: true) : f)
        .toList();
    final sessionWithFixes = session.copyWith(
      findings: findings,
      stagedFilePath: file.localPath,
    );

    state = WorkflowState(
      selectedFile: file,
      session: sessionWithFixes,
      findings: findings,
      exportConfig: state.exportConfig.copyWith(blurSensitiveAreas: true),
    );
    ref.read(historyProvider.notifier).upsert(sessionWithFixes);
    Future.microtask(refreshLivePreview);
  }

  /// Completes scan with zero findings when pipeline fails or staging is missing.
  void completeScanEmpty() {
    final file = state.selectedFile;
    if (file == null) return;

    final session = ScanSession(
      id: 'scan-${DateTime.now().millisecondsSinceEpoch}',
      fileName: file.name,
      fileSize: file.size,
      fileType: file.type,
      scannedAt: DateTime.now(),
      riskScore: 0,
      findings: const [],
      stagedFilePath: file.localPath,
    );
    state = WorkflowState(
      selectedFile: file,
      session: session,
      findings: const [],
    );
    ref.read(historyProvider.notifier).upsert(session);
  }

  /// Demo fallback when no staged file is available.
  void completeScanDemo() {
    final file = state.selectedFile;
    if (file == null) return;

    final session = DemoData.buildSession(file).copyWith(
      stagedFilePath: file.localPath,
    );
    state = WorkflowState(
      selectedFile: file,
      session: session,
      findings: List<PrivacyFinding>.from(DemoData.sampleFindings),
    );
    ref.read(historyProvider.notifier).upsert(session);
  }

  void toggleFinding(String id, bool isFixed) {
    state = state.copyWith(
      findings: state.findings
          .map((f) => f.id == id ? f.copyWith(isFixed: isFixed) : f)
          .toList(),
    );
    Future.microtask(refreshLivePreview);
  }

  void applyAllFixes() {
    state = state.copyWith(
      findings:
          state.findings.map((f) => f.copyWith(isFixed: true)).toList(),
    );
    Future.microtask(refreshLivePreview);
  }

  /// Regenerates the cleaned preview from the staged upload.
  /// Uses the same isFixed toggles as export — never re-enables disabled blurs.
  Future<void> refreshLivePreview() async {
    final file = state.selectedFile;
    final localPath = file?.localPath;
    if (localPath == null) return;

    try {
      await ref.read(engineBootstrapProvider.future);
      final engine = ref.read(exportEngineProvider);
      final config = state.exportConfig.copyWith(
        blurSensitiveAreas: state.findings.any((f) => f.isFixed && f.supportsBlur),
      );
      final result = await engine.exportPreview(
        source: ScanInput(
          filePath: localPath,
          fileName: file!.name,
          mimeType: file.type,
          sizeBytes: file.sizeBytes ?? 0,
        ),
        config: config,
        findings: state.findings,
      );
      state = state.copyWith(previewAfterPath: result.outputPath);
    } catch (_) {
      state = state.copyWith(clearPreview: true);
    }
  }

  void updateExportConfig(ExportConfig config) {
    state = state.copyWith(exportConfig: config);
  }

  void toggleExportOption({
    bool? stripMetadata,
    bool? blurSensitiveAreas,
    bool? scrubPersonalInfo,
  }) {
    state = state.copyWith(
      exportConfig: state.exportConfig.copyWith(
        stripMetadata: stripMetadata,
        blurSensitiveAreas: blurSensitiveAreas,
        scrubPersonalInfo: scrubPersonalInfo,
      ),
    );
  }

  void toggleScanOption({bool? deepAiScan}) {
    state = state.copyWith(
      scanConfig: state.scanConfig.copyWith(deepAiScan: deepAiScan),
    );
  }

  Future<void> markExported(
    String sanitizedFileName, {
    String? outputPath,
  }) async {
    final session = state.session;
    if (session == null) return;

    final exported = session.copyWith(
      findings: state.findings,
      isExported: true,
      stagedFilePath: session.stagedFilePath ?? state.selectedFile?.localPath,
      exportedFilePath: outputPath ?? session.exportedFilePath,
    );

    state = state.copyWith(
      session: exported,
      exportedFileName: sanitizedFileName,
      exportedFilePath: outputPath,
    );
    await ref.read(historyProvider.notifier).upsert(exported);
  }

  /// Writes a sanitized copy to disk and updates workflow/history state.
  Future<String> exportSanitizedCopy() async {
    final file = state.selectedFile;
    final localPath = file?.localPath;
    if (localPath == null) {
      throw ExportException('Staged file is missing. Re-upload and scan again.');
    }

    await ref.read(engineBootstrapProvider.future);
    final engine = ref.read(exportEngineProvider);
    final result = await engine.export(
      source: ScanInput(
        filePath: localPath,
        fileName: file!.name,
        mimeType: file.type,
        sizeBytes: file.sizeBytes ?? 0,
      ),
      config: state.exportConfig,
      findings: state.findingsPreparedForExport(),
    );

    await markExported(result.outputFileName, outputPath: result.outputPath);
    return result.outputPath;
  }

  void reset() {
    state = const WorkflowState();
  }

  void loadFromHistory(ScanSession session) {
    var findings = List<PrivacyFinding>.from(session.findings);
    if (!findings.any((f) => f.isFixed)) {
      findings = findings.map((f) => f.copyWith(isFixed: true)).toList();
    }

    final layoutReady = ZeroTracePaths.isInitialized;
    final layout = layoutReady ? ref.read(zeroTraceLayoutProvider) : null;

    final stagedPath = layout != null
        ? HistoryFileRecovery.resolveStagedPath(
            layout,
            session.fileName,
            savedPath: session.stagedFilePath,
          )
        : _pathIfExists(session.stagedFilePath);
    final exportPath = layout != null
        ? HistoryFileRecovery.resolveExportPath(
            layout,
            session.fileName,
            savedPath: session.exportedFilePath,
          )
        : _pathIfExists(session.exportedFilePath);

    if (stagedPath != session.stagedFilePath ||
        exportPath != session.exportedFilePath) {
      session = session.copyWith(
        stagedFilePath: stagedPath,
        exportedFilePath: exportPath,
      );
      ref.read(historyProvider.notifier).upsert(session);
    }

    final exportName = exportPath != null
        ? File(exportPath).uri.pathSegments.last
        : session.isExported
            ? '${session.fileName.replaceAll(RegExp(r'\.[^.]+$'), '')}_sanitized'
            : null;

    state = WorkflowState(
      selectedFile: SelectedFile(
        name: session.fileName,
        size: session.fileSize,
        type: session.fileType,
        localPath: stagedPath,
      ),
      session: session,
      findings: findings,
      exportedFileName: exportName,
      exportedFilePath: exportPath,
      exportConfig: state.exportConfig.copyWith(blurSensitiveAreas: true),
    );

    if (stagedPath != null) {
      Future.microtask(refreshLivePreview);
    }
  }

  String? _pathIfExists(String? path) {
    if (path == null || path.isEmpty) return null;
    return File(path).existsSync() ? path : null;
  }
}

class HistoryNotifier extends Notifier<List<ScanSession>> {
  HistoryStore? _store;
  var _hydrated = false;

  @override
  List<ScanSession> build() {
    if (!_hydrated) {
      _hydrated = true;
      Future.microtask(_loadFromDisk);
    }
    return const [];
  }

  Future<void> _loadFromDisk() async {
    try {
      await ref.read(engineBootstrapProvider.future);
      _store = ref.read(historyStoreProvider);
      var sessions = await _store!.readAll();
      if (sessions.isEmpty && DemoData.isDemoMode) {
        sessions = List<ScanSession>.from(DemoData.recentSessions);
      }
      state = sessions;
    } catch (_) {
      state = [];
    } finally {
      ref.read(historyHydratingProvider.notifier).state = false;
    }
  }

  Future<void> upsert(ScanSession session) async {
    final next = [
      session,
      ...state.where((s) => s.id != session.id),
    ];
    state = next;
    await _store?.upsert(session);
  }

  Future<void> remove(String id) async {
    state = state.where((s) => s.id != id).toList();
    await _store?.remove(id);
  }

  Future<void> clear() async {
    state = [];
    await _store?.clear();
  }

  ScanSession? findById(String id) {
    for (final session in state) {
      if (session.id == id) return session;
    }
    return null;
  }
}
