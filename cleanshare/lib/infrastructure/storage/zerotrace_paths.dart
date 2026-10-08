import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_io/io.dart';

import '../security/catalog_integrity_verifier.dart';
import '../../core/platform/platform_storage.dart';
import '../../domain/marketplace/marketplace_models.dart';
import '../../domain/storage/storage_layout.dart';

/// Resolves and initializes the ZeroTrace data directory.
class ZeroTracePaths {
  ZeroTracePaths._();

  static ZeroTraceLayout? _layout;

  static Future<ZeroTraceLayout> ensureInitialized() async {
    if (_layout != null) return _layout!;

    final root = Directory(await _resolveRootPath());
    _layout = ZeroTraceLayout(root: root);
    await _layout!.ensureCreated();
    return _layout!;
  }

  static Future<String> _resolveRootPath() async {
    if (kIsWeb) return 'zerotrace';

    final base = await getApplicationSupportDirectory();
    return '${base.path}${Platform.pathSeparator}ZeroTrace';
  }

  static ZeroTraceLayout get layout {
    final l = _layout;
    if (l == null) {
      throw StateError('ZeroTracePaths not initialized. Call ensureInitialized().');
    }
    return l;
  }

  static bool get isInitialized => _layout != null;
}

/// Loads bundled + cached marketplace catalog.
class MarketplaceCatalogSource {
  MarketplaceCatalogSource(
    this._layout, {
    CatalogIntegrityVerifier? integrityVerifier,
  }) : _integrity = integrityVerifier ?? const CatalogIntegrityVerifier();

  final ZeroTraceLayout _layout;
  final CatalogIntegrityVerifier _integrity;

  static const assetPath = 'assets/marketplace/catalog.json';

  Future<List<ModelCatalogEntry>> loadCatalog() async {
    if (!PlatformStorage.supportsLocalFileSystem) {
      return loadBundledCatalog();
    }

    final cached = _layout.catalogCache();
    if (await cached.exists()) {
      try {
        final raw = await cached.readAsString();
        await _integrity.verifyCatalogRaw(raw, isBundled: false);
        final json = jsonDecode(raw) as Map<String, dynamic>;
        return _parseCatalog(json);
      } catch (_) {
        try {
          await cached.delete();
        } catch (_) {
          // Ignore — fall through to bundled catalog.
        }
      }
    }
    return loadBundledCatalog();
  }

  Future<List<ModelCatalogEntry>> loadBundledCatalog() async {
    final raw = await rootBundle.loadString(assetPath);
    await _integrity.verifyCatalogRaw(raw, isBundled: true);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return _parseCatalog(json);
  }

  Future<void> cacheRemoteCatalog(Map<String, dynamic> json) async {
    if (!PlatformStorage.supportsLocalFileSystem) return;
    final encoded = jsonEncode(json);
    await _integrity.verifyCatalogRaw(encoded, isBundled: false);
    await _layout.catalogCache().writeAsString(encoded);
  }

  List<ModelCatalogEntry> _parseCatalog(Map<String, dynamic> json) {
    final packs = (json['packs'] ?? json['models']) as List<dynamic>;
    return packs
        .map((e) => ModelCatalogEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
