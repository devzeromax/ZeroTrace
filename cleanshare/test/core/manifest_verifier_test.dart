import 'package:flutter_test/flutter_test.dart';

import 'package:cleanshare/domain/marketplace/marketplace_models.dart';
import 'package:cleanshare/infrastructure/marketplace/manifest_verifier.dart';

void main() {
  group('ManifestVerifier', () {
    const verifier = ManifestVerifier();

    test('rejects invalid sha256 length', () {
      final manifest = const PluginManifest(
        id: 'test',
        name: 'Test',
        version: '1.0.0',
        developer: 'ZT',
        category: MarketplaceCategory.metadataScanner,
        capabilities: ['metadata'],
        model: PluginModelSpec(
          format: 'onnx',
          file: 'model.onnx',
          sha256: 'abc',
          sizeBytes: 100,
        ),
        minAppVersion: '1.0.0',
        license: 'MIT',
      );

      expect(
        () => verifier.validatePluginManifest(manifest),
        throwsA(isA<ManifestVerificationException>()),
      );
    });
  });
}
