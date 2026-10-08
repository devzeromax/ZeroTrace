import 'package:flutter/material.dart';

import '../core/constants/model_pack_art.dart';
import '../core/theme/design_tokens.dart';
import '../domain/marketplace/marketplace_models.dart';
import '../infrastructure/marketplace/marketplace_service.dart';
import 'pack_thumbnail.dart';
import 'primary_button.dart';
import 'secondary_button.dart';
import 'security_badge.dart';

/// Full pack details — opened from grid card tap.
Future<void> showModelPackDetailSheet({
  required BuildContext context,
  required MarketplaceItemView item,
  required bool isDownloading,
  required double? downloadProgress,
  required VoidCallback onDownload,
  required VoidCallback onUpdate,
  required VoidCallback onRemove,
  String? operationalNote,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _ModelPackDetailSheet(
      item: item,
      isDownloading: isDownloading,
      downloadProgress: downloadProgress,
      onDownload: onDownload,
      onUpdate: onUpdate,
      onRemove: onRemove,
      operationalNote: operationalNote,
    ),
  );
}

class _ModelPackDetailSheet extends StatelessWidget {
  const _ModelPackDetailSheet({
    required this.item,
    required this.isDownloading,
    required this.downloadProgress,
    required this.onDownload,
    required this.onUpdate,
    required this.onRemove,
    this.operationalNote,
  });

  final MarketplaceItemView item;
  final bool isDownloading;
  final double? downloadProgress;
  final VoidCallback onDownload;
  final VoidCallback onUpdate;
  final VoidCallback onRemove;
  final String? operationalNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final entry = item.entry;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.x5,
        0,
        AppSpacing.x5,
        AppSpacing.x5 + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: PackThumbnail(
                  entry: entry,
                  iconSize: 36,
                  borderRadius: AppRadius.md,
                ),
              ),
              const SizedBox(width: AppSpacing.x4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x1),
                    Text(
                      entry.category.label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x2),
                    SecurityBadge(
                      label: item.statusLabel,
                      variant: _badgeVariant(item.installState),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x4),
          Text(
            entry.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.x4),
          Wrap(
            spacing: AppSpacing.x4,
            runSpacing: AppSpacing.x2,
            children: [
                  _MetaLine(
                    label: 'Use case',
                    value: entry.isOptionalNeuralPack
                        ? entry.packBriefLabel
                        : entry.category.label,
                  ),
                  _MetaLine(label: 'Delivery', value: item.deliveryLabel),
              _MetaLine(label: 'Size', value: ModelPackArt.formatSize(entry.sizeBytes)),
              _MetaLine(label: 'Version', value: entry.version),
              _MetaLine(label: 'By', value: entry.developer),
              _MetaLine(label: 'License', value: entry.license),
            ],
          ),
          if (operationalNote != null) ...[
            const SizedBox(height: AppSpacing.x3),
            Text(
              operationalNote!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
          if (isDownloading && downloadProgress != null) ...[
            const SizedBox(height: AppSpacing.x4),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                value: downloadProgress!.clamp(0, 1),
                minHeight: 6,
                backgroundColor: colorScheme.surfaceContainerHighest,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.x1),
            Text(
              '${(downloadProgress! * 100).round()}% downloaded',
              style: theme.textTheme.labelSmall,
            ),
          ],
          const SizedBox(height: AppSpacing.x5),
          _Actions(
            item: item,
            isDownloading: isDownloading,
            onDownload: onDownload,
            onUpdate: onUpdate,
            onRemove: onRemove,
          ),
        ],
      ),
    );
  }

  SecurityBadgeVariant _badgeVariant(ModelInstallState state) =>
      switch (state) {
        ModelInstallState.installed => SecurityBadgeVariant.success,
        ModelInstallState.updateAvailable => SecurityBadgeVariant.accent,
        ModelInstallState.failed => SecurityBadgeVariant.accent,
        _ => SecurityBadgeVariant.neutral,
      };
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $value',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.item,
    required this.isDownloading,
    required this.onDownload,
    required this.onUpdate,
    required this.onRemove,
  });

  final MarketplaceItemView item;
  final bool isDownloading;
  final VoidCallback onDownload;
  final VoidCallback onUpdate;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final entry = item.entry;
    final state = item.installState;

    if (entry.builtin && state == ModelInstallState.installed) {
      return Text(
        'Built into ZeroTrace — always available offline.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      );
    }

    if (isDownloading) {
      return const PrimaryButton(
        label: 'Downloading…',
        onPressed: null,
        isLoading: true,
      );
    }

    return switch (state) {
      ModelInstallState.notInstalled || ModelInstallState.failed => PrimaryButton(
          label: entry.isOptionalNeuralPack
              ? 'Download neural model'
              : 'Download pack',
          icon: Icons.download_rounded,
          onPressed: () {
            Navigator.pop(context);
            onDownload();
          },
        ),
      ModelInstallState.updateAvailable => Row(
          children: [
            Expanded(
              child: PrimaryButton(
                label: 'Update',
                icon: Icons.system_update_alt_rounded,
                onPressed: () {
                  Navigator.pop(context);
                  onUpdate();
                },
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: SecondaryButton(
                label: 'Remove',
                onPressed: entry.builtin
                    ? null
                    : () {
                        Navigator.pop(context);
                        onRemove();
                      },
                expand: true,
              ),
            ),
          ],
        ),
      ModelInstallState.installed => SecondaryButton(
          label: 'Remove from device',
          onPressed: entry.builtin ? null : () {
              Navigator.pop(context);
              onRemove();
            },
          expand: true,
        ),
      ModelInstallState.downloading => const SizedBox.shrink(),
    };
  }
}
