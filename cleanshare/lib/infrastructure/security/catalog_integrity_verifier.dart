import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import 'pack_signature_verifier.dart';
import 'pack_trust_constants.dart';
import 'pack_trust_policy.dart';

/// Validates marketplace catalog against bundled [INTEGRITY.json] (ASI-09).
class CatalogIntegrityVerifier {
  const CatalogIntegrityVerifier({
    PackSignatureVerifier? signatureVerifier,
  }) : _signatures = signatureVerifier ?? const PackSignatureVerifier();

  final PackSignatureVerifier _signatures;

  static const integrityAssetPath = 'assets/marketplace/INTEGRITY.json';

  Future<CatalogIntegrityManifest> loadBundledIntegrity() async {
    final raw = await rootBundle.loadString(integrityAssetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return CatalogIntegrityManifest.fromJson(json);
  }

  /// Verifies catalog JSON before it is parsed or cached.
  Future<void> verifyCatalogRaw(
    String catalogRaw, {
    required bool isBundled,
  }) async {
    final integrity = await loadBundledIntegrity();

    if (integrity.publicKeyHex.toLowerCase() !=
        PackTrustConstants.publisherPublicKeyHex.toLowerCase()) {
      throw CatalogIntegrityException(
        'Catalog integrity publisher key does not match embedded trust anchor.',
      );
    }

    final digest = sha256.convert(utf8.encode(catalogRaw)).toString();
    if (digest.toLowerCase() != integrity.catalogSha256.toLowerCase()) {
      throw CatalogIntegrityException(
        isBundled
            ? 'Bundled catalog hash does not match INTEGRITY.json.'
            : 'Remote catalog hash does not match signed INTEGRITY.json.',
      );
    }

    final catalogJson = jsonDecode(catalogRaw) as Map<String, dynamic>;
    final packs =
        (catalogJson['packs'] ?? catalogJson['models']) as List<dynamic>? ??
            [];

    for (final raw in packs) {
      final pack = raw as Map<String, dynamic>;
      final manifest = pack['manifest'] as Map<String, dynamic>?;
      if (manifest == null) continue;

      final format = manifest['format'] as String? ?? '';
      if (format == 'builtin') continue;

      final packId = pack['id'] as String;
      final version = pack['version'] as String;
      final sha256Hex = manifest['sha256'] as String?;
      final signature = manifest['signature'] as String?;

      if (sha256Hex == null || sha256Hex.length != 64) {
        if (format == 'onnx') {
          throw CatalogIntegrityException('ONNX pack $packId missing sha256.');
        }
        continue;
      }

      if (!PackTrustPolicy.requiresSignature(format: format)) continue;

      await _signatures.assertValidOrThrow(
        packId: packId,
        version: version,
        sha256Hex: sha256Hex,
        signature: signature,
        format: format,
      );

      if (isBundled) {
        final entry = integrity.packs
            .where((e) => e.packId == packId && e.version == version)
            .firstOrNull;
        if (entry == null) {
          throw CatalogIntegrityException(
            'Pack $packId v$version missing from INTEGRITY.json.',
          );
        }
        if (entry.sha256.toLowerCase() != sha256Hex.toLowerCase() ||
            entry.signature != signature) {
          throw CatalogIntegrityException(
            'Pack $packId v$version does not match INTEGRITY.json.',
          );
        }
      }

      final url = manifest['downloadUrl'] as String?;
      if (url != null && url.trim().isNotEmpty) {
        PackTrustPolicy.assertDownloadUrlAllowed(url);
      }
    }
  }
}

class CatalogIntegrityManifest {
  const CatalogIntegrityManifest({
    required this.catalogSha256,
    required this.publicKeyHex,
    required this.packs,
  });

  final String catalogSha256;
  final String publicKeyHex;
  final List<CatalogIntegrityPackEntry> packs;

  factory CatalogIntegrityManifest.fromJson(Map<String, dynamic> json) {
    final packsJson = json['packs'] as List<dynamic>? ?? [];
    return CatalogIntegrityManifest(
      catalogSha256: json['catalogSha256'] as String,
      publicKeyHex: json['publicKeyHex'] as String,
      packs: packsJson
          .map(
            (e) => CatalogIntegrityPackEntry.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

class CatalogIntegrityPackEntry {
  const CatalogIntegrityPackEntry({
    required this.packId,
    required this.version,
    required this.sha256,
    required this.signature,
  });

  final String packId;
  final String version;
  final String sha256;
  final String signature;

  factory CatalogIntegrityPackEntry.fromJson(Map<String, dynamic> json) {
    return CatalogIntegrityPackEntry(
      packId: json['packId'] as String,
      version: json['version'] as String,
      sha256: json['sha256'] as String,
      signature: json['signature'] as String,
    );
  }
}

class CatalogIntegrityException implements Exception {
  CatalogIntegrityException(this.message);
  final String message;

  @override
  String toString() => 'CatalogIntegrityException: $message';
}
