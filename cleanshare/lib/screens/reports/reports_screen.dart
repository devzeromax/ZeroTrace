import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/animation/app_motion.dart';
import '../../core/layout/shell_scroll_padding.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/design_tokens.dart';
import '../../models/app_models.dart';
import '../../providers/workflow_provider.dart';
import '../../core/theme/glass_scene.dart';
import '../../widgets/premium_page.dart';
import '../../widgets/audit_summary_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/recent_scan_row.dart';
import '../../widgets/shell_page_header.dart';
import '../../widgets/skeleton.dart';

/// Latest audit snapshot — full scan list lives under History.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  static const _recentLimit = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final hydrating = ref.watch(historyHydratingProvider);
    final latest = history.isNotEmpty ? history.first : null;
    final listPadding = ShellScrollPadding.list(context);
    final recentOthers = history.length > 1
        ? history.skip(1).take(_recentLimit).toList()
        : <ScanSession>[];

    return PremiumPage(
      scene: GlassScene.reports,
      body: ContentRevealSwap(
        showPlaceholder: hydrating && latest == null,
        placeholder: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.marginMobile,
            AppSpacing.marginMobile,
            AppSpacing.marginMobile,
            listPadding.bottom,
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ShellPageHeader(
                title: 'Latest audit',
                subtitle:
                    'Your most recent scan report. All past scans are in History.',
              ),
              SizedBox(height: AppSpacing.x4),
              Expanded(child: AuditReportSkeleton()),
            ],
          ),
        ),
        content: latest == null
          ? Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.marginMobile,
                AppSpacing.marginMobile,
                AppSpacing.marginMobile,
                listPadding.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ShellPageHeader(
                    title: 'Latest audit',
                    subtitle:
                        'Your most recent scan report. All past scans are in History.',
                  ),
                  Expanded(
                    child: EmptyStatePanel(
                      scene: GlassScene.reports,
                      title: 'No audits yet',
                      description: 'Complete a scan to see your latest report.',
                      icon: Icons.assessment_outlined,
                      action: PrimaryButton(
                        label: 'Add file',
                        onPressed: () => context.push(AppRoutes.upload),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.marginMobile,
                AppSpacing.marginMobile,
                AppSpacing.marginMobile,
                listPadding.bottom,
              ),
              children: [
                const ShellPageHeader(
                  title: 'Latest audit',
                  subtitle:
                      'Most recent scan report. Browse every scan in History.',
                ),
                Text(
                  'Current report',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                ),
                const SizedBox(height: AppSpacing.x3),
                AuditSummaryHeader(session: latest),
                if (recentOthers.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.x8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Earlier audits',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go(AppRoutes.history),
                        child: const Text('View all in History'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  ...recentOthers.asMap().entries.map(
                        (entry) => FadeSlideIn(
                          index: entry.key,
                          delay: AppMotion.staggerDelay(entry.key),
                          child: Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.x2),
                            child: RecentScanRow(
                              session: entry.value,
                              onTap: () => context.push(
                                AppRoutes.scanDetail(entry.value.id),
                              ),
                            ),
                          ),
                        ),
                      ),
                ] else ...[
                  const SizedBox(height: AppSpacing.x6),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => context.go(AppRoutes.history),
                      icon: const Icon(Icons.history_outlined, size: 18),
                      label: const Text('View scan history'),
                    ),
                  ),
                ],
              ],
            ),
      ),
    );
  }
}
