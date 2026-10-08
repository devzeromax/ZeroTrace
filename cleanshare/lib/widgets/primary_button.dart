import 'package:flutter/material.dart';

import '../core/animation/app_motion.dart';
import '../core/theme/design_tokens.dart';
import '../core/theme/theme_surfaces.dart';

/// Primary CTA — ghost pill: transparent fill, themed border, 20px radius.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final colorScheme = Theme.of(context).colorScheme;
    final background = enabled
        ? ThemeSurfaces.accent(context)
        : ThemeSurfaces.cardElevated(context);
    final foreground = enabled
        ? colorScheme.onSecondary
        : ThemeSurfaces.onSurfaceMuted(context);
    final opacity = enabled ? 1.0 : 0.62;

    return Semantics(
      button: true,
      enabled: enabled,
      label: isLoading ? '$label, loading' : label,
      child: PressableScale(
        onPressed: isLoading ? null : onPressed,
        child: Opacity(
          opacity: opacity,
          child: SizedBox(
            height: AppSpacing.x12,
            width: expand ? double.infinity : null,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                boxShadow: enabled
                    ? [
                        BoxShadow(
                          color: background.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x6,
                  vertical: AppSpacing.x3,
                ),
                child: Center(
                  child: isLoading
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: foreground,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.x2),
                            Text(
                              label,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(color: foreground),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (icon != null) ...[
                              Icon(icon, size: 18, color: foreground),
                              const SizedBox(width: AppSpacing.x2),
                            ],
                            Text(
                              label,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(color: foreground),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
