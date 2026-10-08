import 'package:flutter/material.dart';

import '../core/theme/design_tokens.dart';
import '../core/theme/glass_scene.dart';
import '../core/utils/user_facing_error.dart';
import 'glass_surface.dart';

/// Inline error panel with plain language and optional recovery hint.
class UserErrorBanner extends StatelessWidget {
  const UserErrorBanner({
    super.key,
    required this.error,
    this.scene = GlassScene.settings,
    this.onDismiss,
  });

  final Object error;
  final GlassScene scene;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final message = UserFacingError.message(error);
    final hint = UserFacingError.recoveryHint(error);

    return GlassSurface(
      scene: scene,
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: colorScheme.error, size: 22),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.error,
                      ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: AppSpacing.x2),
                  Text(
                    hint,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            ),
          ),
          if (onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: 'Dismiss',
              onPressed: onDismiss,
            ),
        ],
      ),
    );
  }
}
