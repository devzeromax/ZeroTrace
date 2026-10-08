import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_branding.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/shell_scroll_padding.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/design_tokens.dart';
import '../../domain/marketplace/marketplace_models.dart';
import '../../infrastructure/security/secure_data_wiper.dart';
import '../../providers/engine_providers.dart';
import '../../providers/intro_video_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/marketplace_provider.dart';
import '../../providers/neural_pack_status_provider.dart';
import '../../providers/welcome_celebration_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/workflow_provider.dart';
import '../../services/theme_storage.dart';
import '../../widgets/security_badge.dart';
import '../../core/theme/glass_scene.dart';
import '../../widgets/glass_surface.dart';
import '../../widgets/premium_page.dart';
import '../../widgets/shell_page_header.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/zerotrace_logo.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmDeleteData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all data?'),
        content: const Text(
          'This permanently removes scan history, staged files, exports, '
          'downloaded scanner packs, cache, and security logs from this device. '
          'Built-in scanners return automatically; optional neural packs must be '
          're-downloaded from the Marketplace.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    await ref.read(engineBootstrapProvider.future);
    if (!context.mounted) return;

    final layout = ref.read(zeroTraceLayoutProvider);
    await ref.read(historyProvider.notifier).clear();
    await SecureDataWiper(layout).wipeAllUserData();
    ref.read(workflowProvider.notifier).reset();

    ref.invalidate(marketplaceItemsProvider);
    ref.invalidate(marketplaceProvider);
    ref.invalidate(scanPipelineProvider);
    ref.invalidate(inactiveNeuralPackDiagnosticsProvider);
    ref.invalidate(pluginDiscoveryProvider);
    await ref.read(marketplaceProvider.notifier).refresh();

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'All local data removed. Re-download optional scanner packs from the Marketplace.',
        ),
      ),
    );
    context.push(AppRoutes.marketplace);
  }

  Future<void> _showAboutDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('About ${AppBranding.name}'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ZeroTraceLogoFull(maxWidth: 200),
            SizedBox(height: AppSpacing.x4),
            Text(
              '${AppBranding.taglineShort}\n\n'
              '${AppBranding.versionLabel}\n\n'
              '${AppBranding.description}\n\n'
              'Detection results are informational. Always review exports before sharing.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeAsync = ref.watch(themeProvider);
    final preference = themeAsync.value ?? ThemePreference.system;
    final colorScheme = Theme.of(context).colorScheme;
    final marketplaceAsync = ref.watch(marketplaceItemsProvider);

    final bottomInset = ShellScrollPadding.list(context).bottom;

    return PremiumPage(
      scene: GlassScene.settings,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.marginMobile,
          AppSpacing.marginMobile,
          AppSpacing.marginMobile,
          bottomInset,
        ),
        children: [
          const ShellPageHeader(
            title: 'Settings',
            subtitle: 'Appearance, privacy, scanner packs, and app info.',
          ),
          const _SectionHeader(title: 'Appearance'),
          GlassSurface(
            scene: GlassScene.settings,
            padding: const EdgeInsets.all(AppSpacing.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Theme',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.x1),
                Text(
                  'Choose light, dark, or match your system setting.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.x4),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: SegmentedButton<ThemePreference>(
                      showSelectedIcon: true,
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                        side: const WidgetStatePropertyAll(BorderSide.none),
                        backgroundColor: WidgetStateProperty.resolveWith((states) {
                          if (!states.contains(WidgetState.selected)) {
                            return Colors.transparent;
                          }
                          return colorScheme.primary.withValues(alpha: 0.12);
                        }),
                        foregroundColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return colorScheme.onSurface;
                          }
                          return colorScheme.onSurface.withValues(alpha: 0.9);
                        }),
                        textStyle: WidgetStatePropertyAll(
                          Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        iconColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return colorScheme.primary;
                          }
                          return colorScheme.onSurface.withValues(alpha: 0.82);
                        }),
                      ),
                      segments: const [
                        ButtonSegment(
                          value: ThemePreference.light,
                          icon: Icon(Icons.light_mode_outlined, size: 18),
                          label: Text('Light'),
                        ),
                        ButtonSegment(
                          value: ThemePreference.dark,
                          icon: Icon(Icons.dark_mode_outlined, size: 18),
                          label: Text('Dark'),
                        ),
                        ButtonSegment(
                          value: ThemePreference.system,
                          icon: Icon(Icons.brightness_auto_outlined, size: 18),
                          label: Text('System'),
                        ),
                      ],
                      selected: {preference},
                      onSelectionChanged: themeAsync.isLoading
                          ? null
                          : (selection) {
                              ref
                                  .read(themeProvider.notifier)
                                  .setPreference(selection.first);
                            },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x6),
          const _SectionHeader(title: 'App'),
          _SettingsTile(
            icon: Icons.play_circle_outline,
            title: 'Replay introduction',
            subtitle: 'Watch the intro video and onboarding walkthrough again',
            onTap: () async {
              await ref.read(introVideoProvider.notifier).reset();
              await ref.read(onboardingProvider.notifier).reset();
              await ref.read(welcomeCelebrationProvider.notifier).reset();
              if (!context.mounted) return;
              context.go(AppRoutes.intro);
            },
          ),
          const SizedBox(height: AppSpacing.x6),
          const _SectionHeader(title: 'Privacy'),
          _SettingsTile(
            icon: Icons.gavel_outlined,
            title: 'Legal notice',
            subtitle: 'AI limitations, disclaimer, and liability',
            onTap: () => context.push(AppRoutes.legalNotice),
          ),
          const SizedBox(height: AppSpacing.x3),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy policy',
            subtitle: 'How ${AppBranding.name} handles your data',
            onTap: () => context.push(AppRoutes.privacyPolicy),
          ),
          const SizedBox(height: AppSpacing.x3),
          _SettingsTile(
            icon: Icons.delete_sweep_outlined,
            title: 'Delete all data',
            subtitle: 'Clear history, cache, and downloaded packs',
            onTap: () => _confirmDeleteData(context, ref),
            isDestructive: true,
          ),
          const SizedBox(height: AppSpacing.x6),
          const _SectionHeader(title: 'Scanner packs'),
          _SettingsTile(
            icon: Icons.storefront_outlined,
            title: 'Pack Marketplace',
            subtitle: 'Download face, QR, OCR, and privacy scanner packs',
            onTap: () => context.push(AppRoutes.marketplace),
          ),
          const SizedBox(height: AppSpacing.x3),
          GlassSurface(
            scene: GlassScene.settings,
            padding: const EdgeInsets.all(AppSpacing.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Installed packs',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    SecurityBadge(
                      label: marketplaceAsync.when(
                        data: (items) {
                          final installed = items
                              .where((i) => i.installState == ModelInstallState.installed)
                              .length;
                          return '$installed loaded';
                        },
                        loading: () => '…',
                        error: (_, __) => 'Local',
                      ),
                      variant: SecurityBadgeVariant.success,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x3),
                marketplaceAsync.when(
                  data: (items) => Column(
                    children: items
                        .map(
                          (item) => _ModelRow(
                            name: item.entry.name,
                            size: _formatModelSize(item.entry.sizeBytes),
                            status: item.statusLabel,
                          ),
                        )
                        .toList(),
                  ),
                  loading: () => const InstalledPacksSkeleton(),
                  error: (_, __) => const _ModelRow(
                    name: 'Metadata Cleaner',
                    size: '4 MB',
                    status: 'Installed',
                  ),
                ),
                const SizedBox(height: AppSpacing.x3),
                Text(
                  'Core scanners are built-in (KB). Optional face/plate/OCR packs are multi‑MB neural models.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x6),
          const _SectionHeader(title: 'About'),
          _SettingsTile(
            icon: Icons.info_outline,
            title: 'About ${AppBranding.name}',
            subtitle: AppBranding.versionLabel,
            onTap: () => _showAboutDialog(context),
          ),
        ],
      ),
    );
  }
}

String _formatModelSize(int bytes) {
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x3),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
          ),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Divider(
              color: colorScheme.outline.withValues(alpha: 0.5),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final titleColor = isDestructive ? AppColors.riskCritical : colorScheme.onSurface;
    final subtitleColor = colorScheme.onSurfaceVariant;
    final iconColor = isDestructive ? AppColors.riskCritical : colorScheme.onSurfaceVariant;

    return GlassSurface(
      scene: GlassScene.settings,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x4,
              vertical: AppSpacing.x3,
            ),
            child: Row(
              children: [
                Icon(icon, color: iconColor),
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: titleColor,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: AppSpacing.x1),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: subtitleColor,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.x2),
                Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({
    required this.name,
    required this.size,
    required this.status,
  });

  final String name;
  final String size;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x2),
      child: Row(
        children: [
          Expanded(
            child: Text(name, style: Theme.of(context).textTheme.bodyLarge),
          ),
          Text(size, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: AppSpacing.x3),
          Text(
            status,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
