import 'package:flutter/material.dart';

import '../core/theme/design_tokens.dart';
import '../core/theme/theme_surfaces.dart';
import '../core/theme/glass_scene.dart';
import 'glass_surface.dart';

class CleaningToggle extends StatelessWidget {
  const CleaningToggle({
    super.key,
    required this.active,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onChanged,
  });

  final bool active;
  final IconData icon;
  final String label;
  final String subtitle;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassSurface(
      scene: GlassScene.export,
      tint: active ? ThemeSurfaces.cardElevated(context) : null,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPadding,
        vertical: AppSpacing.x3,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: active
                  ? colorScheme.primary.withValues(alpha: 0.12)
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              icon,
              size: 20,
              color: active
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.x1),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Semantics(
            label: '$label. $subtitle',
            child: Switch.adaptive(
              value: active,
              onChanged: onChanged,
              activeTrackColor: colorScheme.primary.withValues(alpha: 0.35),
              activeThumbColor: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
