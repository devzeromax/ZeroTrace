import 'package:flutter/material.dart';

import '../core/theme/design_tokens.dart';
import '../models/app_models.dart';
import 'step_progress_rail.dart';
import 'zerotrace_logo.dart';

/// Persistent workflow header — brand strip + step rail for root-stack screens.
class WorkflowChrome extends StatelessWidget {
  const WorkflowChrome({
    super.key,
    required this.currentStep,
  });

  final WorkflowStep currentStep;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _BrandStrip(),
        const SizedBox(height: AppSpacing.x4),
        StepProgressRail(currentStep: currentStep),
      ],
    );
  }
}

class _BrandStrip extends StatelessWidget {
  const _BrandStrip();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.x3),
      child: Row(
        children: [
          ZeroTraceLogo(size: 24, compact: true),
        ],
      ),
    );
  }
}
