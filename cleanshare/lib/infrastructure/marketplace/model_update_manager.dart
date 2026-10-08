import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/marketplace/marketplace_models.dart';
import '../security/catalog_integrity_verifier.dart';
import '../security/http_client_factory.dart';
import '../security/pack_trust_constants.dart';
import '../storage/installed_models_store.dart';
import '../storage/zerotrace_paths.dart';

/// Checks catalog for newer model versions.
class ModelUpdateManager {
  ModelUpdateManager({
    required InstalledModelsStore store,
    required MarketplaceCatalogSource catalogSource,
    http.Client? httpClient,
    CatalogIntegrityVerifier? integrityVerifier,
    this.remoteCatalogUrl =
        'https://releases.zerotrace.app/marketplace/catalog.json',
  })  : _store = store,
        _catalogSource = catalogSource,
        _http = httpClient ?? createTrustHttpClient(),
        _integrity = integrityVerifier ?? const CatalogIntegrityVerifier();

  final InstalledModelsStore _store;
  final MarketplaceCatalogSource _catalogSource;
  final http.Client _http;
  final CatalogIntegrityVerifier _integrity;
  final String remoteCatalogUrl;

  Future<List<ModelUpdateInfo>> checkForUpdates() async {
    final installed = await _store.readAll();
    final catalog = await _loadLatestCatalog();

    final updates = <ModelUpdateInfo>[];
    for (final entry in catalog) {
      final record = installed[entry.id];
      if (record == null || record.state != ModelInstallState.installed) {
        continue;
      }
      if (_isNewer(entry.version, record.version)) {
        updates.add(
          ModelUpdateInfo(
            entry: entry,
            installedVersion: record.version,
            availableVersion: entry.version,
          ),
        );
        await _store.upsert(
          record.copyWith(
            state: ModelInstallState.updateAvailable,
            updateVersion: entry.version,
          ),
        );
      }
    }
    return updates;
  }

  Future<List<ModelCatalogEntry>> _loadLatestCatalog() async {
    if (!PackTrustConstants.remoteMarketplaceEnabled) {
      return _catalogSource.loadCatalog();
    }
    try {
      final response = await _http.get(Uri.parse(remoteCatalogUrl));
      if (response.statusCode == 200) {
        await _integrity.verifyCatalogRaw(response.body, isBundled: false);
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        await _catalogSource.cacheRemoteCatalog(json);
        final packs = (json['packs'] ?? json['models']) as List<dynamic>;
        return packs
            .map((e) => ModelCatalogEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // Offline — use cached/bundled catalog.
    }
    return _catalogSource.loadCatalog();
  }

  bool _isNewer(String available, String installed) {
    final a = _parseVersion(available);
    final b = _parseVersion(installed);
    for (var i = 0; i < 3; i++) {
      final av = i < a.length ? a[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      if (av > bv) return true;
      if (av < bv) return false;
    }
    return false;
  }

  List<int> _parseVersion(String v) {
    return v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  }

  void dispose() => _http.close();
}

class ModelUpdateInfo {
  const ModelUpdateInfo({
    required this.entry,
    required this.installedVersion,
    required this.availableVersion,
  });

  final ModelCatalogEntry entry;
  final String installedVersion;
  final String availableVersion;
}
