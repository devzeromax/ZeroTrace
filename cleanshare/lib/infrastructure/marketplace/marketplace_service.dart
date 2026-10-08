import '../../core/platform/platform_storage.dart';
import '../../domain/marketplace/marketplace_models.dart';
import '../storage/installed_models_store.dart';
import '../storage/zerotrace_paths.dart';
import 'model_download_manager.dart';
import 'model_update_manager.dart';
import 'neural_pack_diagnostics.dart';

/// Marketplace facade — catalog, install state, downloads, updates.
class MarketplaceService {
  MarketplaceService({
    required MarketplaceCatalogSource catalogSource,
    required InstalledModelsStore installedStore,
    required ModelDownloadManager downloadManager,
    required ModelUpdateManager updateManager,
  })  : _catalogSource = catalogSource,
        _installedStore = installedStore,
        _downloadManager = downloadManager,
        _updateManager = updateManager;

  final MarketplaceCatalogSource _catalogSource;
  final InstalledModelsStore _installedStore;
  final ModelDownloadManager _downloadManager;
  final ModelUpdateManager _updateManager;

  Future<List<MarketplaceItemView>> listItems() async {
    final catalog = await _catalogSource.loadCatalog();
    var installed = await _installedStore.readAll();

    // Register built-in packs — failures must not hide the catalog.
    for (final entry in catalog.where((e) => e.builtin)) {
      if (!installed.containsKey(entry.id)) {
        try {
          await _downloadManager.install(entry);
        } catch (_) {
          // Browser / offline — catalog still lists built-in scanners.
        }
      }
    }

    // Auto-install optional neural packs that ship as bundled zip assets so
    // face / plate / document detection works offline without CDN.
    if (PlatformStorage.supportsLocalFileSystem) {
      for (final entry in catalog.where(
        (e) =>
            e.isOptionalNeuralPack &&
            (e.bundleAsset?.trim().isNotEmpty ?? false) &&
            e.compatibility.supportsCurrentPlatform,
      )) {
        final record = installed[entry.id];
        final needsInstall = record == null ||
            record.state != ModelInstallState.installed;
        if (!needsInstall) continue;
        try {
          await _downloadManager.install(entry);
        } catch (_) {
          // Bundled asset missing in this build — marketplace still lists it.
        }
      }

      try {
        installed = await _installedStore.readAll();
        await _repairOnnxPacksIfNeeded(catalog, installed);
      } catch (_) {
        // Stale install registry — catalog remains browsable.
      }
    }

    installed = await _installedStore.readAll();
    return catalog
        .map((entry) => _toView(entry, installed[entry.id]))
        .toList();
  }

  Future<InstalledModelRecord> download(
    String packId, {
    DownloadProgressCallback? onProgress,
  }) async {
    final catalog = await _catalogSource.loadCatalog();
    final entry = catalog.firstWhere(
      (e) => e.id == packId,
      orElse: () => throw MarketplaceException('Pack not found in catalog.'),
    );

    if (entry.builtin) {
      throw MarketplaceException(
        '${entry.name} is built into ZeroTrace — no download needed.',
      );
    }

    if (!entry.isOptionalNeuralPack) {
      throw MarketplaceException(
        'Only optional neural packs can be downloaded from the marketplace.',
      );
    }
    if (!entry.compatibility.supportsCurrentPlatform) {
      throw MarketplaceException(
        '${entry.name} is not available on this device yet.',
      );
    }

    return _downloadManager.install(entry, onProgress: onProgress);
  }

  Future<void> remove(String modelId) async {
    final catalog = await _catalogSource.loadCatalog();
    ModelCatalogEntry? entry;
    for (final e in catalog) {
      if (e.id == modelId) {
        entry = e;
        break;
      }
    }
    if (entry?.builtin == true) {
      throw MarketplaceException('Built-in packs cannot be removed.');
    }
    await _installedStore.remove(modelId);
  }

  Future<InstalledModelRecord> update(
    String modelId, {
    DownloadProgressCallback? onProgress,
  }) =>
      download(modelId, onProgress: onProgress);

