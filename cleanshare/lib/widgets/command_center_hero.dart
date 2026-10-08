import 'package:flutter/material.dart';

import '../core/theme/design_tokens.dart';
import '../core/theme/glass_scene.dart';
import '../core/theme/glass_tokens.dart';
import 'glass_hero_card.dart';
import 'count_up_text.dart';
import 'hero_sparkline.dart';

/// Gradient hero card — total scans & fixes with sparkline trends.
class CommandCenterHero extends StatelessWidget {
  const CommandCenterHero({
    super.key,
    required this.totalScans,
    required this.fixesApplied,
    required this.scanSparkline,
    required this.fixesSparkline,
    this.onViewHistory,
  });

  final int totalScans;
  final int fixesApplied;
  final List<double> scanSparkline;
  final List<double> fixesSparkline;
  final VoidCallback? onViewHistory;

  @override
  Widget build(BuildContext context) {
    final darkHero =
        GlassTokens.heroUsesDarkForeground(context, scene: GlassScene.home);
    final onHero =
        darkHero ? CosmosColors.pureWhite : CosmosColors.voidBlack;
    final onHeroMuted = onHero.withValues(alpha: 0.72);
    final accent = Theme.of(context).colorScheme.secondary;
    final sparkColor = darkHero
        ? accent.withValues(alpha: 0.85)
        : CosmosColors.concentricTeal;

    return GlassHeroCard(
      scene: GlassScene.home,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Overview',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: onHero,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              if (onViewHistory != null)
                TextButton(
                  onPressed: onViewHistory,
                  style: TextButton.styleFrom(
                    foregroundColor: darkHero
                        ? accent.withValues(alpha: 0.9)
                        : CosmosColors.concentricTeal,
                    minimumSize: const Size(48, 48),
                  ),
                  child: const Text('View history'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.x4),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _HeroStatTile(
                    label: 'Total scans',
                    value: totalScans,
                    sparkline: scanSparkline,
                    sparkColor: sparkColor,
                    onHero: onHero,
                    onHeroMuted: onHeroMuted,
                  ),
                ),
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
                  color: onHero.withValues(alpha: 0.15),
                ),
                Expanded(
                  child: _HeroStatTile(
                    label: 'Fixes applied',
                    value: fixesApplied,
                    sparkline: fixesSparkline,
                    sparkColor: sparkColor,
                    onHero: onHero,
                    onHeroMuted: onHeroMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStatTile extends StatelessWidget {
  const _HeroStatTile({
    required this.label,
    required this.value,
    required this.sparkline,
    required this.sparkColor,
    required this.onHero,
    required this.onHeroMuted,
  });

  final String label;
  final int value;
  final List<double> sparkline;
  final Color sparkColor;
  final Color onHero;
  final Color onHeroMuted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: onHeroMuted,
                ),
          ),
          const SizedBox(height: AppSpacing.x2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: CountUpText(
                    target: value,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: onHero,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.x2),
              HeroSparkline(
                points: sparkline,
                color: sparkColor.withValues(alpha: 0.9),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
