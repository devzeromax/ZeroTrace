import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/storage/storage_layout.dart';
import '../infrastructure/engine/engine_bootstrap_exception.dart';
import '../infrastructure/engine/zerotrace_engine_bridge.dart';
import '../infrastructure/export/export_engine.dart';
import '../infrastructure/marketplace/manifest_verifier.dart';
import '../infrastructure/marketplace/marketplace_service.dart';
import '../infrastructure/marketplace/model_download_manager.dart';
import '../infrastructure/marketplace/model_update_manager.dart';
import '../infrastructure/plugins/plugin_discovery.dart';
import '../infrastructure/scanner/risk_scorer.dart';
import '../infrastructure/scanner/scan_pipeline.dart';
import '../core/utils/user_facing_error.dart';
import '../infrastructure/security/app_integrity_verifier.dart';
import '../infrastructure/security/device_integrity.dart';
import '../infrastructure/security/runtime_security_guard.dart';
import '../infrastructure/security/security_audit_log.dart';
import '../infrastructure/storage/history_store.dart';
import '../infrastructure/storage/installed_models_store.dart';
import '../infrastructure/storage/zerotrace_paths.dart';
import '../infrastructure/storage/file_staging_service.dart';

export '../infrastructure/engine/zerotrace_engine_bridge.dart';
export '../infrastructure/export/export_engine.dart';
export '../infrastructure/marketplace/marketplace_service.dart';
export '../infrastructure/scanner/scan_pipeline.dart';
export '../domain/scanner/scanner_models.dart';

/// Bootstrap flag — set after [engineBootstrapProvider] completes.
final engineReadyProvider = StateProvider<bool>((ref) => false);

final zeroTraceLayoutProvider = Provider<ZeroTraceLayout>((ref) {
  return ZeroTracePaths.layout;
});

final engineCapabilitiesProvider = Provider<EngineCapabilities>((ref) {
  return ZeroTraceEngineBridge.probe();
});

final marketplaceServiceProvider = Provider<MarketplaceService>((ref) {
  final layout = ref.watch(zeroTraceLayoutProvider);
  final catalog = MarketplaceCatalogSource(layout);
  final store = InstalledModelsStore(layout);
  final verifier = const ManifestVerifier();
  final downloader = ModelDownloadManager(
    layout: layout,
    store: store,
    verifier: verifier,
    securityGuard: RuntimeSecurityGuard(auditLog: SecurityAuditLog(layout)),
  );
  final updater = ModelUpdateManager(store: store, catalogSource: catalog);
  return MarketplaceService(
    catalogSource: catalog,
    installedStore: store,
    downloadManager: downloader,
    updateManager: updater,
  );
});

final pluginDiscoveryProvider = Provider<PluginDiscovery>((ref) {
  final layout = ref.watch(zeroTraceLayoutProvider);
  final caps = ref.watch(engineCapabilitiesProvider);
  return PluginDiscovery(
    layout: layout,
    verifier: const ManifestVerifier(),
    onnxRuntimeAvailable: caps.onnxRuntimeAvailable,
  );
});

final runtimeSecurityGuardProvider = Provider<RuntimeSecurityGuard>((ref) {
  final layout = ref.watch(zeroTraceLayoutProvider);
  return RuntimeSecurityGuard(auditLog: SecurityAuditLog(layout));
});

final scanPipelineProvider = Provider<ScanPipeline>((ref) {
  return ScanPipeline(
    discovery: ref.watch(pluginDiscoveryProvider),
    riskScorer: const RiskScorer(),
    layout: ref.watch(zeroTraceLayoutProvider),
    securityGuard: ref.watch(runtimeSecurityGuardProvider),
  );
});

final fileStagingProvider = Provider<FileStagingService>((ref) {
  return FileStagingService(ref.watch(zeroTraceLayoutProvider));
});

final exportEngineProvider = Provider<ExportEngine>((ref) {
  return ExportEngine(
    ref.watch(zeroTraceLayoutProvider),
    securityGuard: ref.watch(runtimeSecurityGuardProvider),
  );
});

final historyStoreProvider = Provider<HistoryStore>((ref) {
  return HistoryStore(ref.watch(zeroTraceLayoutProvider));
});

/// Initializes storage and probes native engine on cold start.
/// Fails closed if release signing/engine integrity checks fail.
final engineBootstrapProvider = FutureProvider<void>((ref) async {
  try {
    await ZeroTracePaths.ensureInitialized();
    final layout = ref.read(zeroTraceLayoutProvider);
    final guard = ref.read(runtimeSecurityGuardProvider);
    await guard.assertBootstrap(auditLog: SecurityAuditLog(layout));
    ref.read(engineCapabilitiesProvider);
    ref.read(engineReadyProvider.notifier).state = true;
  } on AppIntegrityException catch (e) {
    throw EngineBootstrapException(e.message);
  } on DeviceIntegrityException catch (e) {
    throw EngineBootstrapException(e.message);
  } on RuntimeSecurityException catch (e) {
    throw EngineBootstrapException(e.message);
  } on StateError catch (e) {
    throw EngineBootstrapException(e.message);
  } catch (e) {
    throw EngineBootstrapException(UserFacingError.bootstrapMessage(e));
  }
});

final marketplaceItemsProvider =
    FutureProvider<List<MarketplaceItemView>>((ref) async {
  await ref.watch(engineBootstrapProvider.future);
  return ref.read(marketplaceServiceProvider).listItems();
});
