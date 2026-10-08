import 'package:universal_io/io.dart';



import 'package:path/path.dart' as p;



import '../../core/platform/platform_storage.dart';

import '../marketplace/marketplace_models.dart';



/// Canonical ZeroTrace on-disk layout.

///

/// ```

/// ZeroTrace/

///   packs/           # Installed privacy packs + manifest.json

///   models/          # Legacy ONNX weights by category

///   cache/

///   settings/

///   logs/

///   downloads/

///   scans/           # Staged input files

///   exports/         # Sanitized outputs

/// ```

class ZeroTraceLayout {

  ZeroTraceLayout({required this.root});



  final Directory root;



  Directory get packs => _dir('packs');

  Directory get models => _dir('models');

  Directory get cache => _dir('cache');

  Directory get settings => _dir('settings');

  Directory get logs => _dir('logs');

  Directory get downloads => _dir('downloads');

  Directory get scans => _dir('scans');

  Directory get exports => _dir('exports');



  /// Legacy alias — installed packs live under [packs].

  Directory get plugins => packs;



  File settingsFile(String name) => File(p.join(settings.path, name));

  File installedModelsIndex() => settingsFile('installed_models.json');

  File installedPacksIndex() => settingsFile('installed_packs.json');

  File historyIndex() => settingsFile('scan_history.json');

  File catalogCache() => cacheFile('marketplace_catalog.json');



  File cacheFile(String name) => File(p.join(cache.path, name));



  Directory packDirectory(String packId) => Directory(p.join(packs.path, packId));



  /// Legacy alias for [packDirectory].

  Directory pluginDirectory(String packId) => packDirectory(packId);



  Directory modelCategoryDirectory(MarketplaceCategory category) =>

      Directory(p.join(models.path, category.id));



  File packManifestFile(String packId) =>

      File(p.join(packDirectory(packId).path, 'zerotrace.plugin.json'));



  /// Legacy alias for [packManifestFile].

  File pluginManifestFile(String packId) => packManifestFile(packId);



  Future<void> ensureCreated() async {

    if (!PlatformStorage.supportsLocalFileSystem) return;

    for (final dir in [

      packs,

      models,

      cache,

      settings,

      logs,

      downloads,

      scans,

      exports,

    ]) {

      if (!await dir.exists()) {

        await dir.create(recursive: true);

      }

    }

  }



  Directory _dir(String name) => Directory(p.join(root.path, name));

}

