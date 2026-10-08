import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme/design_tokens.dart';
import '../core/theme/glass_scene.dart';
import '../core/theme/glass_tokens.dart';

/// Dive Wallet–style gradient hero surface with frosted glass overlay.
class GlassHeroCard extends StatelessWidget {
  const GlassHeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.x6),
    this.scene = GlassScene.home,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final GlassScene scene;

  @override
  Widget build(BuildContext context) {
    final darkHero = GlassTokens.heroUsesDarkForeground(context, scene: scene);
    final radius = BorderRadius.circular(AppRadius.hero);
    final sigma = GlassTokens.blurSigma(context, override: 12, scene: scene);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: GlassTokens.heroGlow(context, scene: scene),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: GlassTokens.heroGradient(context, scene: scene),
                ),
              ),
            ),
            // Brand highlight — soft mint wash on hero cards.
            Positioned(
              top: -40,
              right: -20,
              child: _AmbientHighlight(
                size: 160,
                color: (darkHero ? CosmosColors.signalMint : CosmosColors.concentricTeal)
                    .withValues(alpha: darkHero ? 0.10 : 0.14),
              ),
            ),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: darkHero ? 0.04 : 0.22),
                ),
                child: Padding(padding: padding, child: child),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmbientHighlight extends StatelessWidget {
  const _AmbientHighlight({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
