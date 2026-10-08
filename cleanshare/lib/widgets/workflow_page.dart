import 'package:flutter/material.dart';

import '../core/theme/design_tokens.dart';
import '../core/theme/glass_scene.dart';
import '../core/theme/glass_tokens.dart';
import '../models/app_models.dart';
import 'premium_page.dart';
import 'step_progress_rail.dart';
import 'workflow_chrome.dart';

/// Standard layout for Upload → Scan → Audit → Fix → Export flow.
///
/// Fixes app-bar overlap by keeping the step rail and body below the toolbar.
class WorkflowPage extends StatelessWidget {
  const WorkflowPage({
    super.key,
    required this.title,
    required this.currentStep,
    required this.body,
    this.leading,
    this.bottomBar,
    this.scene = GlassScene.workflow,
    this.showBrandStrip = false,
    this.centerBody = false,
  });

  final String title;
  final WorkflowStep currentStep;
  final Widget body;
  final Widget? leading;
  final Widget? bottomBar;
  final GlassScene scene;
  final bool showBrandStrip;
  final bool centerBody;

  @override
  Widget build(BuildContext context) {
    final stepHeader = showBrandStrip
        ? WorkflowChrome(currentStep: currentStep)
        : StepProgressRail(currentStep: currentStep);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4,
            AppSpacing.x2,
            AppSpacing.x4,
            AppSpacing.x4,
          ),
          child: stepHeader,
        ),
        Expanded(
          child: centerBody
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x4,
                  ),
                  child: Center(child: body),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x4,
                  ),
                  child: body,
                ),
        ),
      ],
    );

    return PremiumPage(
      scene: scene,
      constrainBody: false,
      appBar: GlassAppBar(
        scene: scene,
        title: Text(title),
        leading: leading,
        automaticallyImplyLeading: false,
      ),
      body: content,
      bottomNavigationBar: bottomBar,
    );
  }
}

/// Pinned bottom CTA bar used across workflow steps.
class WorkflowBottomBar extends StatelessWidget {
  const WorkflowBottomBar({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final useGlass = GlassTokens.useGlass(context);
    final sigma = GlassTokens.blurSigma(context, override: 14, scene: GlassScene.workflow);

    return ClipRect(
      child: useGlass && sigma > 0
          ? BackdropFilter(
              filter: GlassTokens.blurFilter(context, sigma: sigma),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: GlassTokens.chromeFill(
                    context,
                    scene: GlassScene.workflow,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.x4),
                    child: child,
                  ),
                ),
              ),
            )
          : ColoredBox(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.x4),
                  child: child,
                ),
              ),
            ),
    );
  }
}
