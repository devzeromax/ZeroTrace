import 'package:flutter/material.dart';

import '../core/theme/design_tokens.dart';
import '../core/theme/glass_scene.dart';
import 'glass_surface.dart';

class TrustBanner extends StatelessWidget {
  const TrustBanner({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label:
          'Processed locally on this device. Your files never leave this phone.',
      child: GlassSurface(
        scene: GlassScene.workflow,
        borderRadius: AppRadius.sm,
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.cardPadding,
          vertical: compact ? AppSpacing.x2 : AppSpacing.x3,
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Text(
                compact
                    ? 'Processed locally on this device'
                    : 'Processed locally on this device. Your files never leave this phone.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
              ),
            ),
            if (!compact)
              Icon(
                Icons.shield_outlined,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}
