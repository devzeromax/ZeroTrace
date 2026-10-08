import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/design_tokens.dart';
import '../models/app_models.dart';
import '../core/extensions/model_extensions.dart';
import '../core/theme/glass_scene.dart';
import 'glass_surface.dart';

/// Compact recent-scan list row — frosted glass card.
class RecentScanRow extends StatelessWidget {
  const RecentScanRow({
    super.key,
    required this.session,
    required this.onTap,
  });

  final ScanSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final findings = session.findings.where((f) => !f.isFixed).length;
    final isClean = findings == 0;
    final colorScheme = Theme.of(context).colorScheme;

    return GlassSurface(
      scene: GlassScene.history,
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Row(
        children: [
          Icon(
            _iconForType(session.fileType),
            color: CosmosColors.concentricTeal.withValues(alpha: 0.9),
          ),
          const SizedBox(width: AppSpacing.x4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                ),
                Text(
                  '${session.fileSize} • ${_relativeTime(session.scannedAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          _StatusBadge(
            label: isClean ? 'Clean' : '$findings Risks',
            tone: isClean
                ? _BadgeTone.clean
                : (findings >= 3 ? _BadgeTone.critical : _BadgeTone.warn),
          ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return DateFormat('MMM d').format(time);
  }

  IconData _iconForType(String type) {
    final t = type.toLowerCase();
    if (t.contains('pdf')) return Icons.picture_as_pdf_outlined;
    if (t.contains('png') || t.contains('jpg') || t.contains('heic')) {
      return Icons.image_outlined;
    }
    if (t.contains('json')) return Icons.data_object_outlined;
    return Icons.insert_drive_file_outlined;
  }
}

enum _BadgeTone { clean, warn, critical }

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.tone});

  final String label;
  final _BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final (bg, fg) = switch (tone) {
      _BadgeTone.clean => (
          AppColors.statusNeutralSubtle,
          AppColors.statusNeutral,
        ),
      _BadgeTone.warn => (
          RiskLevel.high.backgroundColorFor(brightness),
          AppColors.riskHigh,
        ),
      _BadgeTone.critical => (
          RiskLevel.critical.backgroundColorFor(brightness),
          AppColors.riskCritical,
        ),
    };

    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x2,
          vertical: AppSpacing.x1,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
        ),
      ),
    );
  }
}
