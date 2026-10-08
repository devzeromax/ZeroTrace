import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cleanshare/infrastructure/security/pack_signature_verifier.dart';
import 'package:cleanshare/infrastructure/security/pack_trust_constants.dart';

void main() {
  test('ONNX catalog entries verify with embedded publisher key', () async {
    expect(
      PackTrustConstants.publisherPublicKeyHex.length,
      64,
      reason: 'Run: dart run tool/embed_publisher_key.dart',
    );
    expect(
      PackTrustConstants.publisherPublicKeyHex,
      isNot(contains('PLACEHOLDER')),
    );

    final catalogPath = File(
      '${Directory.current.path}${Platform.pathSeparator}assets'
      '${Platform.pathSeparator}marketplace'
      '${Platform.pathSeparator}catalog.json',
    );
    expect(await catalogPath.exists(), isTrue);

    final json =
        jsonDecode(await catalogPath.readAsString()) as Map<String, dynamic>;
    final packs = json['packs'] as List<dynamic>;
    const verifier = PackSignatureVerifier();

    var onnxCount = 0;
    for (final raw in packs) {
      final pack = raw as Map<String, dynamic>;
      final manifest = pack['manifest'] as Map<String, dynamic>?;
      if (manifest?['format'] != 'onnx') continue;
      onnxCount++;

      final sig = manifest!['signature'] as String?;
      expect(sig, isNotNull);
      expect(sig!.startsWith('ed25519:'), isTrue);

      final ok = await verifier.verify(
        packId: pack['id'] as String,
        version: pack['version'] as String,
        sha256Hex: manifest['sha256'] as String,
        signature: sig,
      );
      expect(ok, isTrue, reason: 'Bad signature for ${pack['id']}');
    }

    expect(onnxCount, 3);
  });
}
