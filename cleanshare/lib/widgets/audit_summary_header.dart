import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/extensions/model_extensions.dart';
import '../core/theme/design_tokens.dart';
import '../models/app_models.dart';
import '../core/theme/glass_scene.dart';
import 'glass_blob_backdrop.dart';
import 'glass_surface.dart';
import 'risk_level_label.dart';

class AuditSummaryHeader extends StatelessWidget {
  const AuditSummaryHeader({
    super.key,
    required this.session,
  });

  final ScanSession session;

  RiskLevel _scoreLevel(int score) {
    if (score >= 75) return RiskLevel.critical;
    if (score >= 50) return RiskLevel.high;
    if (score >= 25) return RiskLevel.medium;
    if (score > 0) return RiskLevel.low;
    return RiskLevel.none;
  }

  String _verdict(int score, int findingCount) {
    if (findingCount == 0) return 'Clean file';
    if (score >= 75) return 'Critical exposure';
    if (score >= 50) return 'High risk';
    if (score >= 25) return 'Review recommended';
    return 'Low risk';
  }

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('MMM d, yyyy · h:mm a').format(session.scannedAt);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final level = _scoreLevel(session.riskScore);
    final accent = level.color;
    final findingCount = session.findings.length;

    return Semantics(
      label:
          'Audit report for ${session.fileName}. Risk index ${session.riskScore} out of 100. ${_verdict(session.riskScore, findingCount)}.',
      child: GlassBlobBackdrop(
        borderRadius: AppRadius.xl,
        accent: accent,
        scene: GlassScene.audit,
        intensity: findingCount > 0 ? 1.15 : 0.95,
        child: GlassSurface(
          scene: GlassScene.audit,
          borderRadius: AppRadius.xl,
          intensity: 0.16,
          blurSigma: 26,
          focused: findingCount > 0,
          padding: EdgeInsets.zero,
          child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.14),
                Colors.transparent,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 16,
                      color: accent,
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    Text(
                      'Audit result',
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 0.3,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x4),
                Text(
                  session.fileName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.x1),
                Text(
                  '$dateStr · ${session.fileSize}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.x4),
                Text(
                  '0 = clean · higher = more exposure',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                if (session.riskScore <= 10) ...[
                  const SizedBox(height: AppSpacing.x2),
                  Text(
                    session.riskScore == 0
                        ? 'No privacy issues detected. If you already exported a '
                            'sanitized copy, that is expected — metadata was removed.'
                        : 'A very low index means the file is already clean or was '
                            'previously sanitized.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.x4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 96,
                      height: 96,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 96,
                            height: 96,
                            child: CircularProgressIndicator(
                              value: session.riskScore / 100,
                              strokeWidth: 7,
                              backgroundColor:
                                  colorScheme.outline.withValues(alpha: 0.25),
                              color: accent,
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${session.riskScore}',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: accent,
                                  height: 1,
                                ),
                              ),
                              Text(
                                '/100',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x5),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Risk index',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.x2),
                          RiskLevelLabel(level: level),
                          const SizedBox(height: AppSpacing.x3),
                          RiskFindingCounts(session: session),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
