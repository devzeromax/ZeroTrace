import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/animation/app_motion.dart';
import '../core/audio/app_sound_player.dart';
import '../core/constants/app_assets.dart';
import '../core/extensions/model_extensions.dart';
import '../core/routing/app_routes.dart';
import '../core/theme/design_tokens.dart';
import '../core/utils/download_export.dart';
import '../core/utils/export_risk_label.dart';
import '../core/utils/export_status_steps.dart';
import '../core/utils/user_facing_error.dart';
import '../providers/workflow_provider.dart';
import '../widgets/cleaning_toggle.dart';
import '../widgets/export_stat_card.dart';
import '../widgets/file_summary_card.dart';
import '../widgets/fluid_progress_bar.dart';
import '../widgets/primary_button.dart';
import '../widgets/secondary_button.dart';
import '../widgets/security_badge.dart';

/// iOS-style export sheet — options → processing → success without route pushes.
class ExportBottomSheet {
  ExportBottomSheet._();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      useRootNavigator: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => const _ExportSheet(),
    );
  }
}

enum _ExportPhase { options, processing, success }

class _ExportSheet extends ConsumerStatefulWidget {
  const _ExportSheet();

  @override
  ConsumerState<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<_ExportSheet> {
  _ExportPhase _phase = _ExportPhase.options;

  bool _running = false;
  String? _errorMessage;
  int _statusIndex = 0;
  Timer? _statusTimer;
  var _isSaving = false;
  List<String> _statusSteps = ExportStatusSteps.forSession(null);

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  void _goToProcessing() {
    setState(() {
      _phase = _ExportPhase.processing;
      _running = true;
      _errorMessage = null;
      _statusIndex = 0;
      _statusSteps =
          ExportStatusSteps.forSession(ref.read(workflowProvider).session);
    });
    // ponytail: let sheet settle before heavy export + animations compete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 280), () {
        if (mounted && _phase == _ExportPhase.processing) _startExport();
      });
    });
  }

  void _beginStatusUpdates() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(AppDurations.exportStatusStep, (_) {
      if (!mounted || _errorMessage != null) return;
      setState(() {
        _statusIndex = (_statusIndex + 1).clamp(0, _statusSteps.length - 1);
      });
    });
  }

  Future<void> _startExport() async {
    setState(() {
      _running = true;
      _errorMessage = null;
      _statusIndex = 0;
      _statusSteps =
          ExportStatusSteps.forSession(ref.read(workflowProvider).session);
    });
    _beginStatusUpdates();

    final startedAt = DateTime.now();
    try {
      await ref.read(workflowProvider.notifier).exportSanitizedCopy();

      final elapsed = DateTime.now().difference(startedAt);
      final remaining = AppDurations.exportProcessingMinimum - elapsed;
      if (remaining > Duration.zero) {
        await Future<void>.delayed(remaining);
      }

      if (!mounted) return;
      _statusTimer?.cancel();
      unawaited(AppSoundPlayer.playExportSuccess());
      setState(() {
        _running = false;
        _phase = _ExportPhase.success;
      });
    } catch (e) {
      if (!mounted) return;
      _statusTimer?.cancel();
      setState(() {
        _running = false;
        _errorMessage = UserFacingError.message(e);
      });
    }
  }

  Future<void> _downloadFile() async {
    final workflow = ref.read(workflowProvider);
    final fileName = workflow.exportedFileName ?? 'sanitized_file';
    final path = workflow.exportedFilePath;

    if (path == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Export file not found. Try exporting again.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final ok = await DownloadExport.saveToDevice(
      sourcePath: path,
      fileName: fileName,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) unawaited(AppSoundPlayer.playUiConfirm());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Saved $fileName to device' : 'Save to device cancelled',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final canDismiss = _phase == _ExportPhase.options && !_running;

    return PopScope(
      canPop: canDismiss,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: switch (_phase) {
              _ExportPhase.options => _OptionsPane(
                key: const ValueKey('options'),
                onExport: _goToProcessing,
                onCancel: () => Navigator.of(context).pop(),
              ),
              _ExportPhase.processing => _ProcessingPane(
                key: const ValueKey('processing'),
                running: _running,
                errorMessage: _errorMessage,
                statusIndex: _statusIndex,
                statusSteps: _statusSteps,
                onRetry: _startExport,
                onBack: () => setState(() {
                  _phase = _ExportPhase.options;
                  _errorMessage = null;
                }),
              ),
              _ExportPhase.success => _SuccessPane(
                key: const ValueKey('success'),
                isSaving: _isSaving,
                onSave: _downloadFile,
                onDone: () {
                  ref.read(workflowProvider.notifier).reset();
                  Navigator.of(context).pop();
                  context.go(AppRoutes.home);
                },
              ),
            },
          ),
        ),
      ),
    );
  }
}

