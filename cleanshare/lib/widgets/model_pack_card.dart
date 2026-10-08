import 'package:flutter/material.dart';



import '../core/constants/model_pack_art.dart';

import '../core/theme/design_tokens.dart';

import '../domain/marketplace/marketplace_models.dart';

import '../infrastructure/marketplace/marketplace_service.dart';

import 'pack_thumbnail.dart';



/// E-commerce style pack card for a 2-column marketplace grid.

class ModelPackCard extends StatelessWidget {

  const ModelPackCard({

    super.key,

    required this.item,

    required this.onTap,

    required this.onQuickAction,

    this.isDownloading = false,

    this.downloadProgress,

  });



  final MarketplaceItemView item;

  final VoidCallback onTap;

  final VoidCallback onQuickAction;

  final bool isDownloading;

  final double? downloadProgress;



  bool get _isOnDevice {

    final state = item.installState;

    return state == ModelInstallState.installed ||

        state == ModelInstallState.updateAvailable ||

        item.entry.builtin;

  }



  @override

  Widget build(BuildContext context) {

    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    final entry = item.entry;

    final accent = colorScheme.primary;



    return Semantics(

      button: true,

      label: '${entry.name} pack. ${item.statusLabel}. '

          '${ModelPackArt.formatSize(entry.sizeBytes)}.',

      child: Material(

        color: Colors.transparent,

        child: InkWell(

          borderRadius: BorderRadius.circular(AppRadius.lg),

          onTap: onTap,

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Expanded(

                child: ClipRRect(

                  borderRadius: BorderRadius.circular(AppRadius.lg),

                  child: Stack(

                    fit: StackFit.expand,

                    children: [

                      DecoratedBox(

                        decoration: const BoxDecoration(

                          color: Color(0xFF0E0E0E),

                        ),

                        child: Padding(

                          padding: const EdgeInsets.all(AppSpacing.x4),

                          child: PackThumbnail(

                            entry: entry,

                            iconSize: 44,

                            borderRadius: AppRadius.md,

                            fit: BoxFit.contain,

                          ),

                        ),

                      ),

                      if (isDownloading && downloadProgress != null)

                        Positioned(

                          left: AppSpacing.x3,

                          right: AppSpacing.x3,

                          bottom: AppSpacing.x3,

                          child: ClipRRect(

                            borderRadius: BorderRadius.circular(AppRadius.full),

                            child: LinearProgressIndicator(

                              value: downloadProgress!.clamp(0, 1),

                              minHeight: 4,

                              backgroundColor:

                                  colorScheme.surface.withValues(alpha: 0.5),

                              color: accent,

                            ),

                          ),

                        )

                      else if (entry.isOptionalNeuralPack)

                        Positioned(

                          top: AppSpacing.x2,

                          right: AppSpacing.x2,

                          child: _PackBadge(

                            label: 'Optional MB',

                            color: colorScheme.tertiary,

                          ),

                        )

                      else if (entry.builtin)

                        const Positioned(

                          top: AppSpacing.x2,

                          right: AppSpacing.x2,

                          child: _PackBadge(

                            label: 'Built-in',

                            color: AppColors.accent,

                          ),

                        )

                      else if (item.installState ==

                          ModelInstallState.updateAvailable)

                        Positioned(

                          top: AppSpacing.x2,

                          right: AppSpacing.x2,

                          child: _PackBadge(label: 'Update', color: accent),

                        ),

                    ],

                  ),

                ),

              ),

              const SizedBox(height: AppSpacing.x3),

              Text(
                entry.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.x2),
              Text(
                entry.isOptionalNeuralPack ? entry.packBriefLabel : item.statusLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.x1),
              Row(

                children: [

                  Expanded(

                    child: Text(

                      ModelPackArt.formatSize(entry.sizeBytes),

                      style: theme.textTheme.titleSmall?.copyWith(

                        fontWeight: FontWeight.w700,

                        color: accent,

                      ),

                    ),

                  ),

                  _QuickActionButton(

                    isOnDevice: _isOnDevice,

                    isDownloading: isDownloading,

                    accent: accent,

                    muted: colorScheme.onSurfaceVariant,

                    onPressed: onQuickAction,

                  ),

                ],

              ),

            ],

          ),

        ),

      ),

    );

  }

}



class _PackBadge extends StatelessWidget {

  const _PackBadge({required this.label, required this.color});



  final String label;

  final Color color;



  @override

  Widget build(BuildContext context) {

    return Container(

      padding: const EdgeInsets.symmetric(

        horizontal: AppSpacing.x2,

        vertical: AppSpacing.x1,

      ),

      decoration: BoxDecoration(

        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),

        borderRadius: BorderRadius.circular(AppRadius.pill),

      ),

      child: Text(

        label,

        style: Theme.of(context).textTheme.labelSmall?.copyWith(

              color: color,

              fontWeight: FontWeight.w700,

              fontSize: 12,

            ),

      ),

    );

  }

}



class _QuickActionButton extends StatelessWidget {

  const _QuickActionButton({

    required this.isOnDevice,

    required this.isDownloading,

    required this.accent,

    required this.muted,

    required this.onPressed,

  });



  final bool isOnDevice;

  final bool isDownloading;

  final Color accent;

  final Color muted;

  final VoidCallback onPressed;



  @override

  Widget build(BuildContext context) {

    final bg = isOnDevice

        ? accent.withValues(alpha: 0.14)

        : colorSchemeTint(context);



    return Material(

      color: Colors.transparent,

      child: InkWell(

        borderRadius: BorderRadius.circular(50),

        onTap: isDownloading ? null : onPressed,

        child: Container(

          height: 44,

          width: 44,

          decoration: BoxDecoration(

            color: bg,

            shape: BoxShape.circle,

          ),

          child: isDownloading

              ? Padding(

                  padding: const EdgeInsets.all(8),

                  child: CircularProgressIndicator(

                    strokeWidth: 2,

                    color: accent,

                  ),

                )

              : Icon(

                  isOnDevice ? Icons.check_rounded : Icons.download_rounded,

                  size: 18,

                  color: isOnDevice ? accent : muted,

                ),

        ),

      ),

    );

  }



  Color colorSchemeTint(BuildContext context) {
    return Theme.of(context).colorScheme.primary.withValues(alpha: 0.12);
  }

}

