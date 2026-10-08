import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';
import 'package:universal_io/io.dart';



import '../../core/platform/platform_storage.dart';

import '../../widgets/export_bottom_sheet.dart';

import '../../core/theme/design_tokens.dart';

import '../../models/app_models.dart';

import '../../providers/workflow_provider.dart';

import '../../widgets/adaptive_content.dart';

import '../../widgets/audit_item.dart';

import '../../widgets/comparison_slider.dart';

import '../../widgets/metadata_details_card.dart';

import '../../core/theme/glass_scene.dart';

import '../../widgets/premium_page.dart';

import '../../widgets/primary_button.dart';

import '../../widgets/security_badge.dart';



class FilePreviewComparisonScreen extends ConsumerStatefulWidget {

  const FilePreviewComparisonScreen({super.key, this.fileId});



  final String? fileId;



  @override

  ConsumerState<FilePreviewComparisonScreen> createState() =>

      _FilePreviewComparisonScreenState();

}



class _FilePreviewComparisonScreenState

    extends ConsumerState<FilePreviewComparisonScreen> {

  var _previewRequested = false;



  @override

  void initState() {

    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => _ensurePreview());

  }



  Future<void> _ensurePreview() async {

    if (_previewRequested) return;

    _previewRequested = true;

    await ref.read(workflowProvider.notifier).refreshLivePreview();

  }



  RiskLevel _riskFromScore(int score) {

    if (score >= 70) return RiskLevel.critical;

    if (score >= 50) return RiskLevel.high;

    if (score >= 30) return RiskLevel.medium;

    if (score > 0) return RiskLevel.low;

    return RiskLevel.none;

  }



  ComparisonImageSource? _beforeImage(WorkflowState workflow) {
    final path = workflow.selectedFile?.localPath;
    if (path != null && PlatformStorage.supportsLocalFileSystem) {
      return ComparisonImageSource.file(path);
    }
    // Never fall back to demo stock photos for a real session.
    return null;
  }

  ComparisonImageSource? _afterImage(WorkflowState workflow) {
    final preview = workflow.previewAfterPath;
    if (preview != null && PlatformStorage.supportsLocalFileSystem) {
      return ComparisonImageSource.file(preview);
    }
    // While generating, or with all blurs off, show the original as "after".
    final path = workflow.selectedFile?.localPath;
    if (path != null && PlatformStorage.supportsLocalFileSystem) {
      return ComparisonImageSource.file(path);
    }
    return null;
  }

  Map<String, String> _metadataFromFindings(
    List<PrivacyFinding> findings,
    DateTime scannedAt,
  ) {
    final map = <String, String>{};
    for (final f in findings.where(WorkflowState.isMetadataFinding)) {
      final key = f.title.trim();
      if (key.isEmpty) continue;
      map[key] = f.description;
    }
    map['Scanned'] = DateFormat('yyyy-MM-dd HH:mm:ss').format(scannedAt.toLocal());
    return map;
  }

  void _openFullPreview(
    BuildContext context, {
    required ComparisonImageSource source,
    required String title,
  }) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x3,
                  AppSpacing.x2,
                  AppSpacing.x3,
                  AppSpacing.x2,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      tooltip: 'Close',
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white24),
              Expanded(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Center(
                    child: _FullPreviewImage(source: source),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  @override

  Widget build(BuildContext context) {

    final workflow = ref.watch(workflowProvider);

    final session = workflow.session;



    ref.listen(workflowProvider.select((s) => s.appliedFixCount), (_, __) {

      ref.read(workflowProvider.notifier).refreshLivePreview();

    });



    if (session == null) {

      return const Scaffold(

        body: Center(child: CircularProgressIndicator()),

      );

    }



    final findings = workflow.findings;

    final originalScore = session.riskScore;

    final projectedScore = workflow.projectedRiskScore;

    final riskLevel = _riskFromScore(originalScore);

    final fileName = session.fileName;

    final fileType = session.fileType;

    final fileSize = session.fileSize;

    final metadata = _metadataFromFindings(findings, session.scannedAt);



    final before = _beforeImage(workflow);

    final after = _afterImage(workflow);

    final hasLivePreview = workflow.previewAfterPath != null;

    final blurCount = workflow.findings.where((f) => f.supportsBlur).length;

    final projectedBlur = workflow.appliedFixCount > 0

        ? workflow.appliedFixCount

        : blurCount;



    return PremiumPage(

      scene: GlassScene.workflow,

      constrainBody: false,

      appBar: GlassAppBar(

        scene: GlassScene.workflow,

        leading: IconButton(

          onPressed: () => context.pop(),

          icon: const Icon(Icons.arrow_back_rounded),

          tooltip: 'Back',

        ),

        title: Text(

          fileName,

          maxLines: 1,

          overflow: TextOverflow.ellipsis,

        ),

        automaticallyImplyLeading: false,

        actions: [

          Padding(

            padding: const EdgeInsets.only(right: AppSpacing.x2),

            child: RiskBadge(level: riskLevel),

          ),

        ],

      ),

      body: Column(

        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [

          Expanded(

            child: SingleChildScrollView(

              child: AdaptiveContent(

                padding: const EdgeInsets.all(AppSpacing.x6),

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.stretch,

                  children: [

                    Text(

                      '$fileType • $fileSize',

                      style: Theme.of(context).textTheme.labelSmall,

                    ),

                    const SizedBox(height: AppSpacing.x4),

                    Text(

                      'Before / after preview',

                      style: Theme.of(context).textTheme.titleSmall?.copyWith(

                            fontWeight: FontWeight.w600,

                          ),

                    ),

                    const SizedBox(height: AppSpacing.x2),

                    Text(

                      hasLivePreview

                          ? workflow.appliedFixCount > 0

                              ? 'Drag the handle to compare your original with $projectedBlur applied fix${projectedBlur == 1 ? '' : 'es'}.'

                              : 'Drag the handle to preview the cleaned result — all $projectedBlur blur region${projectedBlur == 1 ? '' : 's'} applied as if you export now.'

                          : 'Generating cleaned preview…',

                      style: Theme.of(context).textTheme.bodySmall?.copyWith(

                            color: Theme.of(context)

                                .colorScheme

                                .onSurfaceVariant,

                          ),

                    ),

                    const SizedBox(height: AppSpacing.x4),
                    if (before != null && after != null) ...[
                      ComparisonSlider(
                        key: ValueKey(
                          'cmp-${workflow.previewAfterPath ?? 'pending'}-'
                          '${workflow.appliedFixCount}',
                        ),
                        beforeImage: before,
                        afterImage: after,
                        afterLabel: workflow.appliedFixCount > 0
                            ? 'CLEANED'
                            : 'NO BLUR',
                      ),
                      const SizedBox(height: AppSpacing.x3),
                      Wrap(
                        spacing: AppSpacing.x2,
                        runSpacing: AppSpacing.x2,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _openFullPreview(
                              context,
                              source: before,
                              title: 'Original image',
                            ),
                            icon: const Icon(Icons.fullscreen_rounded),
                            label: const Text('View full original'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _openFullPreview(
                              context,
                              source: after,
                              title: workflow.appliedFixCount > 0
                                  ? 'Cleaned image'
                                  : 'Current export (no blur)',
                            ),
                            icon: const Icon(Icons.fullscreen_rounded),
                            label: Text(
                              workflow.appliedFixCount > 0
                                  ? 'View full cleaned'
                                  : 'View current export',
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        'Preview is available for image files scanned on this device.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                    if (!hasLivePreview && before != null) ...[
                      const SizedBox(height: AppSpacing.x4),
                      const Center(child: CircularProgressIndicator()),
                    ],

                    const SizedBox(height: AppSpacing.x6),

                    Row(

                      mainAxisAlignment: MainAxisAlignment.spaceBetween,

                      children: [

                        Text(

                          'Privacy Report',

                          style:

                              Theme.of(context).textTheme.titleSmall?.copyWith(

                                    fontWeight: FontWeight.w600,

                                  ),

                        ),

                        Text(

                          '${findings.length} Risks Detected',

                          style: Theme.of(context).textTheme.labelSmall,

                        ),

                      ],

                    ),

                    const SizedBox(height: AppSpacing.x3),

                    ...findings.map((f) => AuditItem(finding: f)),

                    if (metadata.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.x6),
                      MetadataDetailsCard(entries: metadata),
                    ],

                  ],

                ),

              ),

            ),

          ),

          _ComparisonFooter(

            originalScore: originalScore,

            projectedScore: projectedScore,

            canExport: workflow.canExportSafeCopy,

            onExport: () => ExportBottomSheet.show(context),

          ),

        ],

      ),

    );

  }

}

class _FullPreviewImage extends StatelessWidget {
  const _FullPreviewImage({required this.source});

  final ComparisonImageSource source;

  @override
  Widget build(BuildContext context) {
    final path = source.filePath;
    if (path != null &&
        PlatformStorage.supportsLocalFileSystem &&
        File(path).existsSync()) {
      return Image.file(
        File(path),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const _PreviewUnavailable(),
      );
    }

    final url = source.networkUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        },
        errorBuilder: (_, __, ___) => const _PreviewUnavailable(),
      );
    }

    return const _PreviewUnavailable();
  }
}

