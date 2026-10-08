import 'package:flutter/material.dart';

import '../core/constants/app_branding.dart';
import '../core/theme/design_tokens.dart';

/// Compact beta version indicator across the app shell.
class BetaVersionBanner extends StatelessWidget {
  const BetaVersionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AppBranding.isBeta) return const SizedBox.shrink();

    final brightness = Theme.of(context).brightness;
    final colorScheme = Theme.of(context).colorScheme;
    final bannerBg = AppColors.warningBannerBackground(brightness);
    final accent = AppColors.riskHigh;

    return Material(
      color: bannerBg,
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x4,
            vertical: AppSpacing.x2,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x2,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  'BETA',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                ),
              ),
              const SizedBox(width: AppSpacing.x2),
              Text(
                AppBranding.versionLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
