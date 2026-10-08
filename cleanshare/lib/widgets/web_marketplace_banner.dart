import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../core/platform/platform_storage.dart';
import '../core/theme/design_tokens.dart';
import '../core/theme/glass_scene.dart';
import 'glass_surface.dart';
import 'security_badge.dart';

/// Shown on web — clarifies what works in-browser vs desktop.
class WebMarketplaceBanner extends StatelessWidget {
  const WebMarketplaceBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || PlatformStorage.supportsLocalFileSystem) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x4),
      child: GlassSurface(
        scene: GlassScene.settings,
        padding: const EdgeInsets.all(AppSpacing.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.phone_iphone_outlined,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.x2),
                Expanded(
                  child: Text(
                    'Browsing on web',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(
              'All core scanners work in the browser. Optional face, plate, and '
              'OCR neural models need the desktop or mobile app.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpacing.x3),
            const Wrap(
              spacing: AppSpacing.x2,
              runSpacing: AppSpacing.x2,
              children: [
                SecurityBadge(
                  label: 'Works in browser',
                  icon: Icons.check_circle_outline,
                  variant: SecurityBadgeVariant.success,
                ),
                SecurityBadge(
                  label: 'Downloads: mobile/desktop',
                  icon: Icons.phone_android_outlined,
                  variant: SecurityBadgeVariant.accent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
