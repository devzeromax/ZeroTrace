import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_routes.dart';
import '../../core/routing/workflow_navigation.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/user_facing_error.dart';
import '../../models/app_models.dart';
import '../../providers/engine_providers.dart';
import '../../providers/neural_pack_status_provider.dart';
import '../../providers/workflow_provider.dart';
import '../../widgets/neural_pack_status_banner.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/scan_progress_panel.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/workflow_page.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  double _progress = 0;
  int _elapsedSeconds = 0;
  Timer? _elapsedTimer;
  DateTime? _startedAt;
  bool _cancelled = false;
  String? _errorMessage;
  StreamSubscription<ScanProgressEvent>? _scanSub;
  String _scannerSubtitle = 'Built-in scanners';
  final _stages = <ScanStage, ScanStageStatus>{
    ScanStage.metadata: ScanStageStatus.pending,
    ScanStage.faces: ScanStageStatus.pending,
    ScanStage.qrCodes: ScanStageStatus.pending,
    ScanStage.licensePlates: ScanStageStatus.pending,
    ScanStage.documents: ScanStageStatus.pending,
    ScanStage.report: ScanStageStatus.pending,
  };

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScan());
  }

  Future<void> _startScan() async {
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _cancelled) return;
      setState(() {
        _elapsedSeconds = DateTime.now().difference(_startedAt!).inSeconds;
      });
    });

    final file = ref.read(workflowProvider).selectedFile;
    if (file?.localPath == null) {
      _failScan('No file is ready to scan. Add a file and try again.');
      return;
    }

    await ref.read(engineBootstrapProvider.future);
    final discovery = ref.read(pluginDiscoveryProvider);
    final allPlugins = await discovery.discoverAll();
    final operational = allPlugins.where((p) => p.isOperational).toList();
    _markSkippedStages(operational);

    final caps = ref.read(engineCapabilitiesProvider);
    final neuralCount =
        operational.where((p) => p.scanStage == ScanStage.faces).length;
    final deepScan = ref.read(workflowProvider).scanConfig.deepAiScan;
    setState(() {
      _scannerSubtitle = caps.onnxRuntimeAvailable && neuralCount > 0
          ? (deepScan
              ? 'Deep scan — full OCR and PII review'
              : 'Built-in + optional scanner packs')
          : 'Built-in scanners (metadata, QR, secrets)';
    });

    final pipeline = ref.read(scanPipelineProvider);
    final input = ScanInput(
      filePath: file!.localPath!,
      fileName: file.name,
      mimeType: file.type,
      sizeBytes: file.sizeBytes ?? 0,
      deepAiScan: deepScan,
    );

    _scanSub = pipeline.run(input).listen(
      (event) {
        if (!mounted || _cancelled) return;
        setState(() {
          _progress = event.progress.clamp(0.0, 1.0);
          _applyStage(event.stage, event.progress);
        });
      },
      onDone: () {
        if (_cancelled) return;
        final result = pipeline.lastResult;
        if (result != null) {
          ref.read(workflowProvider.notifier).completeScanFromPipeline(result);
          _finishNavigation();
        } else {
          _failScan('The scan did not finish. Check the file and try again.');
        }
      },
      onError: (error) {
        if (_cancelled) return;
        _failScan(UserFacingError.message(error));
      },
    );
  }

  void _failScan(String message) {
    _elapsedTimer?.cancel();
    if (!mounted) return;
    setState(() => _errorMessage = message);
  }

  void _markSkippedStages(List<ScanPlugin> operational) {
    final neuralStages = {
      ScanStage.faces,
      ScanStage.licensePlates,
      ScanStage.documents,
    };
    for (final stage in neuralStages) {
      final hasScanner =
          operational.any((plugin) => plugin.scanStage == stage);
      if (!hasScanner) {
        _stages[stage] = ScanStageStatus.skipped;
      }
    }
  }

  void _applyStage(ScanStage stage, double progress) {
    final stageList = ScanStage.values;
    final activeIndex = stageList.indexOf(stage);
    for (var i = 0; i < stageList.length; i++) {
      final current = stageList[i];
      if (_stages[current] == ScanStageStatus.skipped) continue;

      if (i < activeIndex) {
        _stages[current] = ScanStageStatus.complete;
      } else if (i == activeIndex) {
        _stages[current] = ScanStageStatus.active;
      } else if (progress >= 1.0) {
        _stages[current] = ScanStageStatus.complete;
      } else {
        _stages[current] = ScanStageStatus.pending;
      }
    }
    if (progress >= 1.0) {
      for (final s in stageList) {
        if (_stages[s] != ScanStageStatus.skipped) {
          _stages[s] = ScanStageStatus.complete;
        }
      }
    }
  }

  void _finishNavigation() {
    _elapsedTimer?.cancel();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted && !_cancelled) {
        context.pushReplacement(AppRoutes.audit);
      }
    });
  }

  void _cancel() {
    _cancelled = true;
    _scanSub?.cancel();
    _elapsedTimer?.cancel();
    WorkflowNavigation.cancelScan(context, ref);
  }

  @override
  void dispose() {
    _cancelled = true;
    _scanSub?.cancel();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fileName =
        ref.watch(workflowProvider).selectedFile?.name ?? 'Unknown file';
    final neuralIssues = ref.watch(inactiveNeuralPackDiagnosticsProvider);

    return WorkflowPage(
      title: 'Scanning',
      currentStep: WorkflowStep.scan,
      centerBody: _errorMessage != null,
      body: _errorMessage != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: AppSpacing.x4),
                Text(
                  'Scan interrupted',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  _errorMessage!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.x6),
                PrimaryButton(
                  label: 'Back to add file',
                  icon: Icons.upload_file_outlined,
                  onPressed: () => context.go(AppRoutes.upload),
                ),
              ],
            )
          : ListView(
        children: [
          Text(
            'Scan status',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
          ),
          const SizedBox(height: AppSpacing.x2),
          neuralIssues.when(
            data: (issues) => InactiveNeuralPackBannerList(
              diagnostics: issues,
              compact: true,
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          ScanProgressPanel(
            fileName: fileName,
            progress: _progress,
            stages: _stages,
            elapsedSeconds: _elapsedSeconds,
            scannerSubtitle: _scannerSubtitle,
          ),
        ],
      ),
      bottomBar: _errorMessage != null
          ? null
          : WorkflowBottomBar(
        child: SecondaryButton(
          label: 'Cancel scan',
          onPressed: _cancel,
        ),
      ),
    );
  }
}
