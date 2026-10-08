import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// App typography — bundled system stack (no runtime font CDN fetches).
abstract final class AppTypography {
  static TextStyle _style({
    required double size,
    required double height,
    required FontWeight weight,
    required Color color,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  static TextTheme build({
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
  }) {
    return TextTheme(
      displayLarge: _style(
        size: AppTypographyScale.display,
        height: 68 / 60,
        weight: FontWeight.w700,
        letterSpacing: 0.4,
        color: textPrimary,
      ),
      displaySmall: _style(
        size: AppTypographyScale.headingSm,
        height: 40 / 32,
        weight: FontWeight.w700,
        letterSpacing: 0.1,
        color: textPrimary,
      ),
      headlineSmall: _style(
        size: AppTypographyScale.subheading,
        height: 32 / 24,
        weight: FontWeight.w600,
        letterSpacing: 0.2,
        color: textPrimary,
      ),
      titleLarge: _style(
        size: AppTypographyScale.subheading,
        height: 32 / 24,
        weight: FontWeight.w700,
        letterSpacing: 0.05,
        color: textPrimary,
      ),
      titleMedium: _style(
        size: AppTypographyScale.body,
        height: 24 / 16,
        weight: FontWeight.w600,
        letterSpacing: 0.2,
        color: textPrimary,
      ),
      bodyLarge: _style(
        size: AppTypographyScale.body,
        height: 24 / 16,
        weight: FontWeight.w400,
        letterSpacing: 0.2,
        color: textPrimary,
      ),
      bodyMedium: _style(
        size: AppTypographyScale.bodySm,
        height: 20 / 14,
        weight: FontWeight.w400,
        letterSpacing: 0.2,
        color: textSecondary,
      ),
      bodySmall: _style(
        size: AppTypographyScale.caption,
        height: 18 / 12,
        weight: FontWeight.w400,
        letterSpacing: 0.2,
        color: textMuted,
      ),
      labelLarge: _style(
        size: AppTypographyScale.body,
        height: 24 / 16,
        weight: FontWeight.w600,
        letterSpacing: 0.2,
        color: textPrimary,
      ),
      labelMedium: _style(
        size: AppTypographyScale.bodySm,
        height: 20 / 14,
        weight: FontWeight.w500,
        letterSpacing: 0.2,
        color: textSecondary,
      ),
      labelSmall: _style(
        size: AppTypographyScale.caption,
        height: 18 / 12,
        weight: FontWeight.w500,
        letterSpacing: 0.2,
        color: textMuted,
      ),
    );
  }
}
