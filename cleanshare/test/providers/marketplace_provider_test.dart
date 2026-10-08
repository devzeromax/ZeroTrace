import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cleanshare/domain/marketplace/marketplace_models.dart';
import 'package:cleanshare/infrastructure/marketplace/marketplace_service.dart';
import 'package:cleanshare/providers/marketplace_provider.dart';

void main() {
  test('MarketplaceNotifier starts loading', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = container.read(marketplaceProvider);
    expect(state.isLoading, isTrue);
  });

  test('MarketplaceItemView status labels', () {
    expect(
      const MarketplaceItemView(
        entry: _fakeEntry,
        installState: ModelInstallState.installed,
      ).statusLabel,
      'Built-in',
    );
    expect(
      const MarketplaceItemView(
        entry: _onnxEntry,
        installState: ModelInstallState.notInstalled,
      ).statusLabel,
      'Optional',
    );
  });
}

const _onnxEntry = ModelCatalogEntry(
  id: 'face',
  name: 'Face',
  description: 'Face',
  version: '1.0.0',
  developer: 'ZT',
  category: MarketplaceCategory.faceDetection,
  sizeBytes: 15000000,
  downloadCount: 0,
  license: 'MIT',
  compatibility: ModelCompatibility(
    minAppVersion: '1.0.0',
    platforms: ['windows'],
  ),
  builtin: false,
  capabilities: ['faces'],
  manifest: ModelManifestRef(format: 'onnx', pluginId: 'face'),
);

const _fakeEntry = ModelCatalogEntry(
  id: 'test',
  name: 'Test',
  description: 'Test',
  version: '1.0.0',
  developer: 'ZT',
  category: MarketplaceCategory.metadataScanner,
  sizeBytes: 1000,
  downloadCount: 0,
  license: 'MIT',
  compatibility: ModelCompatibility(
    minAppVersion: '1.0.0',
    platforms: ['windows'],
  ),
  builtin: true,
  capabilities: ['metadata'],
  manifest: ModelManifestRef(format: 'builtin', pluginId: 'test'),
);
