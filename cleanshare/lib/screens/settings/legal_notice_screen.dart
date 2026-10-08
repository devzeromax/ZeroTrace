import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/shell_scroll_padding.dart';
import '../../core/constants/app_branding.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/glass_scene.dart';
import '../../widgets/premium_page.dart';

/// Limitation-of-liability notice for store compliance.
class LegalNoticeScreen extends StatelessWidget {
  const LegalNoticeScreen({super.key});

  static const sections = [
    (
      title: 'Software version',
      body:
          '${AppBranding.name} ${AppBranding.versionLabel}. '
          'Features, models, and accuracy may improve over time with updates. '
          'Some privacy packs or AI models may be unavailable, incomplete, or produce false positives or false negatives.',
    ),
    (
      title: 'On-device processing only',
      body:
          'Scanning, fixes, and exports run locally on your device. '
          '${AppBranding.name} does not upload your files to our servers. '
          'You remain responsible for reviewing findings before sharing exported files.',
    ),
    (
      title: 'AI detection limitations',
      body:
          'Face, vehicle, license plate, document OCR, and QR detection use automated models '
          'that are not 100% accurate. Results are informational aids only — not legal, security, or compliance advice. '
          'Always manually verify sensitive content before publishing or sharing files.',
    ),
    (
      title: 'No warranty',
      body:
          'The software is provided "as is" without warranty of any kind, express or implied, '
          'including merchantability, fitness for a particular purpose, and non-infringement.',
    ),
    (
      title: 'Limitation of liability',
      body:
          'To the maximum extent permitted by applicable law, the developers and distributors of '
          '${AppBranding.name} shall not be liable for any indirect, incidental, special, consequential, '
          'or punitive damages, or any loss of data, privacy exposure, or reputational harm arising from '
          'use of or reliance on scan results, missed detections, or exported files.',
    ),
    (
      title: 'Your responsibility',
      body:
          'By using this release, you agree to review results carefully, back up important files, '
          'and not rely solely on automated findings for regulatory, legal, or safety-critical decisions.',
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
        title: const Text('Legal notice'),
      ),
      body: ListView(
        padding: ShellScrollPadding.list(context),
        children: [
          Text(
            'Legal & liability notice',
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
