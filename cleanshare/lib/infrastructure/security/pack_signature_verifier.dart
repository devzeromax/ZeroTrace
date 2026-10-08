import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'pack_trust_constants.dart';
import 'pack_trust_policy.dart';

/// Verifies ed25519 signatures on marketplace manifests (ASI-09).
class PackSignatureVerifier {
  const PackSignatureVerifier();

  static final _algorithm = Ed25519();

  /// Message format: `zerotrace|packId|version|sha256`
  String messageFor({
    required String packId,
    required String version,
    required String sha256Hex,
  }) =>
      'zerotrace|$packId|$version|$sha256Hex';

  Future<bool> verify({
    required String packId,
    required String version,
    required String sha256Hex,
    required String signature,
  }) async {
    if (!signature.startsWith('ed25519:')) return false;
    final sigHex = signature.substring('ed25519:'.length).trim();
    if (sigHex.length != 128) return false;

    try {
      final publicKey = SimplePublicKey(
        _hexToBytes(PackTrustConstants.publisherPublicKeyHex),
        type: KeyPairType.ed25519,
      );
      final sigBytes = _hexToBytes(sigHex);
      final message = utf8.encode(messageFor(
        packId: packId,
        version: version,
        sha256Hex: sha256Hex,
      ));
      return await _algorithm.verify(
        message,
        signature: Signature(sigBytes, publicKey: publicKey),
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> assertValidOrThrow({
    required String packId,
    required String version,
    required String sha256Hex,
    required String? signature,
    required String format,
  }) async {
    PackTrustPolicy.assertSignaturePresent(
      signature: signature,
      format: format,
    );
    final sig = signature?.trim();
    if (sig == null || sig.isEmpty) return;

    final ok = await verify(
      packId: packId,
      version: version,
      sha256Hex: sha256Hex,
      signature: sig,
    );
    if (!ok) {
      throw PackTrustException('Publisher signature verification failed.');
    }
  }

  static Uint8List _hexToBytes(String hex) {
    final normalized = hex.toLowerCase();
    final out = Uint8List(normalized.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(normalized.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }
}
