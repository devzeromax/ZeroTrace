import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/animation/app_motion.dart';
import '../../core/audio/app_sound_player.dart';
import '../../core/utils/download_export.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/glass_scene.dart';
import '../../core/theme/glass_tokens.dart';
import '../../models/app_models.dart';
import '../../providers/workflow_provider.dart';
import '../../widgets/glass_hero_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/security_badge.dart';
import '../../widgets/workflow_page.dart';

class ExportSuccessScreen extends ConsumerStatefulWidget {
  const ExportSuccessScreen({super.key});

  @override
  ConsumerState<ExportSuccessScreen> createState() =>
      _ExportSuccessScreenState();
}

class _ExportSuccessScreenState extends ConsumerState<ExportSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = Tween<double>(begin: 0.6, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.spring),
    );
    _fade = AppMotion.fadeIn(_controller);
    _controller.forward();
    // Route-based export success (sheet path plays from the sheet).
    AppSoundPlayer.playExportSuccess();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _downloadFile() async {
    final workflow = ref.read(workflowProvider);
    final fileName = workflow.exportedFileName ?? 'sanitized_file';
    final path = workflow.exportedFilePath;

    if (path == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Export file not found. Try exporting again.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final ok = await DownloadExport.saveToDevice(
      sourcePath: path,
      fileName: fileName,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) AppSoundPlayer.playUiConfirm();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Saved $fileName to device' : 'Save to device cancelled',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workflow = ref.watch(workflowProvider);
    final fileName = workflow.exportedFileName ?? 'sanitized_file';
    final fixCount = workflow.appliedFixCount;
    final colorScheme = Theme.of(context).colorScheme;
    final darkHero =
        GlassTokens.heroUsesDarkForeground(context, scene: GlassScene.export);
    final onHero =
        darkHero ? CosmosColors.pureWhite : colorScheme.onSurface;
    final onHeroMuted = darkHero
        ? onHero.withValues(alpha: 0.72)
        : colorScheme.onSurfaceVariant;

    return WorkflowPage(
      title: 'Export complete',
      currentStep: WorkflowStep.export,
      scene: GlassScene.export,
      showBrandStrip: true,
      centerBody: true,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeSlideIn(
            delay: const Duration(milliseconds: 80),
            child: GlassHeroCard(
              scene: GlassScene.export,
              padding: const EdgeInsets.all(AppSpacing.x8),
              child: Column(
                children: [
                  FadeTransition(
                    opacity: _fade,
                    child: ScaleTransition(
                      scale: _scale,
                      child: AnimatedSuccessCheck(
                        color: colorScheme.secondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x6),
                  Text(
                    'Export complete',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: onHero,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.x3),
                  Text(
                    '$fileName is ready in app storage. '
                    'Save to device picks a folder for your copy.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: onHeroMuted,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.x6),
                  Wrap(
                    spacing: AppSpacing.x2,
                    runSpacing: AppSpacing.x2,
                    alignment: WrapAlignment.center,
                    children: [
                      SecurityBadge(
                        label: '$fixCount fixes applied',
                        icon: Icons.auto_fix_high_outlined,
                        variant: SecurityBadgeVariant.neutral,
                      ),
                      const SecurityBadge(
                        label: 'Manifest saved',
                        icon: Icons.description_outlined,
                        variant: SecurityBadgeVariant.neutral,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomBar: WorkflowBottomBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeSlideIn(
              delay: const Duration(milliseconds: 300),
              child: PrimaryButton(
                label: _isSaving ? 'Saving…' : 'Save to device',
                icon: Icons.download_rounded,
                isLoading: _isSaving,
                onPressed: _isSaving ? null : _downloadFile,
              ),
            ),
            const SizedBox(height: AppSpacing.x3),
            SecondaryButton(
              label: 'Back to home',
              onPressed: () {
                ref.read(workflowProvider.notifier).reset();
                context.go(AppRoutes.home);
              },
            ),
          ],
        ),
      ),
    );
  }
}
