import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/shell_scroll_padding.dart';
import '../../core/constants/app_branding.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/glass_scene.dart';
import '../../widgets/premium_page.dart';

/// Local privacy disclosure for store review and user trust.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const sections = [
    (
      title: 'Detection accuracy',
      body:
          '${AppBranding.name} ${AppBranding.versionLabel} uses automated scanners that may produce incomplete or incorrect results. '
          'See Settings → Legal notice for full terms.',
    ),
    (
      title: 'Your data stays on your device',
      body:
          '${AppBranding.name} scans, fixes, and exports files locally. '
          'We do not upload your photos, documents, or scan results to our servers.',
    ),
    (
      title: 'Internet use',
      body:
          'Internet is only used to download optional privacy packs from the marketplace. '
          'Installed packs and all scanning work offline.',
    ),
    (
      title: 'What we store locally',
      body:
          'The app may store staged scan files, export outputs, installed pack files, '
          'and scan history on your device. You can delete scan data anytime in Settings.',
    ),
    (
      title: 'Permissions',
      body:
          'On mobile, ${AppBranding.name} asks for photo and file access when you open the app '
          'so you can select images and documents to scan. '
          'The app does not access your camera, microphone, or contacts.',
    ),
    (
      title: 'Contact',
      body:
          'Questions about privacy? Contact the developer listed on your app store listing.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return PremiumPage(
      scene: GlassScene.settings,
      appBar: GlassAppBar(
        scene: GlassScene.settings,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Privacy policy'),
      ),
      body: ListView(
        padding: ShellScrollPadding.list(context),
        children: [
          Text(
            AppBranding.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            'Last updated: June 2026 · ${AppBranding.versionLabel}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppSpacing.x6),
          for (final section in sections) ...[
            Text(
              section.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(
              section.body,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpacing.x5),
          ],
        ],
      ),
    );
  }
}
