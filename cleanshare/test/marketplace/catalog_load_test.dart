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

  test('bundled catalog loads and listItems returns packs', () async {
    final layout = ZeroTraceLayout(
      root: Directory.systemTemp.createTempSync('zerotrace_test_'),
    );
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

    final items = await service.listItems();
    expect(items, isNotEmpty);
    expect(items.any((i) => i.entry.id == 'privacy-essentials'), isTrue);
  });

  test('corrupt installed-models prefs do not break listItems', () async {
    SharedPreferences.setMockInitialValues({
      'zerotrace_installed_models': '{not valid json',
    });

    final layout = ZeroTraceLayout(
      root: Directory.systemTemp.createTempSync('zerotrace_web_test_'),
    );
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

    final items = await service.listItems();
    expect(items, isNotEmpty);
  });
}
