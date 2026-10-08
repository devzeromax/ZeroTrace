import 'package:flutter/material.dart';

import '../core/theme/design_tokens.dart';
import '../core/theme/glass_scene.dart';
import '../models/app_models.dart';
import 'glass_surface.dart';
import 'risk_level_label.dart';

/// Compact privacy finding row — glass, neutral severity.
class AuditItem extends StatelessWidget {
  const AuditItem({
    super.key,
    required this.finding,
  });

  final PrivacyFinding finding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GlassSurface(
      scene: GlassScene.audit,
      intensity: 0.4,
      borderRadius: AppRadius.lg,
      margin: const EdgeInsets.only(bottom: AppSpacing.x2),
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
            ],
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            finding.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.x1),
          Text(
            finding.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
