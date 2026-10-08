import 'package:flutter/material.dart';

import '../core/theme/design_tokens.dart';
import '../data/demo_data.dart';

class DemoModeBanner extends StatelessWidget {
  const DemoModeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!DemoData.isDemoMode) return const SizedBox.shrink();

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
            children: [
              Icon(
                Icons.science_outlined,
                size: 16,
                color: accent,
              ),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: Text(
                  'On-device scanner packs active. Everything runs locally only.',
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
