import 'package:flutter/material.dart';

import '../core/constants/model_pack_art.dart';
import '../core/theme/design_tokens.dart';
import '../core/theme/glass_scene.dart';
import 'glass_surface.dart';

/// Explains that MB neural packs are optional add-ons only.
class MarketplaceNeuralNotice extends StatelessWidget {
  const MarketplaceNeuralNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return GlassSurface(
      scene: GlassScene.settings,
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 22,
                color: colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Text(
                  'Optional scanner packs',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            'Metadata, QR codes, PDF headers, and API-key detection are already '
            'built in — no download required.\n\n'
            'Optional face, plate, and document packs install from the app '
            'bundle on first open (no CDN required). Scans stay on-device.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

/// Section title for marketplace grids.
class MarketplaceSectionHeader extends StatelessWidget {
  const MarketplaceSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.x1),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Confirms large neural model download with use-case reminder.
Future<bool> confirmNeuralPackDownload(
  BuildContext context, {
  required String packName,
  required String useCase,
  required int sizeBytes,
}) async {
  final size = ModelPackArt.formatSize(sizeBytes);
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Download $packName?'),
      content: Text(
        'This optional $size scanner pack helps with $useCase.\n\n'
        'Metadata, QR, and secrets scanning already work without any download.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('Download $size'),
        ),
      ],
    ),
  );
  return result == true;
}