class _OptionsPane extends ConsumerWidget {
  const _OptionsPane({
    super.key,
    required this.onExport,
    required this.onCancel,
  });

  final VoidCallback onExport;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workflow = ref.watch(workflowProvider);
    final notifier = ref.read(workflowProvider.notifier);
    final session = workflow.session;
    final config = workflow.exportConfig;
    final projected = workflow.projectedRiskScore;
    final finalRisk = riskLevelFromScore(projected);
    final canExport = workflow.canExportSafeCopy;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x5,
            AppSpacing.x2,
            AppSpacing.x5,
            AppSpacing.x4,
          ),
          child: Text(
            'Export safe copy',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ExportStatCard(
                        label: 'Risks found',
                        value: '${workflow.risksFoundCount}',
                        valueColor: AppColors.riskHigh,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x4),
                    Expanded(
                      child: ExportStatCard(
                        label: 'Risk reduced by',
                        value: workflow.scoreImprovePercent > 0
                            ? '${workflow.scoreImprovePercent}%'
                            : (projected <= 5 ? 'Already low' : '—'),
                        valueColor: AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x5),
                Text(
                  'Export options',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.x3),
                CleaningToggle(
                  active: config.stripMetadata,
                  icon: Icons.history_toggle_off_rounded,
                  label: 'Remove metadata',
                  subtitle: 'Strip EXIF, GPS, and device info on export',
                  onChanged: (v) =>
                      notifier.toggleExportOption(stripMetadata: v),
                ),
                const SizedBox(height: AppSpacing.x3),
                CleaningToggle(
                  active: config.blurSensitiveAreas,
                  icon: Icons.blur_on_rounded,
                  label: 'Blur sensitive areas',
                  subtitle:
                      'Pixelate faces, plates, and text regions you enabled',
                  onChanged: (v) =>
                      notifier.toggleExportOption(blurSensitiveAreas: v),
                ),
                const SizedBox(height: AppSpacing.x3),
                CleaningToggle(
                  active: config.scrubPersonalInfo,
                  icon: Icons.policy_outlined,
                  label: 'Smart redact (PII)',
                  subtitle:
                      'Pixelate OCR regions with emails, phones, cards, and IDs',
                  onChanged: (v) =>
                      notifier.toggleExportOption(scrubPersonalInfo: v),
                ),
                const SizedBox(height: AppSpacing.x5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'File to export',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.push(AppRoutes.fix);
                      },
                      child: const Text('Edit fixes'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x3),
                if (session != null)
                  FileSummaryCard(
                    fileName: session.fileName,
                    size: session.fileSize,
                    status: 'READY',
                    statusColor: AppColors.statusNeutral,
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.x4),
                    child: Text(
                      'No file ready to export',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                const SizedBox(height: AppSpacing.x5),
                _RiskFooter(
                  riskLabel: exportRiskLabel(finalRisk),
                  riskColor: finalRisk.color,
                  totalSize: session?.fileSize ?? '—',
                ),
                const SizedBox(height: AppSpacing.x4),
                PrimaryButton(
                  label: 'Export safe copy',
                  icon: Icons.verified_user_outlined,
                  onPressed: canExport ? onExport : null,
                ),
                const SizedBox(height: AppSpacing.x2),
                Center(
                  child: TextButton(
                    onPressed: onCancel,
                    child: Text(
                      'Cancel',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.x2),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RiskFooter extends StatelessWidget {
  const _RiskFooter({
    required this.riskLabel,
    required this.riskColor,
    required this.totalSize,
  });

  final String riskLabel;
  final Color riskColor;
  final String totalSize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Risk after export',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: AppSpacing.x1),
            Row(
              children: [
                Icon(Icons.security_rounded, size: 16, color: riskColor),
                const SizedBox(width: AppSpacing.x1),
                Text(
                  riskLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: riskColor,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('File size', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: AppSpacing.x1),
            Text(
              totalSize,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProcessingPane extends StatelessWidget {
  const _ProcessingPane({
    super.key,
    required this.running,
    required this.errorMessage,
    required this.statusIndex,
    required this.statusSteps,
    required this.onRetry,
    required this.onBack,
  });

  final bool running;
  final String? errorMessage;
  final int statusIndex;
  final List<String> statusSteps;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x5,
        AppSpacing.x2,
        AppSpacing.x5,
        AppSpacing.x5,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Exporting…',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.x5),
          SizedBox(
            height: 140,
            child: Image.asset(
              AppAssets.processingPalm,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.verified_user_outlined,
                size: 72,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x4),
          if (errorMessage == null) ...[
            FluidProgressBar(
              progress: (statusIndex + 1) / statusSteps.length,
              color: colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.x3),
            Semantics(
              liveRegion: true,
              label: statusSteps[statusIndex],
              child: TextFlipReveal(
                text: statusSteps[statusIndex],
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(
              running ? 'Processing on your device' : 'Finishing up…',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ] else ...[
            Semantics(
              liveRegion: true,
              label: errorMessage!,
              child: Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
            PrimaryButton(label: 'Retry', onPressed: onRetry),
            const SizedBox(height: AppSpacing.x2),
            SecondaryButton(label: 'Back to options', onPressed: onBack),
          ],
        ],
      ),
    );
  }
}

class _SuccessPane extends ConsumerWidget {
  const _SuccessPane({
    super.key,
    required this.isSaving,
    required this.onSave,
    required this.onDone,
  });

  final bool isSaving;
  final VoidCallback onSave;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workflow = ref.watch(workflowProvider);
    final fileName = workflow.exportedFileName ?? 'sanitized_file';
    final fixCount = workflow.appliedFixCount;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x5,
        AppSpacing.x2,
        AppSpacing.x5,
        AppSpacing.x5,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSuccessCheck(color: colorScheme.secondary),
          const SizedBox(height: AppSpacing.x5),
          Text(
            'Export complete',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          Text(
            '$fileName is ready in app storage. '
            'Save to device picks a folder for your copy.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.x4),
          Wrap(
            spacing: AppSpacing.x2,
            runSpacing: AppSpacing.x2,
            alignment: WrapAlignment.center,
            children: [
              SecurityBadge(
                label: '$fixCount fixes applied',
                icon: Icons.auto_fix_high_outlined,
                variant: SecurityBadgeVariant.neutral,
              ),
              const SecurityBadge(
                label: 'Manifest saved',
                icon: Icons.description_outlined,
                variant: SecurityBadgeVariant.neutral,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x5),
          PrimaryButton(
            label: isSaving ? 'Saving…' : 'Save to device',
            icon: Icons.download_rounded,
            isLoading: isSaving,
            onPressed: isSaving ? null : onSave,
          ),
          const SizedBox(height: AppSpacing.x3),
          SecondaryButton(label: 'Done', onPressed: onDone),
        ],
      ),
    );
  }
}
