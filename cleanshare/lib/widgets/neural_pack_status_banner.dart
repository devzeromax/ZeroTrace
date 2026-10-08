import 'package:flutter/material.dart';

import '../core/theme/design_tokens.dart';
import '../infrastructure/marketplace/neural_pack_diagnostics.dart';
import 'glass_surface.dart';
import '../core/theme/glass_scene.dart';

/// Renders one or more inactive neural-pack notices.
class InactiveNeuralPackBannerList extends StatelessWidget {
  const InactiveNeuralPackBannerList({
    super.key,
    required this.diagnostics,
    this.compact = false,
  });

  final List<NeuralPackDiagnostics> diagnostics;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (diagnostics.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (var i = 0; i < diagnostics.length; i++) ...[
          if (i > 0) SizedBox(height: compact ? AppSpacing.x3 : AppSpacing.x3),
          NeuralPackStatusBanner(
            diagnostics: diagnostics[i],
            compact: compact,
          ),
        ],
      ],
    );
  }
}

/// Explains when an optional neural pack is installed but cannot scan yet.
class NeuralPackStatusBanner extends StatelessWidget {
  const NeuralPackStatusBanner({
    super.key,
    required this.diagnostics,
    this.compact = false,
  });

  final NeuralPackDiagnostics diagnostics;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!diagnostics.installed || diagnostics.isOperational) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final message = diagnostics.userMessage;

    if (compact) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.x3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              size: 18,
              color: colorScheme.tertiary,
            ),
            const SizedBox(width: AppSpacing.x2),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
              ),
            ),
          ],
        ),
      );
    }

    return GlassSurface(
      scene: GlassScene.workflow,
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.psychology_outlined,
            color: colorScheme.tertiary,
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  diagnostics.displayTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.x1),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
