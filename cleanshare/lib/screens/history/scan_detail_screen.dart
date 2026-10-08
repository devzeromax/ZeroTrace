import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_routes.dart';
import '../../core/theme/design_tokens.dart';
import '../../infrastructure/storage/history_file_recovery.dart';
import '../../models/app_models.dart';
import '../../providers/engine_providers.dart';
import '../../providers/workflow_provider.dart';
import '../../core/theme/glass_scene.dart';
import '../../widgets/premium_page.dart';
import '../../widgets/audit_summary_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/finding_row.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/secondary_button.dart';

class ScanDetailScreen extends ConsumerWidget {
  const ScanDetailScreen({super.key, required this.scanId});

  final String scanId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(historyProvider);
    ScanSession? session;
    for (final s in sessions) {
      if (s.id == scanId) {
        session = s;
        break;
      }
    }

    if (session == null) {
      return PremiumPage(
        scene: GlassScene.history,
        appBar: const GlassAppBar(
          scene: GlassScene.history,
          title: Text('Scan details'),
        ),
        body: EmptyStatePanel(
          scene: GlassScene.history,
          title: 'Scan not available',
          description:
              'This scan may have been deleted or is no longer in your local history.',
          icon: Icons.search_off_outlined,
          action: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PrimaryButton(
                label: 'Back to history',
                onPressed: () => context.go(AppRoutes.history),
              ),
              const SizedBox(height: AppSpacing.x3),
              SecondaryButton(
                label: 'Go to Home',
                onPressed: () => context.go(AppRoutes.home),
              ),
            ],
          ),
        ),
      );
    }

    final layout = ref.watch(zeroTraceLayoutProvider);
    final stagedAvailable = HistoryFileRecovery.resolveStagedPath(
          layout,
          session.fileName,
          savedPath: session.stagedFilePath,
        ) !=
        null;
    final exportAvailable = HistoryFileRecovery.resolveExportPath(
          layout,
          session.fileName,
          savedPath: session.exportedFilePath,
        ) !=
        null;

    return PremiumPage(
      scene: GlassScene.history,
      appBar: GlassAppBar(
        scene: GlassScene.history,
        title: const Text('Scan details'),
        automaticallyImplyLeading: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete scan',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete scan?'),
                  content: const Text(
                    'This removes the scan from your local history on this device.',
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
              if (confirmed == true && context.mounted) {
                ref.read(historyProvider.notifier).remove(scanId);
                context.pop();
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.x4),
        children: [
          AuditSummaryHeader(session: session),
          const SizedBox(height: AppSpacing.x3),
          Text(
            stagedAvailable
                ? 'Original file is on this device — you can review fixes and re-export.'
                : exportAvailable
                    ? 'Sanitized copy is saved — you can save it again from review.'
                    : 'Source file is missing — scan the file again to export.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: AppSpacing.x6),
          Text(
            'All findings',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
          ),
          const SizedBox(height: AppSpacing.x3),
          ...session.findings.map((f) => FindingRow(finding: f)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: PrimaryButton(
            label: session.isExported ? 'Review & re-export' : 'Review & export',
            icon: Icons.auto_fix_high_outlined,
            onPressed: () {
              ref.read(workflowProvider.notifier).loadFromHistory(session!);
              context.push(AppRoutes.fix);
            },
          ),
        ),
      ),
    );
  }
}