class _PreviewUnavailable extends StatelessWidget {
  const _PreviewUnavailable();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.image_not_supported_outlined,
          size: 44,
          color: Colors.white70,
        ),
        const SizedBox(height: AppSpacing.x2),
        Text(
          'Preview unavailable',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }
}



class _ComparisonFooter extends StatelessWidget {

  const _ComparisonFooter({

    required this.originalScore,

    required this.projectedScore,

    required this.canExport,

    required this.onExport,

  });



  final int originalScore;

  final int projectedScore;

  final bool canExport;

  final VoidCallback onExport;



  @override

  Widget build(BuildContext context) {

    final colorScheme = Theme.of(context).colorScheme;

    final improved = projectedScore < originalScore;



    return ColoredBox(

      color: colorScheme.surface,

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [

          Divider(

            height: 1,

            color: colorScheme.outlineVariant,

          ),

          SafeArea(

            top: false,

            child: AdaptiveContent(

              padding: const EdgeInsets.all(AppSpacing.x6),

              child: AdaptiveRowColumn(

                leading: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text(

                      improved ? 'Risk after export' : 'Current risk',

                      style: Theme.of(context).textTheme.labelSmall,

                    ),

                    const SizedBox(height: AppSpacing.x1),

                    if (improved)

                      Row(

                        children: [

                          Text(

                            '$originalScore',

                            style: Theme.of(context)

                                .textTheme

                                .titleMedium

                                ?.copyWith(

                                  color: AppColors.riskHigh,

                                  fontWeight: FontWeight.w700,

                                ),

                          ),

                          const SizedBox(width: AppSpacing.x2),

                          Icon(

                            Icons.arrow_forward_rounded,

                            size: 16,

                            color: colorScheme.onSurfaceVariant,

                          ),

                          const SizedBox(width: AppSpacing.x2),

                          Text(

                            '$projectedScore',

                            style: Theme.of(context)

                                .textTheme

                                .titleMedium

                                ?.copyWith(

                                  color: AppColors.success,

                                  fontWeight: FontWeight.w700,

                                ),

                          ),

                        ],

                      )

                    else

                      Text(

                        '$originalScore',

                        style: Theme.of(context)

                            .textTheme

                            .titleMedium

                            ?.copyWith(

                              color: AppColors.riskHigh,

                              fontWeight: FontWeight.w700,

                            ),

                      ),

                  ],

                ),

                trailing: PrimaryButton(

                  label: 'Export Safe Copy',

                  icon: Icons.security_rounded,

                  expand: false,

                  onPressed: canExport ? onExport : null,

                ),

              ),

            ),

          ),

        ],

      ),

    );

  }

}

