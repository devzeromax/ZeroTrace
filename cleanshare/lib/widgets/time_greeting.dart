import 'package:flutter/material.dart';

import '../core/animation/app_motion.dart';
import '../core/constants/app_branding.dart';
import '../core/theme/design_tokens.dart';
import '../core/utils/time_greeting.dart' as greeting_util;

/// Time-aware greeting for the home command center.
///
/// Animations adapted from [pksunny/flutter-ui-and-animations](https://github.com/pksunny/flutter-ui-and-animations):
/// - Title: #74 slide-up-text
/// - Subtitle + beta chip: #106 pop-up-text
class TimeGreeting extends StatelessWidget {
  const TimeGreeting({
    super.key,
    this.now,
    this.compact = false,
  });

  final DateTime? now;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final time = now ?? DateTime.now();
    final colorScheme = Theme.of(context).colorScheme;
    final greeting = greeting_util.TimeGreeting.greetingFor(time);
    final subtitle = greeting_util.TimeGreeting.subtitleFor(time);

    return Padding(
      padding: EdgeInsets.only(
        bottom: compact ? AppSpacing.x3 : AppSpacing.x4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SlideUpReveal(
            slideOffset: 0.12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    greeting,
                    style:
                        Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                  ),
                ),
                if (AppBranding.isBeta)
                  PopUpReveal(
                    delay: const Duration(milliseconds: 200),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.x2,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        color: AppColors.accentSubtle,
                        border: Border.all(
                          color: colorScheme.secondary.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        AppBranding.versionLabel,
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: CosmosColors.concentricTeal,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: AppSpacing.x1),
            PopUpReveal(
              child: Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
