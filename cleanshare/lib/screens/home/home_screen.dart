import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/animation/app_motion.dart';
import '../../core/layout/shell_scroll_padding.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/history_metrics.dart';
import '../../models/app_models.dart';
import '../../providers/workflow_provider.dart';
import '../../widgets/command_center_hero.dart';
import '../../widgets/adaptive_content.dart';
import '../../widgets/empty_state.dart';
import '../../core/theme/glass_scene.dart';
import '../../widgets/premium_page.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/recent_scan_row.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/staged_drop_zone.dart';
import '../../widgets/time_greeting.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final hydrating = ref.watch(historyHydratingProvider);
    final fixesApplied = HistoryMetrics.fixesApplied(history);
    final totalScans = history.length;
    final scanSparkline = HistoryMetrics.scanSparkline(history);
    final fixesSparkline = HistoryMetrics.fixesSparkline(history);
    final recent = history.take(3).toList();
    final wide = MediaQuery.sizeOf(context).width > 900;

    return PremiumPage(
      scene: GlassScene.home,
      body: ContentRevealSwap(
        showPlaceholder: hydrating,
        placeholder: SingleChildScrollView(
          padding: ShellScrollPadding.homeScroll(context),
          child: const AdaptiveContent(
            child: HomeCommandCenterSkeleton(),
          ),
        ),
        content: SingleChildScrollView(
          padding: ShellScrollPadding.homeScroll(context),
          child: AdaptiveContent(
            child: wide
                ? _DesktopCommandCenter(
                    totalScans: totalScans,
                    fixesApplied: fixesApplied,
                    scanSparkline: scanSparkline,
                    fixesSparkline: fixesSparkline,
                    recent: recent,
                    onAddFile: () {
                      ref.read(workflowProvider.notifier).reset();
                      context.push(AppRoutes.upload);
                    },
                    onViewAll: () => context.go(AppRoutes.history),
                  )
                : _MobileCommandCenter(
                    totalScans: totalScans,
                    fixesApplied: fixesApplied,
                    scanSparkline: scanSparkline,
                    fixesSparkline: fixesSparkline,
                    recent: recent,
                    onAddFile: () {
                      ref.read(workflowProvider.notifier).reset();
                      context.push(AppRoutes.upload);
                    },
                    onViewAll: () => context.go(AppRoutes.history),
                  ),
          ),
        ),
      ),
    );
  }
}

class _MobileCommandCenter extends StatelessWidget {
  const _MobileCommandCenter({
    required this.totalScans,
    required this.fixesApplied,
    required this.scanSparkline,
    required this.fixesSparkline,
    required this.recent,
    required this.onAddFile,
    required this.onViewAll,
  });

  final int totalScans;
  final int fixesApplied;
  final List<double> scanSparkline;
  final List<double> fixesSparkline;
  final List<ScanSession> recent;
  final VoidCallback onAddFile;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TimeGreeting(),
        FadeSlideIn(
          index: 1,
          delay: AppMotion.staggerDelay(1),
          child: CommandCenterHero(
            totalScans: totalScans,
            fixesApplied: fixesApplied,
            scanSparkline: scanSparkline,
            fixesSparkline: fixesSparkline,
            onViewHistory: onViewAll,
          ),
        ),
        const SizedBox(height: AppSpacing.x6),
        FadeSlideIn(
          index: 2,
          delay: AppMotion.staggerDelay(2),
          child: StagedDropZone(onTap: onAddFile),
        ),
        const SizedBox(height: AppSpacing.x8),
        FadeSlideIn(
          index: 3,
          delay: AppMotion.staggerDelay(3),
          child: _RecentScansSection(
            recent: recent,
            onViewAll: onViewAll,
            onAddFile: onAddFile,
          ),
        ),
      ],
    );
  }
}

class _DesktopCommandCenter extends StatelessWidget {
  const _DesktopCommandCenter({
    required this.totalScans,
    required this.fixesApplied,
    required this.scanSparkline,
    required this.fixesSparkline,
    required this.recent,
    required this.onAddFile,
    required this.onViewAll,
  });

  final int totalScans;
  final int fixesApplied;
  final List<double> scanSparkline;
  final List<double> fixesSparkline;
  final List<ScanSession> recent;
  final VoidCallback onAddFile;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TimeGreeting(),
              FadeSlideIn(
                index: 1,
                delay: AppMotion.staggerDelay(1),
                child: CommandCenterHero(
                  totalScans: totalScans,
                  fixesApplied: fixesApplied,
                  scanSparkline: scanSparkline,
                  fixesSparkline: fixesSparkline,
                  onViewHistory: onViewAll,
                ),
              ),
              const SizedBox(height: AppSpacing.x6),
              FadeSlideIn(
                index: 2,
                delay: AppMotion.staggerDelay(2),
                child: StagedDropZone(onTap: onAddFile),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.x8),
        Expanded(
          flex: 5,
          child: FadeSlideIn(
            index: 3,
            delay: AppMotion.staggerDelay(3),
            child: _RecentScansSection(
              recent: recent,
              onViewAll: onViewAll,
              onAddFile: onAddFile,
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentScansSection extends StatelessWidget {
  const _RecentScansSection({
    required this.recent,
    required this.onViewAll,
    required this.onAddFile,
  });

  final List<ScanSession> recent;
  final VoidCallback onViewAll;
  final VoidCallback onAddFile;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Recent scans',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
              ),
            ),
            TextButton(
              onPressed: onViewAll,
              child: Text(
                'View all',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colorScheme.secondary,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x2),
        if (recent.isEmpty)
          EmptyStatePanel(
            scene: GlassScene.home,
            title: 'No scans yet',
            description: 'Add a file to run your first privacy scan.',
            icon: Icons.history_outlined,
            action: PrimaryButton(
              label: 'Add file',
              onPressed: onAddFile,
            ),
          )
        else
          ...recent.asMap().entries.map(
                (entry) => FadeSlideIn(
                  index: entry.key + 3,
                  delay: AppMotion.staggerDelay(entry.key + 3),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.x2),
                    child: RecentScanRow(
                      session: entry.value,
                      onTap: () =>
                          context.push(AppRoutes.scanDetail(entry.value.id)),
                    ),
                  ),
                ),
              ),
      ],
    );
  }
}
