import 'package:flutter/material.dart';

import '../core/extensions/model_extensions.dart';
import '../core/theme/design_tokens.dart';
import '../core/theme/glass_scene.dart';
import '../models/app_models.dart';
import 'glass_blob_backdrop.dart';
import 'glass_surface.dart';
import 'risk_level_label.dart';

/// Frosted finding card — neutral severity, dark glass, no accent bars.
class FindingRow extends StatelessWidget {
  const FindingRow({
    super.key,
    required this.finding,
    this.onToggleFix,
    this.showFixToggle = false,
  });

  final PrivacyFinding finding;
  final ValueChanged<bool>? onToggleFix;
  final bool showFixToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isPending = showFixToggle && !finding.isFixed;

    return Semantics(
      label: '${finding.level.riskLabel} risk: ${finding.title}. '
          '${finding.description}'
          '${finding.isFixed ? '. Fixed' : isPending ? '. Pending fix' : ''}',
      child: GlassBlobBackdrop(
        borderRadius: AppRadius.lg,
        accent: finding.level.color,
        scene: GlassScene.audit,
        intensity: 0.85,
        child: GlassSurface(
          scene: GlassScene.audit,
          intensity: 0.12,
          blurSigma: 22,
          borderRadius: AppRadius.lg,
          margin: const EdgeInsets.only(bottom: AppSpacing.x3),
          padding: EdgeInsets.zero,
          child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -24,
              right: -16,
              child: IgnorePointer(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        colorScheme.primary.withValues(alpha: 0.07),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.x4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      RiskLevelLabel(level: finding.level, compact: true),
                      const SizedBox(width: AppSpacing.x3),
                      Expanded(
                        child: Text(
                          finding.category,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (finding.isFixed)
                        _StatusChip(
                          label: finding.supportsBlur ? 'Blur on' : 'Reviewed',
                        )
                      else if (isPending)
                        const _StatusChip(label: 'Pending'),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.x3),
                  Text(
                    finding.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (finding.piiLabel != null) ...[
                    const SizedBox(height: AppSpacing.x2),
                    _StatusChip(label: finding.piiLabel!),
                  ],
                  const SizedBox(height: AppSpacing.x2),
                  Text(
                    finding.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  if (finding.recommendedAction != null) ...[
                    const SizedBox(height: AppSpacing.x3),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.x3,
                        vertical: AppSpacing.x3,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.onSurface.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: AppSpacing.x2),
                          Expanded(
                            child: Text(
                              finding.recommendedAction!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.88,
                                ),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (showFixToggle && onToggleFix != null) ...[
                    const SizedBox(height: AppSpacing.x2),
                    Divider(
                      height: 1,
                      color: colorScheme.outline.withValues(alpha: 0.15),
                    ),
                    Material(
                      type: MaterialType.transparency,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          finding.supportsBlur
                              ? 'Blur on export'
                              : 'Mark as reviewed',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          finding.supportsBlur
                              ? (finding.isFixed
                                  ? 'This region will be pixelated in the cleaned copy'
                                  : 'Off — preview and export keep this region visible')
                              : (finding.isFixed
                                  ? 'Marked reviewed (cannot pixelate PDF/text in-app)'
                                  : 'Still open — redact externally if needed'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        value: finding.isFixed,
                        onChanged: onToggleFix,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x2,
        vertical: AppSpacing.x1,
      ),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
      ),
    );
  }
}

class PrivacyRiskCard extends StatelessWidget {
  const PrivacyRiskCard({
    super.key,
    required this.category,
    required this.count,
    required this.highestLevel,
    this.expanded = false,
    required this.onTap,
  });

  final String category;
  final int count;
  final RiskLevel highestLevel;
  final bool expanded;
  final VoidCallback onTap;

  Color _categoryAccent(String category, RiskLevel level) {
    return switch (category.toLowerCase()) {
      'metadata' => CosmosColors.concentricTeal,
      'documents' => AppColors.riskMedium,
      'faces' => AppColors.riskHigh,
      'license plates' => const Color(0xFFE8A838),
      _ => level.color,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = _categoryAccent(category, highestLevel);

    return Semantics(
      button: true,
      label: '$category. $count finding${count == 1 ? '' : 's'}. '
          '${highestLevel.riskLabel} risk. Tap to expand.',
      child: GlassBlobBackdrop(
        borderRadius: AppRadius.lg,
        accent: accent,
        scene: GlassScene.audit,
        intensity: 1.05,
        child: GlassSurface(
          scene: GlassScene.audit,
          intensity: 0.14,
          blurSigma: 24,
          borderRadius: AppRadius.lg,
          margin: const EdgeInsets.only(bottom: AppSpacing.x2),
          padding: EdgeInsets.zero,
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.12),
                  Colors.transparent,
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.x4),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          accent.withValues(alpha: 0.35),
                          accent.withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                    child: Icon(
                      _categoryIcon(category),
                      size: 18,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.x1),
                        Text(
                          '$count finding${count == 1 ? '' : 's'}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  RiskLevelLabel(level: highestLevel, compact: true),
                  const SizedBox(width: AppSpacing.x2),
                  AnimatedRotation(
                    turns: expanded ? 0.25 : 0,
                    duration: AppDurations.normal,
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.chevron_right,
                      color: colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    return switch (category.toLowerCase()) {
      'metadata' => Icons.photo_library_outlined,
      'documents' => Icons.description_outlined,
      'faces' => Icons.face_retouching_natural_outlined,
      'license plates' => Icons.directions_car_outlined,
      _ => Icons.shield_outlined,
    };
  }
}
