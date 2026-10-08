import 'package:flutter/material.dart';

import '../core/theme/design_tokens.dart';
import '../core/theme/glass_scene.dart';
import '../core/theme/glass_tokens.dart';
import '../core/animation/app_motion.dart';

/// Frosted glass panel — iOS-style blur, translucent fill, hairline border.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = AppRadius.hero,
    this.onTap,
    this.tint,
    this.focused = false,
    this.intensity,
    this.blurSigma,
    this.scene,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final VoidCallback? onTap;
  final Color? tint;
  final bool focused;
  final double? intensity;
  final double? blurSigma;
  final GlassScene? scene;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final useGlass = GlassTokens.useGlass(context);
    final sigma = GlassTokens.blurSigma(
      context,
      override: blurSigma,
      scene: scene,
    );
    final fill = tint ??
        GlassTokens.fill(context, intensity: intensity, scene: scene);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = focused
        ? Theme.of(context).colorScheme.secondary
        : Colors.transparent;

    Widget inner = Padding(
      padding: padding ?? EdgeInsets.zero,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: colorScheme.onSurface),
        child: child,
      ),
    );

    Widget panel = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.06),
            blurRadius: isDark ? 24 : 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: focused
            ? Border.all(color: borderColor, width: 1.5)
            : null,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: useGlass && sigma > 0
            ? Stack(
                children: [
                  BackdropFilter(
                    filter: GlassTokens.blurFilter(context, sigma: sigma),
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: fill),
                      child: inner,
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 72,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(
                                alpha: GlassTokens.isDark(context) ? 0.10 : 0.22,
                              ),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : DecoratedBox(
                decoration: BoxDecoration(
                  color: tint ??
                      colorScheme.surfaceContainerHighest.withValues(
                        alpha: isDark ? 0.55 : 0.85,
                      ),
                ),
                child: inner,
              ),
      ),
    );

    if (margin != null) {
      panel = Padding(padding: margin!, child: panel);
    }

    if (onTap != null) {
      panel = Semantics(
        button: true,
        child: SoftPress(onPressed: onTap, child: panel),
      );
    }

    return panel;
  }
}
