import 'package:flutter/material.dart';

import '../core/theme/design_tokens.dart';
import '../core/theme/glass_scene.dart';
import 'glass_surface.dart';

class ExportStatCard extends StatelessWidget {
  const ExportStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      scene: GlassScene.export,
      intensity: 0.45,
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: AppSpacing.x1),
          Text(
            value,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: valueColor,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
