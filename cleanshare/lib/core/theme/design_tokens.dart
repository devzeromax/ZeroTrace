import 'package:flutter/material.dart';

/// Cosmos-inspired design tokens (void → carbon → graphite surface stack).
/// Source: DESIGN (5).md — institutional dark fintech aesthetic.
abstract final class CosmosColors {
  static const voidBlack = Color(0xFF000000);
  static const carbon = Color(0xFF181818);
  static const graphite = Color(0xFF1E1F20);
  static const surfaceBright = Color(0xFF393939);
  static const iron = Color(0xFF333333);
  static const slate = Color(0xFF807F7F);
  static const fog = Color(0xFF999999);
  static const ash = Color(0xFF666666);
  static const chalk = Color(0xFFF1F4F4);
  static const pureWhite = Color(0xFFFFFFFF);
  static const signalMint = Color(0xFF22E2A8);
  static const deepNavy = Color(0xFF0A2142);
  static const concentricTeal = Color(0xFF085556);
}

abstract final class AppColors {
  static const background = CosmosColors.voidBlack;
  static const surface = CosmosColors.graphite;
  static const surfaceSubtle = CosmosColors.carbon;
  static const border = CosmosColors.iron;
  static const borderStrong = CosmosColors.ash;

  static const textPrimary = CosmosColors.pureWhite;
  static const textSecondary = CosmosColors.slate;
  static const textMuted = CosmosColors.fog;

  static const accent = CosmosColors.signalMint;
  static const accentSubtle = Color(0x1A22E2A8);
  static const accentDark = CosmosColors.concentricTeal;

  static const success = CosmosColors.signalMint;
  static const successSubtle = Color(0x1A22E2A8);

  static const riskCritical = Color(0xFFFF6B6B);
  static const riskCriticalSubtle = Color(0xFF2A1A1A);
  static const riskCriticalSubtleLight = Color(0xFFFFE8E8);
  static const riskHigh = Color(0xFFFFB347);
  static const riskHighSubtle = Color(0xFF2A2218);
  static const riskHighSubtleLight = Color(0xFFFFF0DC);
  static const riskMedium = Color(0xFFC47A20);
  static const riskMediumSubtle = CosmosColors.graphite;
  static const riskMediumSubtleLight = Color(0xFFF0F1F2);
  static const riskLow = CosmosColors.concentricTeal;
  static const riskLowSubtle = Color(0x1A085556);
  static const riskLowSubtleLight = Color(0xFFE0F4F1);
  static const statusNeutral = CosmosColors.slate;
  static const statusNeutralSubtle = Color(0x1A807F7F);
  static const riskNone = CosmosColors.slate;
  static const surfaceSubtleLight = Color(0xFFEBEDEF);

  static const backgroundDark = CosmosColors.voidBlack;
  static const surfaceDark = CosmosColors.graphite;
  static const surfaceSubtleDark = CosmosColors.carbon;
  static const borderDark = CosmosColors.iron;
  static const textPrimaryDark = CosmosColors.pureWhite;
  static const textSecondaryDark = CosmosColors.slate;
  static const textMutedDark = CosmosColors.fog;

  static const backgroundLight = Color(0xFFE4E7E9);
  static const surfaceLight = Color(0xFFF5F6F7);
  static const textPrimaryLight = CosmosColors.voidBlack;
  static const textSecondaryLight = Color(0xFF5C5F63);
  static const textMutedLight = Color(0xFF7A7D82);
  static const borderLight = Color(0xFFD4D7DA);

  /// Theme-aware warning banner surface (demo mode, alerts).
  static Color warningBannerBackground(Brightness brightness) {
    return brightness == Brightness.dark
        ? riskHighSubtle
        : riskHighSubtleLight;
  }
}

abstract final class AppRadius {
  static const none = 0.0;
  static const image = 10.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const hero = 24.0;
  static const xl = 30.0;
  static const navPill = 32.0;
  static const pill = 20.0;
  static const full = 9999.0;
}

abstract final class AppSpacing {
  static const x1 = 4.0;
  static const x2 = 8.0;
  static const x3 = 12.0;
  static const x4 = 16.0;
  static const x5 = 20.0;
  static const x6 = 24.0;
  static const x7 = 28.0;
  static const x8 = 32.0;
  static const x10 = 40.0;
  static const x12 = 48.0;
  static const x13 = 50.0;
  static const x25 = 100.0;

  static const cardPadding = 20.0;
  static const sectionGap = 80.0;
  static const pageMaxWidth = 1280.0;
  static const gutter = 24.0;
  static const marginMobile = 16.0;
  static const marginDesktop = 64.0;
}

abstract final class AppDurations {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 300);
  static const exportProcessingMinimum = Duration(milliseconds: 5500);
  static const exportStatusStep = Duration(milliseconds: 1100);
}

abstract final class AppTypographyScale {
  static const caption = 12.0;
  static const bodySm = 14.0;
  static const body = 16.0;
  static const subheading = 24.0;
  static const headingSm = 32.0;
  static const heading = 36.0;
  static const display = 60.0;
  static const displayMobile = 40.0;
}
