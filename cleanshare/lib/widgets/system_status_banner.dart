import 'package:flutter/material.dart';

import '../core/constants/app_branding.dart';
import '../core/theme/design_tokens.dart';
import '../data/demo_data.dart';

/// Single top status strip to avoid stacked global banners.
class SystemStatusBanner extends StatelessWidget {
  const SystemStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final isBeta = AppBranding.isBeta;
    final isDemo = DemoData.isDemoMode;
    if (!isBeta && !isDemo) return const SizedBox.shrink();

    final brightness = Theme.of(context).brightness;
    final colorScheme = Theme.of(context).colorScheme;
    final bannerBg = AppColors.warningBannerBackground(brightness);
    final accent = AppColors.riskHigh;

    // ponytail: combine status messages into one strip to reduce global chrome.
    final message = switch ((isBeta, isDemo)) {
      (true, true) =>
        '${AppBranding.versionLabel} · On-device scanning active. Everything runs locally.',
      (true, false) => AppBranding.versionLabel,
      (false, true) =>
        'On-device scanning active. Everything runs locally.',
      (false, false) => '',
    };

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
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
          ),
          child: Row(
            children: [
              if (isBeta) ...[
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
                          letterSpacing: 0.4,
                        ),
                  ),
                ),
                const SizedBox(width: AppSpacing.x2),
              ] else ...[
                Icon(Icons.verified_user_outlined, size: 16, color: accent),
                const SizedBox(width: AppSpacing.x2),
              ],
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
