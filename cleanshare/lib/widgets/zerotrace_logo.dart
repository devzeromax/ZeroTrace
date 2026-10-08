import 'package:flutter/material.dart';

import '../core/constants/app_assets.dart';
import '../core/constants/app_branding.dart';
import '../core/theme/design_tokens.dart';

/// Brand mark — image logo with optional wordmark for headers and onboarding.
class ZeroTraceLogo extends StatelessWidget {
  const ZeroTraceLogo({
    super.key,
    this.size = 32,
    this.showWordmark = true,
    this.compact = false,
  });

  final double size;
  final bool showWordmark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: AppBranding.name,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            AppAssets.logoMark,
            width: size,
            height: size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => Icon(
              Icons.shield_outlined,
              size: size * 0.75,
              color: colorScheme.secondary,
            ),
          ),
          if (showWordmark) ...[
            SizedBox(width: compact ? AppSpacing.x2 : AppSpacing.x3),
            Text(
              AppBranding.name,
              style: (compact
                      ? Theme.of(context).textTheme.titleMedium
                      : Theme.of(context).textTheme.titleLarge)
                  ?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Full logo lockup with tagline — transparent PNG for light/dark surfaces.
class ZeroTraceLogoFull extends StatelessWidget {
  const ZeroTraceLogoFull({
    super.key,
    this.maxWidth = 320,
  });

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: '${AppBranding.name}. ${AppBranding.taglineShort}',
      child: Image.asset(
        AppAssets.logoFull,
        width: maxWidth,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        // Transparent asset — no backdrop fill so light About dialogs stay clean.
        errorBuilder: (_, __, ___) => Icon(
          Icons.shield_outlined,
          size: maxWidth * 0.35,
          color: colorScheme.primary,
        ),
      ),
    );
  }
}
