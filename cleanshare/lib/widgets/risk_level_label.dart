import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../core/extensions/model_extensions.dart';

/// Minimal severity label — neutral typography, no colored pills or dots.
class RiskLevelLabel extends StatelessWidget {
  const RiskLevelLabel({
    super.key,
    required this.level,
    this.compact = false,
    this.neutral = true,
  });

  final RiskLevel level;
  final bool compact;
  final bool neutral;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textColor = neutral
        ? colorScheme.onSurfaceVariant
        : colorScheme.onSurface;

    return Semantics(
      label: '${level.riskLabel} risk',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!neutral) ...[
            Container(
              width: compact ? 6 : 7,
              height: compact ? 6 : 7,
              decoration: BoxDecoration(
                color: level.color,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: compact ? 6 : 8),
          ],
          Text(
            level.riskLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              fontSize: compact ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline finding counts for audit summary — no colored chips.
class RiskFindingCounts extends StatelessWidget {
  const RiskFindingCounts({
    super.key,
    required this.session,
  });

  final ScanSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final parts = <String>[];

    if (session.criticalCount > 0) {
      parts.add('${session.criticalCount} critical');
    }
    if (session.highCount > 0) parts.add('${session.highCount} high');
    if (session.mediumCount > 0) parts.add('${session.mediumCount} medium');
    if (session.lowCount > 0) parts.add('${session.lowCount} low');

    if (parts.isEmpty) {
      return Text(
        'No open findings',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Text(
      parts.join('  ·  '),
      style: theme.textTheme.bodySmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
        height: 1.4,
        letterSpacing: 0.1,
      ),
    );
  }
}
