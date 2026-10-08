import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/animation/app_motion.dart';
import '../../core/audio/app_sound_player.dart';
import '../../core/platform/platform_storage.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/glass_scene.dart';
import '../../domain/marketplace/marketplace_models.dart';
import '../../infrastructure/marketplace/neural_pack_diagnostics.dart';
import '../../providers/engine_providers.dart';
import '../../providers/marketplace_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/marketplace_neural_notice.dart';
import '../../widgets/model_pack_card.dart';
import '../../widgets/model_pack_detail_sheet.dart';
import '../../widgets/premium_page.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/user_error_banner.dart';
import '../../widgets/web_marketplace_banner.dart';

/// Scanner pack marketplace — unified 2-column product grid.
class MarketplaceScreen extends ConsumerWidget {
  const MarketplaceScreen({super.key});

  static const _includedOrder = [
    MarketplaceCategory.metadataScanner,
    MarketplaceCategory.developerTools,
    MarketplaceCategory.qrDetection,
  ];

  static const _neuralOrder = [
    MarketplaceCategory.faceDetection,
    MarketplaceCategory.licensePlateDetection,
    MarketplaceCategory.documentScanner,
  ];

  List<MarketplaceItemView> _sortByCategory(
    List<MarketplaceItemView> source,
    List<MarketplaceCategory> order,
  ) {
    final items = <MarketplaceItemView>[];
    for (final category in order) {
      items.addAll(source.where((i) => i.entry.category == category));
    }
    return items;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(marketplaceProvider);
    final notifier = ref.read(marketplaceProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;
    final included = _sortByCategory(state.includedScanners, _includedOrder);
    final neural = _sortByCategory(state.optionalNeuralPacks, _neuralOrder);
    final isEmpty = included.isEmpty && neural.isEmpty;

    return PremiumPage(
      scene: GlassScene.settings,
      constrainBody: false,
      appBar: GlassAppBar(
        scene: GlassScene.settings,
        title: const Text('Pack marketplace'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: notifier.refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.marginMobile,
                AppSpacing.x4,
                AppSpacing.marginMobile,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scanner packs',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.x2),
                    Text(
                      'Catalog',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.x1),
                    Text(
                      'Core privacy scanners are included. Add-on packs are optional.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.x4),
                    const MarketplaceNeuralNotice(),
                    const WebMarketplaceBanner(),
                    if (state.errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.x4),
                      UserErrorBanner(
                        error: state.errorMessage!,
                        scene: GlassScene.settings,
                        onDismiss: () => notifier.clearError(),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.x4),
                    SecondaryButton(
                      label: state.isCheckingUpdates
                          ? 'Checking…'
                          : 'Check for updates',
                      icon: Icons.system_update_outlined,
                      onPressed:
                          state.isCheckingUpdates ? null : notifier.checkUpdates,
                      expand: true,
                    ),
                    const SizedBox(height: AppSpacing.x5),
                  ],
                ),
              ),
            ),
            if (state.isLoading && isEmpty)
              const SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.marginMobile,
                ),
                sliver: SliverToBoxAdapter(
                  child: MarketplaceCatalogSkeleton(),
                ),
              )
            else if (isEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.marginMobile,
                ),
                sliver: SliverToBoxAdapter(
                  child: EmptyStatePanel(
                    scene: GlassScene.settings,
                    icon: Icons.inventory_2_outlined,
                    title: 'No packs in catalog',
                    description: state.errorMessage != null
                        ? 'The catalog could not load. Pull down or tap reload.'
                        : 'No scanner packs are available right now.',
                    action: SecondaryButton(
                      label: 'Reload catalog',
                      icon: Icons.refresh,
                      onPressed: notifier.refresh,
                      expand: true,
                    ),
                  ),
                ),
              )
            else ...[
              if (included.isNotEmpty)
                const SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.marginMobile,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: MarketplaceSectionHeader(
                      title: 'Included — no download',
                      subtitle:
                          'Metadata, QR, PDF/Office headers, and secrets detection.',
                    ),
                  ),
                ),
              if (included.isNotEmpty)
                _PackGrid(
                  items: included,
                  state: state,
                  onTap: (item) =>
                      _openDetail(context, ref, notifier, state, item),
                  onQuickAction: (item) =>
                      _onQuickAction(context, ref, notifier, state, item),
                ),
              if (neural.isNotEmpty)
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.marginMobile,
                    AppSpacing.x6,
                    AppSpacing.marginMobile,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: MarketplaceSectionHeader(
                      title: 'Optional scanner packs',
                      subtitle:
                          'Face blur · license plates · document text review.',
                    ),
                  ),
                ),
              if (neural.isNotEmpty)
                _PackGrid(
                  items: neural,
                  state: state,
                  onTap: (item) =>
                      _openDetail(context, ref, notifier, state, item),
                  onQuickAction: (item) =>
                      _onQuickAction(context, ref, notifier, state, item),
                ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.x8)),
          ],
        ),
      ),
    );
  }

  Future<void> _openDetail(
    BuildContext context,
    WidgetRef ref,
    MarketplaceNotifier notifier,
    MarketplaceState state,
    MarketplaceItemView item,
  ) async {
    String? operationalNote;
    if (item.entry.manifest.isOnnx) {
      final caps = ref.read(engineCapabilitiesProvider);
      final layout = ref.read(zeroTraceLayoutProvider);
      final installed = item.installState == ModelInstallState.installed ||
          item.installState == ModelInstallState.updateAvailable;
      final diagnostics = await NeuralPackDiagnostics.inspectPack(
        layout: layout,
        packId: item.entry.id,
        onnxRuntimeAvailable: caps.onnxRuntimeAvailable,
        installed: installed,
      );
      operationalNote = item.operationalNoteFor(
        onnxRuntimeAvailable: caps.onnxRuntimeAvailable,
        modelBytesOnDisk: diagnostics.modelBytes,
      );
    }

    if (!context.mounted) return;
    showModelPackDetailSheet(
      context: context,
      item: item,
      isDownloading: state.activeDownloadId == item.entry.id,
      downloadProgress: state.activeDownloadId == item.entry.id
          ? state.downloadProgress
          : null,
      onDownload: () => _onDownload(context, ref, notifier, item),
      onUpdate: () => _onUpdate(context, ref, notifier, item),
      onRemove: () => _onRemove(context, notifier, item),
      operationalNote: operationalNote,
    );
  }

  void _onQuickAction(
    BuildContext context,
    WidgetRef ref,
    MarketplaceNotifier notifier,
    MarketplaceState state,
    MarketplaceItemView item,
  ) {
    if (item.entry.builtin || item.entry.isIncludedScanner) {
      _openDetail(context, ref, notifier, state, item);
      return;
    }

    switch (item.installState) {
      case ModelInstallState.notInstalled:
      case ModelInstallState.failed:
        _onDownload(context, ref, notifier, item);
      case ModelInstallState.updateAvailable:
        _onUpdate(context, ref, notifier, item);
      case ModelInstallState.installed:
        _openDetail(context, ref, notifier, state, item);
      case ModelInstallState.downloading:
        break;
    }
  }

  Future<void> _onDownload(
    BuildContext context,
    WidgetRef ref,
    MarketplaceNotifier notifier,
    MarketplaceItemView item,
  ) async {
    if (!PlatformStorage.supportsLocalFileSystem) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pack downloads need the Windows desktop or mobile app. '
            'Built-in scanners already work in the browser.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    if (item.entry.isOptionalNeuralPack) {
      final confirmed = await confirmNeuralPackDownload(
        context,
        packName: item.entry.name,
        useCase: item.entry.packBriefLabel,
        sizeBytes: item.entry.sizeBytes,
      );
      if (!confirmed || !context.mounted) return;
    }

    final error = await notifier.download(item.entry.id);
    if (!context.mounted) return;

    if (error == null) AppSoundPlayer.playUiConfirm();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? '${item.entry.name} installed'),
        duration: Duration(seconds: error == null ? 3 : 6),
      ),
    );
  }

  Future<void> _onUpdate(
    BuildContext context,
    WidgetRef ref,
    MarketplaceNotifier notifier,
    MarketplaceItemView item,
  ) async {
    final error = await notifier.update(item.entry.id);
    if (!context.mounted) return;

    if (error == null) AppSoundPlayer.playUiConfirm();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? '${item.entry.name} updated'),
        duration: Duration(seconds: error == null ? 3 : 6),
      ),
    );
  }

  Future<void> _onRemove(
    BuildContext context,
    MarketplaceNotifier notifier,
    MarketplaceItemView item,
  ) async {
    if (item.entry.builtin) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${item.entry.name}?'),
        content: const Text(
          'This deletes the pack from your device. You can download it again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final ok = await notifier.remove(item.entry.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Pack removed' : 'Could not remove pack'),
          ),
        );
      }
    }
  }
}

class _PackGrid extends StatelessWidget {
  const _PackGrid({
    required this.items,
    required this.state,
    required this.onTap,
    required this.onQuickAction,
  });

  final List<MarketplaceItemView> items;
  final MarketplaceState state;
  final void Function(MarketplaceItemView item) onTap;
  final void Function(MarketplaceItemView item) onQuickAction;

  @override
  Widget build(BuildContext context) {
    final crossAxisCount =
        MediaQuery.sizeOf(context).width < 400 ? 1 : 2;
    final aspectRatio = crossAxisCount == 1 ? 2.35 : 0.62;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 20,
          crossAxisSpacing: 16,
          childAspectRatio: aspectRatio,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = items[index];
            final delay = AppMotion.staggerDelay(index);
            return FadeSlideIn(
              delay: delay,
              child: ModelPackCard(
                item: item,
                isDownloading: state.activeDownloadId == item.entry.id,
                downloadProgress: state.activeDownloadId == item.entry.id
                    ? state.downloadProgress
                    : null,
                onTap: () => onTap(item),
                onQuickAction: () => onQuickAction(item),
              ),
            );
          },
          childCount: items.length,
        ),
      ),
    );
  }
}

