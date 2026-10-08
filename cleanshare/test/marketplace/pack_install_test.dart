import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_io/io.dart';

import 'package:cleanshare/domain/storage/storage_layout.dart';
import 'package:cleanshare/infrastructure/marketplace/manifest_verifier.dart';
import 'package:cleanshare/infrastructure/marketplace/marketplace_service.dart';
import 'package:cleanshare/infrastructure/marketplace/model_download_manager.dart';
import 'package:cleanshare/infrastructure/marketplace/model_update_manager.dart';
import 'package:cleanshare/infrastructure/storage/installed_models_store.dart';
import 'package:cleanshare/infrastructure/storage/zerotrace_paths.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  for (final packId in [
    'face-protection',
    'vehicle-protection',
    'document-protection',
  ]) {
    test('installs bundled $packId pack', () async {
      final root = Directory.systemTemp.createTempSync('pack_install_$packId');
      addTearDown(() {
        if (root.existsSync()) root.deleteSync(recursive: true);
      });
      final layout = ZeroTraceLayout(root: root);
      await layout.ensureCreated();

      final store = InstalledModelsStore(layout);
      final catalog = MarketplaceCatalogSource(layout);
      final service = MarketplaceService(
        catalogSource: catalog,
        installedStore: store,
        downloadManager: ModelDownloadManager(
          layout: layout,
          store: store,
          verifier: const ManifestVerifier(),
        ),
        updateManager: ModelUpdateManager(
          store: store,
          catalogSource: catalog,
        ),
      );

      final catalogEntries = await catalog.loadCatalog();
      final entry = catalogEntries.firstWhere((e) => e.id == packId);
      expect(entry.bundleAsset, isNotNull);

      final record = await service.download(packId);
      expect(record.state.name, 'installed');
      expect(await layout.packDirectory(packId).exists(), isTrue);
    });
  }
}
