import 'package:flutter/material.dart';

import '../core/theme/design_tokens.dart';
import '../core/theme/glass_scene.dart';
import '../core/theme/theme_surfaces.dart';
import 'glass_surface.dart';

class EmptyStatePanel extends StatelessWidget {
  const EmptyStatePanel({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.folder_open_outlined,
    this.action,
    this.scene,
  });

  final String title;
  final String description;
  final IconData icon;
  final Widget? action;
  final GlassScene? scene;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final useGlass = scene != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Semantics(
                header: true,
                label: '$title. $description',
                child: Column(
                  children: [
                    if (useGlass)
                      GlassSurface(
                        scene: scene,
                        borderRadius: AppRadius.md,
                        padding: const EdgeInsets.all(AppSpacing.x4),
                        child: Icon(
                          icon,
                          size: 28,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      )
                    else
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: ThemeSurfaces.cardElevated(context),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Icon(
                          icon,
                          size: 28,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: AppSpacing.x6),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.x2),
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                    ),
                  ],
                ),
              ),
              if (action != null) ...[
                const SizedBox(height: AppSpacing.x6),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
