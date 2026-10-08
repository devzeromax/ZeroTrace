import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Theme-aware surface colors — never hardcode Cosmos dark palette in widgets.
abstract final class ThemeSurfaces {
  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static Color canvas(BuildContext context) {
    return Theme.of(context).scaffoldBackgroundColor;
  }

  static Color card(BuildContext context) {
    return Theme.of(context).colorScheme.surface;
  }

  static Color cardElevated(BuildContext context) {
    return Theme.of(context).colorScheme.surfaceContainerHighest;
  }

  static Color border(BuildContext context) {
    return Theme.of(context).colorScheme.outline;
  }

  static Color accent(BuildContext context) {
    return Theme.of(context).colorScheme.secondary;
  }

  static Color onSurface(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  static Color onSurfaceMuted(BuildContext context) {
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  /// Ghost CTA border/text for primary buttons.
  static Color ctaForeground(BuildContext context, {required bool enabled}) {
    if (!enabled) return onSurfaceMuted(context);
    return isDark(context) ? CosmosColors.pureWhite : CosmosColors.voidBlack;
  }

  static Color navBar(BuildContext context) {
    final nav = Theme.of(context).navigationBarTheme.backgroundColor;
    if (nav != null) return nav;
    return isDark(context) ? CosmosColors.carbon : AppColors.surfaceLight;
  }
}
