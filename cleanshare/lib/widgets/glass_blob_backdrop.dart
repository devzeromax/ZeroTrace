import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme/design_tokens.dart';
import '../core/theme/glass_scene.dart';

/// Localized gradient blobs behind frosted glass — makes blur read as glassmorphism.
class GlassBlobBackdrop extends StatelessWidget {
  const GlassBlobBackdrop({
    super.key,
    required this.child,
    required this.borderRadius,
    this.accent,
    this.scene,
    this.intensity = 1,
  });

  final Widget child;
  final double borderRadius;
  final Color? accent;
  final GlassScene? scene;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final colorScheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = dark
        ? (accent ?? colorScheme.secondary)
        : Color.lerp(colorScheme.surface, CosmosColors.deepNavy, 0.18)!;
    final strength = (dark ? 0.62 : 0.18) * intensity.clamp(0.5, 1.4);

    final secondary = Color.lerp(primary, CosmosColors.concentricTeal, 0.4)!;
    final tertiary = Color.lerp(primary, CosmosColors.deepNavy, 0.55)!;

    final blobs = switch (scene) {
      GlassScene.workflow => _workflowBlobs(primary, secondary, tertiary, strength),
      GlassScene.audit || GlassScene.reports => _auditBlobs(
          primary,
          secondary,
          tertiary,
          strength,
        ),
      GlassScene.home => _homeBlobs(primary, secondary, tertiary, strength),
      _ => _defaultBlobs(primary, secondary, tertiary, strength),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (!reduceMotion) ...blobs,
          child,
        ],
      ),
    );
  }

  static List<Widget> _blob({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double size,
    required double blurSigma,
    required List<Color> colors,
  }) {
    return [
      Positioned(
        top: top,
        bottom: bottom,
        left: left,
        right: right,
        child: _GradientBlob(size: size, blurSigma: blurSigma, colors: colors),
      ),
    ];
  }

  static List<Widget> _workflowBlobs(
    Color primary,
    Color secondary,
    Color tertiary,
    double strength,
  ) {
    return [
      ..._blob(
        top: -36,
        right: -28,
        size: 260,
        blurSigma: 64,
        colors: [
          primary.withValues(alpha: strength),
          primary.withValues(alpha: 0),
        ],
      ),
      ..._blob(
        bottom: -40,
        left: -32,
        size: 240,
        blurSigma: 58,
        colors: [
          secondary.withValues(alpha: strength * 0.9),
          secondary.withValues(alpha: 0),
        ],
      ),
      ..._blob(
        top: 72,
        left: 12,
        size: 160,
        blurSigma: 48,
        colors: [
          tertiary.withValues(alpha: strength * 0.45),
          tertiary.withValues(alpha: 0),
        ],
      ),
    ];
  }

  static List<Widget> _auditBlobs(
    Color primary,
    Color secondary,
    Color tertiary,
    double strength,
  ) {
    return [
      ..._blob(
        top: -32,
        right: -24,
        size: 260,
        blurSigma: 64,
        colors: [
          primary.withValues(alpha: strength),
          primary.withValues(alpha: 0),
        ],
      ),
      ..._blob(
        bottom: -36,
        left: -28,
        size: 240,
        blurSigma: 58,
        colors: [
          secondary.withValues(alpha: strength * 0.85),
          secondary.withValues(alpha: 0),
        ],
      ),
      ..._blob(
        top: 40,
        left: 24,
        size: 140,
        blurSigma: 50,
        colors: [
          tertiary.withValues(alpha: strength * 0.5),
          tertiary.withValues(alpha: 0),
        ],
      ),
      ..._blob(
        bottom: 12,
        right: 32,
        size: 100,
        blurSigma: 42,
        colors: [
          const Color(0xFF7B6CFF).withValues(alpha: strength * 0.35),
          const Color(0xFF7B6CFF).withValues(alpha: 0),
        ],
      ),
    ];
  }

  static List<Widget> _homeBlobs(
    Color primary,
    Color secondary,
    Color tertiary,
    double strength,
  ) {
    return [
      ..._blob(
        top: -32,
        right: -24,
        size: 250,
        blurSigma: 62,
        colors: [
          primary.withValues(alpha: strength * 0.85),
          primary.withValues(alpha: 0),
        ],
      ),
      ..._blob(
        bottom: -36,
        left: -28,
        size: 230,
        blurSigma: 54,
        colors: [
          secondary.withValues(alpha: strength * 0.7),
          secondary.withValues(alpha: 0),
        ],
      ),
    ];
  }

  static List<Widget> _defaultBlobs(
    Color primary,
    Color secondary,
    Color tertiary,
    double strength,
  ) {
    return [
      ..._blob(
        top: -30,
        right: -22,
        size: 230,
        blurSigma: 58,
        colors: [
          primary.withValues(alpha: strength),
          primary.withValues(alpha: 0),
        ],
      ),
      ..._blob(
        bottom: -34,
        left: -26,
        size: 210,
        blurSigma: 52,
        colors: [
          secondary.withValues(alpha: strength * 0.8),
          secondary.withValues(alpha: 0),
        ],
      ),
    ];
  }
}

class _GradientBlob extends StatelessWidget {
  const _GradientBlob({
    required this.size,
    required this.blurSigma,
    required this.colors,
  });

  final double size;
  final double blurSigma;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: colors,
            stops: const [0.0, 0.78],
          ),
        ),
      ),
    );
  }
}
