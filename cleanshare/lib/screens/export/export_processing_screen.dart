import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/animation/app_motion.dart';
import '../../core/constants/app_assets.dart';
import '../../core/routing/app_routes.dart';
import '../../core/routing/workflow_navigation.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/glass_scene.dart';
import '../../core/utils/export_status_steps.dart';
import '../../core/utils/user_facing_error.dart';
import '../../models/app_models.dart';
import '../../providers/workflow_provider.dart';
import '../../widgets/glass_surface.dart';
import '../../widgets/fluid_progress_bar.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/workflow_page.dart';

class ExportProcessingScreen extends ConsumerStatefulWidget {
  const ExportProcessingScreen({super.key});

  @override
  ConsumerState<ExportProcessingScreen> createState() =>
      _ExportProcessingScreenState();
}

class _ExportProcessingScreenState extends ConsumerState<ExportProcessingScreen> {
  bool _running = true;
  String? _errorMessage;
  int _statusIndex = 0;
  Timer? _statusTimer;
  List<String> _statusSteps = ExportStatusSteps.forSession(null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startExport());
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<bool> _confirmCancel() async {
    if (!_running || _errorMessage != null) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel export?'),
        content: const Text(
          'Sanitization is still running on your device. Leave now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _beginStatusUpdates() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(AppDurations.exportStatusStep, (_) {
      if (!mounted || _errorMessage != null) return;
      setState(() {
        _statusIndex = (_statusIndex + 1).clamp(0, _statusSteps.length - 1);
      });
    });
  }

  Future<void> _startExport() async {
    final session = ref.read(workflowProvider).session;
    setState(() {
      _running = true;
      _errorMessage = null;
      _statusIndex = 0;
      _statusSteps = ExportStatusSteps.forSession(session);
    });
    _beginStatusUpdates();

    final startedAt = DateTime.now();
    try {
      await ref.read(workflowProvider.notifier).exportSanitizedCopy();

      final elapsed = DateTime.now().difference(startedAt);
      final remaining = AppDurations.exportProcessingMinimum - elapsed;
      if (remaining > Duration.zero) {
        await Future<void>.delayed(remaining);
      }

      if (!mounted) return;
      _statusTimer?.cancel();
      setState(() => _running = false);
      context.pushReplacement(AppRoutes.exportSuccess);
    } catch (e) {
      if (!mounted) return;
      _statusTimer?.cancel();
      setState(() {
        _running = false;
        _errorMessage = UserFacingError.message(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusText = _errorMessage == null
        ? _statusSteps[_statusIndex.clamp(0, _statusSteps.length - 1)]
        : _errorMessage!;

    return WorkflowPage(
      title: 'Processing',
      currentStep: WorkflowStep.export,
      scene: GlassScene.export,
      leading: WorkflowCloseButton(
        onPressed: () async {
          final leave = await _confirmCancel();
          if (!mounted || !leave) return;
          WorkflowNavigation.closeExport(this.context);
        },
      ),
      centerBody: true,
      body: SingleChildScrollView(
        child: GlassSurface(
          scene: GlassScene.export,
          intensity: 0.3,
          padding: const EdgeInsets.all(AppSpacing.x6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: Image.asset(
                  AppAssets.processingPalm,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Padding(
                    padding: const EdgeInsets.all(AppSpacing.x6),
                    child: Icon(
                      Icons.verified_user_outlined,
                      size: 96,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.x5),
              Text(
                'Sanitizing on your device…',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.x2),
              Text(
                _errorMessage == null
                    ? 'Your file stays on this device while we prepare a safe copy.'
                    : 'Something interrupted processing. Retry to continue.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.x5),
              if (_errorMessage == null) ...[
                FluidProgressBar(
                  progress: (_statusIndex + 1) / _statusSteps.length,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: AppSpacing.x3),
                Semantics(
                  liveRegion: true,
                  label: statusText,
                  child: TextFlipReveal(
                    text: statusText,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  _running
                      ? 'Processing securely on your device'
                      : 'Finishing up…',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ] else ...[
                Semantics(
                  liveRegion: true,
                  label: _errorMessage!,
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.x4),
                PrimaryButton(
                  label: 'Retry processing',
                  onPressed: _startExport,
                ),
                const SizedBox(height: AppSpacing.x2),
                SecondaryButton(
                  label: 'Back to export options',
                  onPressed: () => context.pop(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
