import 'package:flutter/material.dart';

import '../core/theme/design_tokens.dart';
import '../models/app_models.dart';
import 'glass_surface.dart';
import 'security_badge.dart';

class FileCard extends StatelessWidget {
  const FileCard({
    super.key,
    required this.fileName,
    required this.fileSize,
    required this.fileType,
    this.riskScore,
    this.onTap,
    this.trailing,
  });

  final String fileName;
  final String fileSize;
  final String fileType;
  final int? riskScore;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              _iconForType(fileType),
              size: 22,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.x1),
                Text(
                  '$fileType · $fileSize',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (riskScore != null) ...[
            const SizedBox(width: AppSpacing.x2),
            RiskBadge(level: _riskFromScore(riskScore!)),
          ],
          if (trailing != null) trailing!,
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    final t = type.toUpperCase();
    if (t.contains('PDF')) return Icons.picture_as_pdf_outlined;
    if (t.contains('PNG') || t.contains('JPG') || t.contains('JPEG')) {
      return Icons.image_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  RiskLevel _riskFromScore(int score) {
    if (score >= 70) return RiskLevel.critical;
    if (score >= 50) return RiskLevel.high;
    if (score >= 30) return RiskLevel.medium;
    if (score > 0) return RiskLevel.low;
    return RiskLevel.none;
  }
}
