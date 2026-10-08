import 'package:flutter/material.dart';

import 'package:cleanshare/core/animation/app_motion.dart';
import 'package:cleanshare/core/extensions/model_extensions.dart';
import 'package:cleanshare/core/theme/design_tokens.dart';
import 'package:cleanshare/models/app_models.dart';

/// Workflow step rail with animated progress and active-step pulse.
/// Inspired by [pksunny/flutter-ui-and-animations #137-step-progress](https://github.com/pksunny/flutter-ui-and-animations/tree/main/lib/screens/137-step-progress).
class StepProgressRail extends StatefulWidget {
  const StepProgressRail({
    super.key,
    required this.currentStep,
  });

  final WorkflowStep currentStep;

  @override
  State<StepProgressRail> createState() => _StepProgressRailState();
}

class _StepProgressRailState extends State<StepProgressRail>
    with TickerProviderStateMixin {
  late final AnimationController _progress;
  late final AnimationController _pulse;
  late int _stepIndex;

  @override
  void initState() {
    super.initState();
    _stepIndex = WorkflowStep.values.indexOf(widget.currentStep);
    _progress = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..forward();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (!WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
        .disableAnimations) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.value = 0.5;
    }
  }

  @override
  void didUpdateWidget(covariant StepProgressRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextIndex = WorkflowStep.values.indexOf(widget.currentStep);
    if (nextIndex == _stepIndex) return;
    _stepIndex = nextIndex;
    if (MediaQuery.disableAnimationsOf(context)) return;
    _progress.forward(from: 0);
  }

  @override
  void dispose() {
    _progress.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final steps = WorkflowStep.values;
    final currentIndex = steps.indexOf(widget.currentStep);
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label:
          'Workflow step ${currentIndex + 1} of ${steps.length}: ${widget.currentStep.stepLabel}',
      child: AnimatedBuilder(
        animation: Listenable.merge([_progress, _pulse]),
        builder: (context, _) {
          return Row(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                Expanded(
                  child: _StepDot(
                    label: steps[i].stepLabel,
                    isComplete: i < currentIndex,
                    isActive: i == currentIndex,
                    pulse: i == currentIndex ? _pulse.value : 0,
                    enter: _progress.value,
                  ),
                ),
                if (i < steps.length - 1)
                  _StepConnector(
                    filled: i < currentIndex,
                    animating: i == currentIndex - 1,
                    progress: _progress.value,
                    activeColor: colorScheme.primary,
                    inactiveColor: colorScheme.outline,
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _StepConnector extends StatelessWidget {
  const _StepConnector({
    required this.filled,
    required this.animating,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  final bool filled;
  final bool animating;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    final color = filled || animating ? activeColor : inactiveColor;
    final widthFactor = filled
        ? 1.0
        : animating
            ? progress
            : 0.0;

    return SizedBox(
      width: 8,
      height: 2,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: inactiveColor,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: widthFactor.clamp(0.0, 1.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.label,
    required this.isComplete,
    required this.isActive,
    required this.pulse,
    required this.enter,
  });

  final String label;
  final bool isComplete;
  final bool isActive;
  final double pulse;
  final double enter;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isComplete || isActive
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    final activeSurface = colorScheme.primary.withValues(alpha: 0.16);
    final baseSize = isComplete ? 14.0 : (isActive ? 16.0 : 10.0);
    final scale = isActive ? 1 + pulse * 0.08 : (isComplete ? enter : 1.0);

    return Column(
      children: [
        Transform.scale(
          scale: scale,
          child: AnimatedContainer(
            duration: AppDurations.normal,
            curve: AppMotion.spring,
            width: baseSize,
            height: baseSize,
            decoration: BoxDecoration(
              color: isComplete
                  ? color
                  : isActive
                      ? color.withValues(alpha: 0.2)
                      : color.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.28 + pulse * 0.12),
                        blurRadius: 8 + pulse * 6,
                        spreadRadius: pulse,
                      ),
                    ]
                  : null,
            ),
            child: isComplete
                ? Icon(Icons.check, size: 10, color: colorScheme.onPrimary)
                : null,
          ),
        ),
        const SizedBox(height: AppSpacing.x1),
        AnimatedDefaultTextStyle(
          duration: AppDurations.fast,
          curve: AppMotion.defaultCurve,
          style: Theme.of(context).textTheme.labelSmall!.copyWith(
                color: isActive
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
          child: Text(label, textAlign: TextAlign.center),
        ),
        if (isActive) ...[
          const SizedBox(height: AppSpacing.x1),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: AppDurations.normal,
            curve: AppMotion.spring,
            builder: (context, value, _) {
              return Container(
                width: 20 * value,
                height: 3,
                decoration: BoxDecoration(
                  color: activeSurface,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
