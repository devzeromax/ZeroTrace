import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/animation/app_motion.dart';
import '../../core/routing/app_routes.dart';
import '../../widgets/export_bottom_sheet.dart';
import '../../core/routing/workflow_navigation.dart';
import '../../core/theme/design_tokens.dart';
import '../../models/app_models.dart';
import '../../providers/neural_pack_status_provider.dart';
import '../../providers/workflow_provider.dart';
import '../../core/theme/glass_scene.dart';
import '../../widgets/audit_summary_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/finding_row.dart';
import '../../widgets/neural_pack_status_banner.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/smooth_card_expansion.dart';
import '../../widgets/workflow_page.dart';

class AuditScreen extends ConsumerStatefulWidget {
  const AuditScreen({super.key});

  @override
  ConsumerState<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends ConsumerState<AuditScreen> {
  String? _expandedCategory;

  Map<String, List<PrivacyFinding>> _groupFindings(
    List<PrivacyFinding> findings,
  ) {
    final map = <String, List<PrivacyFinding>>{};
    for (final f in findings) {
      map.putIfAbsent(f.category, () => []).add(f);
    }
    return map;
  }

  RiskLevel _highestInGroup(List<PrivacyFinding> findings) {
    const order = [
      RiskLevel.critical,
      RiskLevel.high,
      RiskLevel.medium,
      RiskLevel.low,
      RiskLevel.none,
    ];
    for (final level in order) {
      if (findings.any((f) => f.level == level)) return level;
    }
    return RiskLevel.none;
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(workflowProvider).session;
    if (session == null) {
      return WorkflowPage(
        title: 'Audit report',
        currentStep: WorkflowStep.audit,
        scene: GlassScene.audit,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => WorkflowNavigation.popOrHome(context),
          style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
        ),
        centerBody: true,
        body: EmptyStatePanel(
          scene: GlassScene.audit,
          icon: Icons.radar_outlined,
          title: 'No scan to review',
          description:
              'Start a scan to see privacy findings for a file on this device.',
          action: PrimaryButton(
            label: 'Start a scan',
            icon: Icons.upload_file_outlined,
            onPressed: () {
              ref.read(workflowProvider.notifier).reset();
              context.go(AppRoutes.upload);
            },
          ),
        ),
      );
    }

    final grouped = _groupFindings(session.findings);
    final neuralIssues = ref.watch(inactiveNeuralPackDiagnosticsProvider);
    final isClean = session.findings.isEmpty;

    return WorkflowPage(
      title: 'Audit report',
      currentStep: WorkflowStep.audit,
      scene: GlassScene.audit,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Back',
        onPressed: () => WorkflowNavigation.popOrHome(context),
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
        ),
      ),
      body: ListView(
        children: [
          AuditSummaryHeader(session: session),
          const SizedBox(height: AppSpacing.x3),
          neuralIssues.when(
            data: (issues) => InactiveNeuralPackBannerList(
              diagnostics: issues,
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          if (neuralIssues.hasValue && neuralIssues.value!.isNotEmpty)
            const SizedBox(height: AppSpacing.x3),
          if (!isClean)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => context.push(AppRoutes.fixPreview),
                icon: const Icon(Icons.compare_outlined, size: 18),
                label: const Text('Before / after preview'),
              ),
            ),
          if (!isClean) const SizedBox(height: AppSpacing.x3),
          if (isClean)
            EmptyStatePanel(
              scene: GlassScene.audit,
              icon: Icons.verified_user_outlined,
              title: 'No risks found',
              description:
                  'This file looks clean. Export a safe copy to finish.',
              action: PrimaryButton(
                label: 'Export safe copy',
                icon: Icons.ios_share_outlined,
                onPressed: () => ExportBottomSheet.show(context),
              ),
            )
          else ...[
            Text(
              'Findings by category',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
            ),
            const SizedBox(height: AppSpacing.x3),
            ...grouped.entries.toList().asMap().entries.map((indexed) {
              final entry = indexed.value;
              final index = indexed.key;
              final expanded = _expandedCategory == entry.key;
              return FadeSlideIn(
                index: index,
                delay: AppMotion.staggerDelay(index),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.x3),
                  child: Column(
                    children: [
                      PrivacyRiskCard(
                        category: entry.key,
                        count: entry.value.length,
                        highestLevel: _highestInGroup(entry.value),
                        expanded: expanded,
                        onTap: () {
                          setState(() {
                            _expandedCategory = expanded ? null : entry.key;
                          });
                        },
                      ),
                      SmoothCardExpansion(
                        expanded: expanded,
                        child: Column(
                          children: [
                            const SizedBox(height: AppSpacing.x2),
                            ...entry.value.asMap().entries.map(
                                  (findingEntry) => FadeSlideIn(
                                    index: findingEntry.key,
                                    delay: AppMotion.staggerDelay(
                                      findingEntry.key,
                                      maxMs: 240,
                                    ),
                                    child:
                                        FindingRow(finding: findingEntry.value),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
      bottomBar: WorkflowBottomBar(
        child: PrimaryButton(
          label: isClean ? 'Export safe copy' : 'Review fixes',
          icon: isClean
              ? Icons.ios_share_outlined
              : Icons.auto_fix_high_outlined,
          onPressed: isClean
              ? () => ExportBottomSheet.show(context)
              : () => context.push(AppRoutes.fix),
        ),
      ),
    );
  }
}
