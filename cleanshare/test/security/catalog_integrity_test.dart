import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cleanshare/infrastructure/security/catalog_integrity_verifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CatalogIntegrityVerifier', () {
    const verifier = CatalogIntegrityVerifier();

    test('bundled catalog matches INTEGRITY.json', () async {
      final catalogRaw =
          await rootBundle.loadString('assets/marketplace/catalog.json');
      await verifier.verifyCatalogRaw(catalogRaw, isBundled: true);
    });

    test('rejects tampered catalog hash', () async {
      final catalogRaw =
          await rootBundle.loadString('assets/marketplace/catalog.json');
      final tampered = '$catalogRaw\n';
      expect(
        () => verifier.verifyCatalogRaw(tampered, isBundled: true),
        throwsA(isA<CatalogIntegrityException>()),
      );
    });
  });
}
