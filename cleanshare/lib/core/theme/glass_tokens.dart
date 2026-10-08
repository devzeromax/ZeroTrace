import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'design_tokens.dart';
import 'glass_scene.dart';

/// iOS-style glass tokens — frosted blur, translucent fill, hairline border.
abstract final class GlassTokens {
  static const defaultBlurSigma = 8.0;
  static const fillOpacityDark = 0.10;
  static const fillOpacityLight = 0.16;
  static const borderOpacityDark = 0.12;
  static const borderOpacityLight = 0.18;

  static bool useGlass(BuildContext context) {
    // ponytail: BackdropFilter samples black on Windows; use solid surfaces instead.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      return false;
    }
    return true;
  }

  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static double blurSigma(
    BuildContext context, {
    double? override,
    GlassScene? scene,
  }) {
    if (!useGlass(context)) return 0;
    if (override != null) return override;
    if (scene == GlassScene.audit) return 12;
    if (scene == GlassScene.settings) return 8;
    return defaultBlurSigma;
  }

  static double _sceneFillOpacity(GlassScene? scene, bool dark) {
    if (scene == null) return dark ? fillOpacityDark : fillOpacityLight;
    return switch (scene) {
      GlassScene.home => dark ? 0.11 : 0.16,
      GlassScene.history => dark ? 0.09 : 0.15,
      GlassScene.reports => dark ? 0.10 : 0.16,
      GlassScene.settings => dark ? 0.08 : 0.14,
      GlassScene.workflow => dark ? 0.12 : 0.17,
      GlassScene.audit => dark ? 0.07 : 0.14,
      GlassScene.export => dark ? 0.11 : 0.16,
      GlassScene.onboarding => dark ? 0.10 : 0.15,
    };
  }

  static double _sceneTintStrength(GlassScene? scene, bool dark) {
    if (dark) return 0;
    return switch (scene) {
      GlassScene.home ||
      GlassScene.workflow ||
      GlassScene.audit ||
      GlassScene.reports =>
        0.05,
      _ => 0.02,
    };
  }

  static Color fill(
    BuildContext context, {
    double? intensity,
    GlassScene? scene,
  }) {
    if (!useGlass(context)) {
      return Theme.of(context).colorScheme.surface;
    }
    final dark = isDark(context);
    final base = intensity ?? _sceneFillOpacity(scene, dark);
    final alpha = intensity != null
        ? _clampIntensity(intensity, scene, dark)
        : base;

    if (dark) {
      if (scene == GlassScene.audit) {
        return Color.lerp(
          CosmosColors.concentricTeal,
          Colors.white,
          0.72,
        )!.withValues(alpha: alpha);
      }
      return Colors.white.withValues(alpha: alpha);
    }

    final tint = _sceneTintStrength(scene, dark);
    final baseColor = Color.lerp(
      Colors.white,
      CosmosColors.concentricTeal,
      tint,
    )!;
    return baseColor.withValues(alpha: alpha);
  }

  static double _clampIntensity(
    double intensity,
    GlassScene? scene,
    bool dark,
  ) {
    final max = switch (scene) {
      GlassScene.audit => dark ? 0.18 : 0.26,
      GlassScene.settings => dark ? 0.14 : 0.22,
      _ => dark ? 0.28 : 0.38,
    };
    final min = dark ? 0.04 : 0.06;
    return intensity.clamp(min, max);
  }

  static Color elevated(BuildContext context, {GlassScene? scene}) {
    return fill(
      context,
      intensity: isDark(context) ? 0.14 : 0.32,
      scene: scene,
    );
  }

  /// Toolbar / tab bar chrome — slightly more opaque than cards.
  static Color chromeFill(BuildContext context, {GlassScene? scene}) {
    return fill(
      context,
      intensity: isDark(context) ? 0.08 : 0.24,
      scene: scene,
    );
  }

  static bool heroUsesDarkForeground(
    BuildContext context, {
    GlassScene scene = GlassScene.home,
  }) {
    return isDark(context);
  }

  static LinearGradient heroGradient(
    BuildContext context, {
    GlassScene scene = GlassScene.home,
  }) {
    final dark = isDark(context);

    if (dark || heroUsesDarkForeground(context, scene: scene)) {
      return switch (scene) {
        GlassScene.export => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A2142),
              Color(0xFF0B5C4A),
              Color(0xFF181818),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        GlassScene.workflow => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A2142),
              Color(0xFF085556),
              Color(0xFF0F2A3D),
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        GlassScene.audit || GlassScene.reports => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A2142),
              Color(0xFF122A45),
              Color(0xFF1A1A1A),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        // Home: navy → teal → charcoal — subtle mint brand wash.
        _ => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A2142),
              Color(0xFF0B5C4A),
              Color(0xFF181818),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
      };
    }

    return switch (scene) {
      GlassScene.onboarding => LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CosmosColors.deepNavy.withValues(alpha: 0.08),
            CosmosColors.deepNavy.withValues(alpha: 0.04),
            AppColors.backgroundLight,
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
      _ => LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CosmosColors.deepNavy.withValues(alpha: 0.10),
            CosmosColors.concentricTeal.withValues(alpha: 0.12),
            AppColors.riskLowSubtleLight,
          ],
          stops: const [0.0, 0.42, 1.0],
        ),
    };
  }

  static List<BoxShadow> heroGlow(
    BuildContext context, {
    GlassScene scene = GlassScene.home,
  }) {
    final dark = isDark(context);
    // Mint accent glow on hero cards — subtle on home, stronger on export.
    final accent = switch (scene) {
      GlassScene.export || GlassScene.home || GlassScene.workflow =>
        Theme.of(context).colorScheme.secondary,
      GlassScene.audit || GlassScene.reports =>
        CosmosColors.concentricTeal,
      _ => Colors.black,
    };
    final strength = switch (scene) {
      GlassScene.export => dark ? 0.16 : 0.10,
      GlassScene.workflow => dark ? 0.18 : 0.08,
      GlassScene.home => dark ? 0.22 : 0.10,
      GlassScene.audit || GlassScene.reports => dark ? 0.20 : 0.08,
      _ => dark ? 0.22 : 0.06,
    };
    return [
      BoxShadow(
        color: accent.withValues(alpha: strength),
        blurRadius: 32,
        offset: const Offset(0, 12),
      ),
    ];
  }

  static List<BoxShadow> navGlow(BuildContext context) {
    final accent = Theme.of(context).colorScheme.secondary;
    return [
      BoxShadow(
        color: accent.withValues(alpha: isDark(context) ? 0.08 : 0.02),
        blurRadius: 18,
        offset: const Offset(0, 6),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark(context) ? 0.22 : 0.04),
        blurRadius: 12,
        offset: const Offset(0, 3),
      ),
    ];
  }

  static Color accentFill(BuildContext context) {
    return AppColors.accentSubtle;
  }

  static Color border(
    BuildContext context, {
    GlassScene? scene,
  }) {
    final dark = isDark(context);
    var alpha = dark ? borderOpacityDark : borderOpacityLight;
    if (scene == GlassScene.audit) alpha += dark ? 0.04 : 0.04;
    if (scene == GlassScene.settings) alpha -= dark ? 0.02 : 0.02;
    if (dark) {
      return Colors.white.withValues(alpha: alpha.clamp(0.08, 0.30));
    }
    return Color.lerp(
      CosmosColors.deepNavy,
      Theme.of(context).colorScheme.outline,
      0.65,
    )!.withValues(alpha: alpha.clamp(0.12, 0.35));
  }

  static Color borderHighlight(BuildContext context) {
    return Theme.of(context).colorScheme.outline;
  }

  static Color borderShadow(BuildContext context) => Colors.transparent;

  static List<BoxShadow> elevation(BuildContext context) => const [];

  static ImageFilter blurFilter(BuildContext context, {double? sigma}) {
    final s = blurSigma(context, override: sigma);
    return ImageFilter.blur(sigmaX: s, sigmaY: s);
  }

  /// Ambient orb palette per screen — gives blur something to read against.
  static List<AmbientOrbConfig> ambientOrbs(
    BuildContext context,
    GlassScene scene,
  ) {
    final dark = isDark(context);
    final mint = CosmosColors.signalMint;
    final teal = CosmosColors.concentricTeal;
    final navy = CosmosColors.deepNavy;

    if (dark) {
      return switch (scene) {
        GlassScene.home => [
            AmbientOrbConfig(
              top: -140,
              right: -100,
              size: 340,
              color: navy.withValues(alpha: 0.42),
            ),
            AmbientOrbConfig(
              top: 180,
              left: -120,
              size: 280,
              color: teal.withValues(alpha: 0.22),
            ),
            AmbientOrbConfig(
              top: -60,
              left: -40,
              size: 200,
              color: mint.withValues(alpha: 0.10),
            ),
            AmbientOrbConfig(
              bottom: -120,
              left: -80,
              size: 320,
              color: navy.withValues(alpha: 0.55),
            ),
          ],
        GlassScene.history => [
            AmbientOrbConfig(
              top: -120,
              right: -90,
              size: 300,
              color: navy.withValues(alpha: 0.45),
            ),
            AmbientOrbConfig(
              top: 200,
              left: -100,
              size: 260,
              color: teal.withValues(alpha: 0.22),
            ),
            AmbientOrbConfig(
              bottom: -80,
              right: -60,
              size: 220,
              color: mint.withValues(alpha: 0.08),
            ),
          ],
        GlassScene.reports => [
            AmbientOrbConfig(
              top: -130,
              right: -80,
              size: 320,
              color: navy.withValues(alpha: 0.50),
            ),
            AmbientOrbConfig(
              top: 160,
              left: -110,
              size: 280,
              color: teal.withValues(alpha: 0.28),
            ),
          ],
        GlassScene.settings => [
            AmbientOrbConfig(
              top: -100,
              right: -70,
              size: 260,
              color: navy.withValues(alpha: 0.35),
            ),
            AmbientOrbConfig(
              top: 240,
              left: -90,
              size: 220,
              color: teal.withValues(alpha: 0.12),
            ),
          ],
        GlassScene.workflow => [
            AmbientOrbConfig(
              top: -120,
              right: -80,
              size: 340,
              color: mint.withValues(alpha: 0.24),
            ),
            AmbientOrbConfig(
              top: 140,
              left: -100,
              size: 300,
              color: teal.withValues(alpha: 0.42),
            ),
            AmbientOrbConfig(
              bottom: -100,
              left: -70,
              size: 260,
              color: navy.withValues(alpha: 0.48),
            ),
          ],
        GlassScene.audit => [
            AmbientOrbConfig(
              top: -120,
              right: -70,
              size: 360,
              color: mint.withValues(alpha: 0.28),
            ),
            AmbientOrbConfig(
              top: 120,
              left: -100,
              size: 300,
              color: teal.withValues(alpha: 0.42),
            ),
            AmbientOrbConfig(
              bottom: 40,
              right: -50,
              size: 280,
              color: const Color(0xFFE85D4C).withValues(alpha: 0.18),
            ),
            AmbientOrbConfig(
              bottom: -80,
              left: -60,
              size: 260,
              color: navy.withValues(alpha: 0.35),
            ),
          ],
        GlassScene.export => [
            AmbientOrbConfig(
              top: -130,
              right: -90,
              size: 340,
              color: mint.withValues(alpha: 0.16),
            ),
            AmbientOrbConfig(
              top: 160,
              left: -100,
              size: 280,
              color: teal.withValues(alpha: 0.30),
            ),
          ],
        GlassScene.onboarding => [
            AmbientOrbConfig(
              top: -120,
              right: -80,
              size: 300,
              color: mint.withValues(alpha: 0.12),
            ),
            AmbientOrbConfig(
              top: 200,
              left: -90,
              size: 260,
              color: teal.withValues(alpha: 0.20),
            ),
          ],
      };
    }

    // Light mode: soft mint/teal wash so glass cards read branded, not flat gray.
    return switch (scene) {
      GlassScene.home => [
        AmbientOrbConfig(
          top: -100,
          right: -60,
          size: 280,
          color: mint.withValues(alpha: 0.14),
        ),
        AmbientOrbConfig(
          top: 120,
          left: -80,
          size: 240,
          color: teal.withValues(alpha: 0.10),
        ),
        AmbientOrbConfig(
          bottom: -60,
          right: -40,
          size: 200,
          color: navy.withValues(alpha: 0.06),
        ),
      ],
      GlassScene.history || GlassScene.reports || GlassScene.settings => [
        AmbientOrbConfig(
          top: -80,
          right: -50,
          size: 220,
          color: teal.withValues(alpha: 0.08),
        ),
        AmbientOrbConfig(
          bottom: -40,
          left: -60,
          size: 180,
          color: mint.withValues(alpha: 0.06),
        ),
      ],
      GlassScene.workflow || GlassScene.audit || GlassScene.export => [
        AmbientOrbConfig(
          top: -90,
          right: -70,
          size: 260,
          color: mint.withValues(alpha: 0.12),
        ),
        AmbientOrbConfig(
          top: 140,
          left: -90,
          size: 220,
          color: teal.withValues(alpha: 0.10),
        ),
      ],
      _ => const [],
    };
  }
}

/// Positioned ambient orb for [GlassTokens.ambientOrbs].
class AmbientOrbConfig {
  const AmbientOrbConfig({
    required this.size,
    required this.color,
    this.top,
    this.bottom,
    this.left,
    this.right,
  });

  final double? top;
  final double? bottom;
  final double? left;
  final double? right;
  final double size;
  final Color color;
}