  Future<List<ModelUpdateInfo>> checkUpdates() => _updateManager.checkForUpdates();

  Future<void> _repairOnnxPacksIfNeeded(
    List<ModelCatalogEntry> catalog,
    Map<String, InstalledModelRecord> installed,
  ) async {
    final layout = ZeroTracePaths.layout;
    for (final entry in catalog.where((e) => e.manifest.isOnnx)) {
      final record = installed[entry.id];
      if (record?.state != ModelInstallState.installed) continue;

      final modelBytes = await NeuralPackDiagnostics.modelBytesOnDisk(
        layout,
        entry.id,
      );
      final needsMissingRepair = modelBytes == 0;
      final needsPlaceholderRepair = modelBytes > 0 && modelBytes <= 1024;
      final needsFaceUpgrade = entry.id == 'face-protection' &&
          await NeuralPackDiagnostics.needsFacePackUpgrade(layout);

      final needsVehicleUpgrade = entry.id == 'vehicle-protection' &&
          await NeuralPackDiagnostics.needsVehiclePackUpgrade(layout);

      if (!needsMissingRepair &&
          !needsPlaceholderRepair &&
          !needsFaceUpgrade &&
          !needsVehicleUpgrade) {
        continue;
      }

      try {
        await _downloadManager.install(entry);
      } catch (_) {
        // Stale registry with no files — clear so UI offers a fresh install.
        if (needsMissingRepair) {
          await _installedStore.remove(entry.id);
        }
      }
    }
  }

  MarketplaceItemView _toView(
    ModelCatalogEntry entry,
    InstalledModelRecord? record,
  ) {
    final state = record?.state ??
        (entry.builtin ? ModelInstallState.installed : ModelInstallState.notInstalled);

    return MarketplaceItemView(
      entry: entry,
      installState: state,
      installedVersion: record?.version,
      updateVersion: record?.updateVersion,
    );
  }
}

class MarketplaceItemView {
  const MarketplaceItemView({
    required this.entry,
    required this.installState,
    this.installedVersion,
    this.updateVersion,
  });

  final ModelCatalogEntry entry;
  final ModelInstallState installState;
  final String? installedVersion;
  final String? updateVersion;

  String get statusLabel => switch (installState) {
        ModelInstallState.installed => entry.builtin
            ? 'Built-in'
            : entry.manifest.isOnnx
                ? 'Downloaded'
                : 'Installed',
        ModelInstallState.downloading => 'Downloading…',
        ModelInstallState.notInstalled => entry.manifest.isOnnx
            ? 'Optional'
            : 'Get pack',
        ModelInstallState.updateAvailable => 'Update',
        ModelInstallState.failed => 'Failed',
      };

  /// Human-readable delivery type for marketplace detail UI.
  String get deliveryLabel => switch (entry.manifest.format) {
        'builtin' => 'Built-in scanner',
        'rules' => 'Rules engine (lightweight)',
        'onnx' => 'Neural model (large download)',
        _ => 'Pack',
      };

  /// Shown when an ONNX pack is installed but cannot run yet.
  String? operationalNoteFor({
    required bool onnxRuntimeAvailable,
    required int modelBytesOnDisk,
  }) {
    if (!entry.manifest.isOnnx) return null;

    if (installState == ModelInstallState.notInstalled ||
        installState == ModelInstallState.downloading) {
      return 'Optional neural pack. Metadata, QR, and secrets scanners already '
          'run locally without this download.';
    }

    if (!onnxRuntimeAvailable) {
      return 'Downloaded, but ONNX runtime is off in this build. Rebuild the '
          'engine with ONNX to enable ${entry.name}.';
    }
    if (modelBytesOnDisk <= 1024) {
      return 'Pack shell is on device, but full ONNX weights are not loaded yet. '
          'Face/plate detection will stay skipped until real model files are present.';
    }
    return null;
  }
}

class MarketplaceException implements Exception {
  MarketplaceException(this.message);
  final String message;

  @override
  String toString() => message;
}
