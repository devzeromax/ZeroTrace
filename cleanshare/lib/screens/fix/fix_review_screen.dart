import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';
import 'package:universal_io/io.dart';

import '../../core/platform/platform_storage.dart';
import '../../core/routing/app_routes.dart';
import '../../core/utils/download_export.dart';
import '../../widgets/export_bottom_sheet.dart';
import '../../core/routing/workflow_navigation.dart';
import '../../core/theme/design_tokens.dart';
import '../../models/app_models.dart';
import '../../providers/workflow_provider.dart';
import '../../widgets/finding_row.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/undo_snack_bar.dart';
import '../../widgets/workflow_page.dart';
class FixReviewScreen extends ConsumerStatefulWidget {

  const FixReviewScreen({super.key});



  @override

  ConsumerState<FixReviewScreen> createState() => _FixReviewScreenState();

}



class _FixReviewScreenState extends ConsumerState<FixReviewScreen> {
  var _isSavingExport = false;

  @override
  void initState() {

    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {

      ref.read(workflowProvider.notifier).refreshLivePreview();

    });

  }



  @override

  Widget build(BuildContext context) {

    final workflow = ref.watch(workflowProvider);

    final findings = workflow.findings;

    final appliedCount = workflow.appliedFixCount;

    final notifier = ref.read(workflowProvider.notifier);

    final localPath = workflow.selectedFile?.localPath;
    final hasSource = localPath != null &&
        PlatformStorage.supportsLocalFileSystem &&
        File(localPath).existsSync();
    final canExport = workflow.canExportSafeCopy;
    final canSaveExport = workflow.canSaveExistingExport &&
        workflow.exportedFilePath != null &&
        (!PlatformStorage.supportsLocalFileSystem ||
            File(workflow.exportedFilePath!).existsSync());

    Future<void> saveExistingExport() async {
      final path = workflow.exportedFilePath;
      final name = workflow.existingExportFileName ?? 'sanitized_file';
      if (path == null) return;
      setState(() => _isSavingExport = true);
      final ok = await DownloadExport.saveToDevice(
        sourcePath: path,
        fileName: name,
      );
      if (!mounted) return;
      setState(() => _isSavingExport = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? 'Saved $name to your device' : 'Save cancelled',
          ),
        ),
      );
    }

    return WorkflowPage(

      title: 'Review fixes',

      currentStep: WorkflowStep.fix,

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
          if (!hasSource && !canSaveExport)
            _HistoryNoticeBanner(
              message:
                  'The original file is no longer on this device. Scan it again to export a new copy.',
              actionLabel: 'Scan again',
              onAction: () => context.go(AppRoutes.upload),
            )
          else if (!hasSource && canSaveExport)
            _HistoryNoticeBanner(
              message:
                  'Your sanitized copy is still saved on this device. Save it below, or scan the file again to re-export with new fixes.',
              actionLabel: 'Scan again',
              onAction: () => context.go(AppRoutes.upload),
              tone: _NoticeTone.info,
            ),

          if (!hasSource && !canSaveExport)
            const SizedBox(height: AppSpacing.x4)
          else if (!hasSource)
            const SizedBox(height: AppSpacing.x4),

          Row(

            children: [

              Expanded(

                child: Text(

                  '$appliedCount of ${findings.length} fixes selected',

                  style: Theme.of(context).textTheme.bodyLarge,

                ),

              ),

              TextButton(

                onPressed: () {
                  final snapshot = {
                    for (final f in ref.read(workflowProvider).findings)
                      f.id: f.isFixed,
                  };
                  notifier.applyAllFixes();
                  UndoSnackBar.show(
                    context,
                    message: 'All fixes applied',
                    onUndo: () {
                      for (final entry in snapshot.entries) {
                        notifier.toggleFinding(entry.key, entry.value);
                      }
                    },
                  );
                },

                child: const Text('Apply all fixes'),

              ),

            ],

          ),

          const SizedBox(height: AppSpacing.x4),

          Material(

            color: Colors.transparent,

            child: InkWell(

              onTap: () => context.push(AppRoutes.fixPreview),

              borderRadius: BorderRadius.circular(AppRadius.md),

              child: Container(

                height: 180,

                width: double.infinity,

                decoration: BoxDecoration(

                  color: Theme.of(context)

                      .colorScheme

                      .surfaceContainerHighest

                      .withValues(alpha: 0.5),

                  borderRadius: BorderRadius.circular(AppRadius.md),

                ),

                child: ClipRRect(

                  borderRadius: BorderRadius.circular(AppRadius.md),

                  child: Stack(

                    fit: StackFit.expand,

                    children: [

                      if (hasSource)

                        Image.file(

                          File(localPath),

                          fit: BoxFit.cover,

                          errorBuilder: (_, __, ___) => _previewPlaceholder(),

                        )

                      else

                        _previewPlaceholder(),

                      Positioned(

                        left: 0,

                        right: 0,

                        bottom: 0,

                        child: Container(

                          padding: const EdgeInsets.all(AppSpacing.x3),

                          color: Colors.black.withValues(alpha: 0.55),

                          child: Row(

                            children: [

                              const Icon(

                                Icons.compare_outlined,

                                color: Colors.white,

                                size: 20,

                              ),

                              const SizedBox(width: AppSpacing.x2),

                              Expanded(

                                child: Text(

                                  hasSource

                                      ? (appliedCount > 0

                                          ? 'Live preview ready — tap to compare'

                                          : 'Tap to open comparison view')

                                      : canSaveExport

                                          ? 'Original unavailable — view saved export details'

                                          : 'Preview unavailable — scan file again',

                                  style: Theme.of(context)

                                      .textTheme

                                      .labelMedium

                                      ?.copyWith(color: Colors.white),

                                ),

                              ),

                              const Icon(

                                Icons.chevron_right_rounded,

                                color: Colors.white,

                              ),

                            ],

                          ),

                        ),

                      ),

                    ],

                  ),

                ),

              ),

            ),

          ),

          const SizedBox(height: AppSpacing.x6),

          Text(
            'Fix checklist',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: AppSpacing.x2),

          ...findings.map(

            (finding) => FindingRow(

              finding: finding,

              showFixToggle: true,

              onToggleFix: (value) =>

                  notifier.toggleFinding(finding.id, value),

            ),

          ),

        ],

      ),

      bottomBar: WorkflowBottomBar(

        child: Column(

          mainAxisSize: MainAxisSize.min,

          children: [

            if (canSaveExport) ...[
              SecondaryButton(
                label: _isSavingExport ? 'Saving…' : 'Save previous export',
                icon: Icons.download_rounded,
                onPressed: _isSavingExport ? null : saveExistingExport,
              ),
              const SizedBox(height: AppSpacing.x3),
            ],

            SecondaryButton(

              label: 'Back to audit',

              onPressed: () => WorkflowNavigation.popOrHome(context),

            ),

            const SizedBox(height: AppSpacing.x3),

            PrimaryButton(

              label: workflow.session?.isExported == true
                  ? 'Re-export safe copy'
                  : 'Export safe copy',

              icon: Icons.security_rounded,

              onPressed: canExport ? () => ExportBottomSheet.show(context) : null,

            ),

            if (!canExport && hasSource)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.x2),
                child: Text(
                  'Select at least one fix, or enable blur/metadata options.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),

          ],

        ),

      ),

    );

  }



  Widget _previewPlaceholder() {

    return Column(

      mainAxisAlignment: MainAxisAlignment.center,

      children: [

        const Icon(Icons.compare_outlined, size: 32),

        const SizedBox(height: AppSpacing.x2),

        Text(

          'Before / after preview',

          style: Theme.of(context).textTheme.bodyMedium,

        ),

      ],

    );

  }

}

enum _NoticeTone { warning, info }

class _HistoryNoticeBanner extends StatelessWidget {
  const _HistoryNoticeBanner({
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.tone = _NoticeTone.warning,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final _NoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = tone == _NoticeTone.warning
        ? scheme.errorContainer
        : scheme.primaryContainer;
    final fg = tone == _NoticeTone.warning
        ? scheme.onErrorContainer
        : scheme.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: fg),
          ),
          const SizedBox(height: AppSpacing.x3),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

