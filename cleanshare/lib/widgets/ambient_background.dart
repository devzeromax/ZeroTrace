import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme/glass_scene.dart';
import '../core/theme/glass_tokens.dart';
import '../core/theme/theme_surfaces.dart';

/// Layered canvas — accent depth orbs for glass blur to read against.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({
    super.key,
    required this.child,
    this.scene = GlassScene.home,
  });

  final Widget child;
  final GlassScene scene;

  @override
  Widget build(BuildContext context) {
    final canvas = ThemeSurfaces.canvas(context);
    final orbs = GlassTokens.ambientOrbs(context, scene);

    return ColoredBox(
      color: canvas,
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (final orb in orbs)
            Positioned(
              top: orb.top,
              bottom: orb.bottom,
              left: orb.left,
              right: orb.right,
              child: _AmbientOrb(size: orb.size, color: orb.color),
            ),
          child,
        ],
      ),
    );
  }
}

class _AmbientOrb extends StatelessWidget {
  const _AmbientOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
