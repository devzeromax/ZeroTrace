import 'package:flutter/material.dart';

import '../core/extensions/model_extensions.dart';
import '../core/theme/design_tokens.dart';
import '../core/theme/theme_surfaces.dart';
import '../models/app_models.dart';
import '../core/theme/glass_scene.dart';
import 'glass_surface.dart';

class ScanProgressPanel extends StatelessWidget {
  const ScanProgressPanel({
    super.key,
    required this.fileName,
    required this.progress,
    required this.stages,
    this.elapsedSeconds = 0,
    this.scannerSubtitle = 'Built-in scanners',
  });

  final String fileName;
  final double progress;
  final Map<ScanStage, ScanStageStatus> stages;
  final int elapsedSeconds;
  final String scannerSubtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    ScanStage? activeStage;
    for (final stage in ScanStage.values) {
      if (stages[stage] == ScanStageStatus.active) {
        activeStage = stage;
        break;
      }
    }

    final percent = (progress * 100).round();
    final liveLabel = activeStage != null
        ? 'Scanning $fileName, $percent percent. ${activeStage.progressMessage}'
        : 'Scanning $fileName, $percent percent.';

    return GlassSurface(
      scene: GlassScene.workflow,
      padding: const EdgeInsets.all(AppSpacing.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scanning in progress',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 0.3,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppSpacing.x1),
          Text(
            fileName,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: AppSpacing.x4),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: colorScheme.surfaceContainerHighest,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
          Semantics(
            liveRegion: true,
            label: liveLabel,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (activeStage != null) ...[
                  Text(
                    activeStage.progressMessage,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.x2),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$percent%',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                    ),
                    Text(
                      '${elapsedSeconds}s · $scannerSubtitle',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x6),
          ...ScanStage.values.map((stage) {
            final status = stages[stage] ?? ScanStageStatus.pending;
            return _StageRow(stage: stage, status: status);
          }),
        ],
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({required this.stage, required this.status});

  final ScanStage stage;
  final ScanStageStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = ThemeSurfaces.accent(context);

    final (icon, iconColor) = switch (status) {
      ScanStageStatus.complete => (Icons.check_circle, accent),
      ScanStageStatus.active => (Icons.radio_button_checked, accent),
      ScanStageStatus.failed => (Icons.error_outline, colorScheme.error),
      ScanStageStatus.skipped => (
          Icons.remove_circle_outline,
          colorScheme.onSurfaceVariant,
        ),
      ScanStageStatus.pending => (
          Icons.circle_outlined,
          colorScheme.onSurfaceVariant,
        ),
    };

    final labelColor = switch (status) {
      ScanStageStatus.pending => colorScheme.onSurfaceVariant,
      ScanStageStatus.skipped => colorScheme.onSurfaceVariant,
      ScanStageStatus.failed => colorScheme.error,
      _ => colorScheme.onSurface,
    };

    final label = status == ScanStageStatus.skipped
        ? '${stage.stageLabel} (skipped — pack not ready)'
        : stage.stageLabel;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: labelColor,
                    fontWeight: status == ScanStageStatus.active
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
