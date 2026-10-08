import 'package:flutter/material.dart';

import '../core/theme/design_tokens.dart';
import '../models/app_models.dart';
import '../core/extensions/model_extensions.dart';

class SecurityBadge extends StatelessWidget {
  const SecurityBadge({
    super.key,
    required this.label,
    this.icon = Icons.verified_outlined,
    this.variant = SecurityBadgeVariant.neutral,
  });

  final String label;
  final IconData icon;
  final SecurityBadgeVariant variant;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (variant) {
      SecurityBadgeVariant.success => (
          AppColors.successSubtle,
          AppColors.success,
        ),
      SecurityBadgeVariant.accent => (
          AppColors.accentSubtle,
          colorScheme.primary,
        ),
      SecurityBadgeVariant.neutral => (
          colorScheme.surfaceContainerHighest,
          colorScheme.onSurfaceVariant,
        ),
    };

    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x2,
          vertical: AppSpacing.x1,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: AppSpacing.x1),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

enum SecurityBadgeVariant { success, accent, neutral }

class RiskBadge extends StatelessWidget {
  const RiskBadge({super.key, required this.level});

  final RiskLevel level;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${level.riskLabel} risk',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x2,
          vertical: AppSpacing.x1,
        ),
        decoration: BoxDecoration(
          color: level.subtleBackground(context),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(
          level.riskLabel,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: level.color,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}
