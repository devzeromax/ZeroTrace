import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/user_facing_error.dart';
import '../domain/marketplace/marketplace_models.dart';
import '../infrastructure/storage/zerotrace_paths.dart';
import 'engine_providers.dart';
import 'neural_pack_status_provider.dart';

/// Marketplace UI state — catalog, downloads, updates.
class MarketplaceState {
  const MarketplaceState({
    this.items = const [],
    this.isLoading = true,
    this.activeDownloadId,
    this.downloadProgress = 0,
    this.isCheckingUpdates = false,
    this.errorMessage,
  });

  final List<MarketplaceItemView> items;
  final bool isLoading;
  final String? activeDownloadId;
  final double downloadProgress;
  final bool isCheckingUpdates;
  final String? errorMessage;

  MarketplaceState copyWith({
    List<MarketplaceItemView>? items,
    bool? isLoading,
    String? activeDownloadId,
    bool clearDownload = false,
    double? downloadProgress,
    bool? isCheckingUpdates,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MarketplaceState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      activeDownloadId:
          clearDownload ? null : (activeDownloadId ?? this.activeDownloadId),
      downloadProgress: downloadProgress ?? this.downloadProgress,
      isCheckingUpdates: isCheckingUpdates ?? this.isCheckingUpdates,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  Map<MarketplaceCategory, List<MarketplaceItemView>> get grouped {
    final map = <MarketplaceCategory, List<MarketplaceItemView>>{};
    for (final item in items) {
      map.putIfAbsent(item.entry.category, () => []).add(item);
    }
    return map;
  }

  List<MarketplaceItemView> get includedScanners =>
      items.where((i) => i.entry.isIncludedScanner).toList();

  List<MarketplaceItemView> get optionalNeuralPacks =>
      items.where((i) => i.entry.isOptionalNeuralPack).toList();
}

class MarketplaceNotifier extends Notifier<MarketplaceState> {
  MarketplaceService get _service => ref.read(marketplaceServiceProvider);

  @override
  MarketplaceState build() {
    // ponytail: skip eager refresh when no Flutter binding exists (plain unit tests).
    // Upgrade path: inject an explicit scheduler if provider bootstrap grows.
    var hasWidgetsBinding = true;
    try {
      WidgetsBinding.instance;
    } catch (_) {
      hasWidgetsBinding = false;
    }
    if (hasWidgetsBinding) {
      Future.microtask(refresh);
    }
    return const MarketplaceState();
  }

  Future<void> refresh({bool keepError = false}) async {
    final preservedError = keepError ? state.errorMessage : null;
    state = state.copyWith(isLoading: true, clearError: !keepError);
    try {
      await ZeroTracePaths.ensureInitialized();
      try {
        await ref.read(engineBootstrapProvider.future);
      } catch (_) {
        // Offline / engine missing — still show built-in packs.
      }
      final items = await _service.listItems();
      state = state.copyWith(
        items: items,
        isLoading: false,
        errorMessage: preservedError,
        clearError: preservedError == null,
      );
    } catch (e, stack) {
      debugPrint('Marketplace refresh failed: $e\n$stack');
      state = state.copyWith(
        isLoading: false,
        errorMessage: preservedError ?? UserFacingError.message(e),
      );
    }
  }

  Future<void> checkUpdates() async {
    state = state.copyWith(isCheckingUpdates: true, clearError: true);
    try {
      await ZeroTracePaths.ensureInitialized();
      try {
        await ref.read(engineBootstrapProvider.future);
        await _service.checkUpdates();
      } catch (e) {
        debugPrint('Marketplace update check failed: $e');
      }
    } finally {
      state = state.copyWith(isCheckingUpdates: false);
    }
    await refresh();
  }

  /// Returns `null` on success, or a user-facing error message on failure.
  Future<String?> download(String modelId) async {
    state = state.copyWith(
      activeDownloadId: modelId,
      downloadProgress: 0,
      clearError: true,
    );
    try {
      await ZeroTracePaths.ensureInitialized();
      try {
        await ref.read(engineBootstrapProvider.future);
      } catch (e) {
        debugPrint('Engine bootstrap skipped for pack install: $e');
      }
      await _service.download(
        modelId,
        onProgress: (p) {
          state = state.copyWith(downloadProgress: p);
        },
      );
      ref.invalidate(marketplaceItemsProvider);
      ref.invalidate(scanPipelineProvider);
      ref.invalidate(inactiveNeuralPackDiagnosticsProvider);
      ref.invalidate(pluginDiscoveryProvider);
      await refresh();
      return null;
    } catch (e, stack) {
      debugPrint('Pack download failed: $e\n$stack');
      final message = UserFacingError.message(e);
      state = state.copyWith(errorMessage: message);
      await refresh(keepError: true);
      return message;
    } finally {
      state = state.copyWith(clearDownload: true);
    }
  }

  Future<String?> update(String modelId) => download(modelId);

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<bool> remove(String modelId) async {
    try {
      await ref.read(engineBootstrapProvider.future);
      await _service.remove(modelId);
      ref.invalidate(marketplaceItemsProvider);
      ref.invalidate(scanPipelineProvider);
      ref.invalidate(inactiveNeuralPackDiagnosticsProvider);
      ref.invalidate(pluginDiscoveryProvider);
      await refresh();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: UserFacingError.message(e));
      return false;
    }
  }
}

final marketplaceProvider =
    NotifierProvider<MarketplaceNotifier, MarketplaceState>(
  MarketplaceNotifier.new,
);
