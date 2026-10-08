import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_typography.dart';
import 'design_tokens.dart';

abstract final class AppTheme {
  static ThemeData light() {
    const colorScheme = ColorScheme.light(
      primary: CosmosColors.voidBlack,
      onPrimary: CosmosColors.pureWhite,
      secondary: CosmosColors.signalMint,
      onSecondary: CosmosColors.voidBlack,
      surface: AppColors.surfaceLight,
      onSurface: AppColors.textPrimaryLight,
      onSurfaceVariant: AppColors.textSecondaryLight,
      outline: AppColors.borderLight,
      surfaceContainerHighest: Color(0xFFEBEDEF),
      error: AppColors.riskCritical,
    );

    return _baseTheme(
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackground: AppColors.backgroundLight,
      textPrimary: AppColors.textPrimaryLight,
      textSecondary: AppColors.textSecondaryLight,
      textMuted: AppColors.textMutedLight,
      navBackground: AppColors.surfaceLight,
      navIndicator: AppColors.accentSubtle,
      navSelected: CosmosColors.concentricTeal,
      navUnselected: AppColors.textMutedLight,
    );
  }

  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      primary: CosmosColors.pureWhite,
      onPrimary: CosmosColors.voidBlack,
      secondary: CosmosColors.signalMint,
      onSecondary: CosmosColors.voidBlack,
      surface: CosmosColors.graphite,
      onSurface: CosmosColors.pureWhite,
      onSurfaceVariant: CosmosColors.slate,
      outline: CosmosColors.iron,
      surfaceContainerHighest: CosmosColors.carbon,
      error: AppColors.riskCritical,
    );

    return _baseTheme(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackground: CosmosColors.voidBlack,
      textPrimary: CosmosColors.pureWhite,
      textSecondary: CosmosColors.slate,
      textMuted: CosmosColors.fog,
      navBackground: CosmosColors.carbon,
      navIndicator: const Color(0x3322E2A8),
      navSelected: CosmosColors.signalMint,
      navUnselected: CosmosColors.slate,
    );
  }

  static ThemeData _baseTheme({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required Color scaffoldBackground,
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
    required Color navBackground,
    required Color navIndicator,
    required Color navSelected,
    required Color navUnselected,
  }) {
    final textTheme = AppTypography.build(
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      textMuted: textMuted,
    );
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      textTheme: textTheme,
      dividerColor: colorScheme.outline,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scaffoldBackground,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium,
        iconTheme: IconThemeData(color: textPrimary),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navBackground,
        indicatorColor: navIndicator,
        surfaceTintColor: Colors.transparent,
        height: 64,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: selected ? navSelected : navUnselected,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? navSelected : navUnselected,
            size: 24,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: navBackground,
        indicatorColor: navIndicator,
        selectedIconTheme: IconThemeData(color: navSelected),
        unselectedIconTheme: IconThemeData(color: navUnselected),
        selectedLabelTextStyle:
            textTheme.labelSmall?.copyWith(color: navSelected),
        unselectedLabelTextStyle:
            textTheme.labelSmall?.copyWith(color: navUnselected),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4,
          vertical: AppSpacing.x3,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: CosmosColors.signalMint, width: 2),
        ),
        hintStyle: textTheme.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        backgroundColor: colorScheme.surfaceContainerHighest,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: textPrimary),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outline,
        thickness: 1,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: const WidgetStatePropertyAll(BorderSide.none),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
        ),
      ),
    );
  }
}
