import 'dart:convert';

import 'package:universal_io/io.dart';

import 'package:crypto/crypto.dart';

import '../../domain/marketplace/marketplace_models.dart';
import '../security/pack_signature_verifier.dart';
import '../security/pack_trust_policy.dart';

/// Validates plugin manifests and downloaded artifacts.
class ManifestVerifier {
  const ManifestVerifier({
    PackSignatureVerifier? signatureVerifier,
  }) : _signatures = signatureVerifier ?? const PackSignatureVerifier();

  final PackSignatureVerifier _signatures;

  void validatePluginManifest(PluginManifest manifest) {
    if (manifest.id.isEmpty || manifest.name.isEmpty) {
      throw ManifestVerificationException('Manifest id and name are required.');
    }

    const allowedFormats = {'builtin', 'onnx', 'rules'};
    if (!allowedFormats.contains(manifest.model.format)) {
      throw ManifestVerificationException(
        'Unsupported model format: ${manifest.model.format}',
      );
    }

    if (manifest.model.format != 'builtin' &&
        manifest.model.sha256.length != 64) {
      throw ManifestVerificationException('Invalid SHA256 digest in manifest.');
    }

    if (manifest.signature != null &&
        manifest.signature!.isNotEmpty &&
        !manifest.signature!.startsWith('ed25519:')) {
      throw ManifestVerificationException('Unsupported signature format.');
    }
  }

  Future<void> verifySha256(File file, String expectedHex) async {
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes).toString();
    if (digest.toLowerCase() != expectedHex.toLowerCase()) {
      throw ManifestVerificationException(
        'Checksum mismatch for ${file.path}. Expected $expectedHex, got $digest.',
      );
    }
  }

  Future<PluginManifest> readAndValidate(File manifestFile) async {
    if (!await manifestFile.exists()) {
      throw ManifestVerificationException(
        'Manifest not found: ${manifestFile.path}',
      );
    }

    final json =
        jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
    final manifest = PluginManifest.fromJson(json);
    validatePluginManifest(manifest);
    return manifest;
  }

  Future<File?> resolvePackManifestFile(Directory packDir) async {
    for (final name in ['zerotrace.plugin.json', 'manifest.json']) {
      final file = File('${packDir.path}/$name');
      if (await file.exists()) return file;
    }
    return null;
  }

  Future<void> validateDownloadManifest(
    ModelManifestRef ref, {
    String? bundleAsset,
    required String packId,
    required String version,
  }) async {
    if (ref.format == 'builtin') return;

    final hasRemote =
        ref.downloadUrl != null && ref.downloadUrl!.trim().isNotEmpty;
    final hasBundle = bundleAsset != null && bundleAsset.trim().isNotEmpty;

    if (!hasRemote && !hasBundle) {
      throw ManifestVerificationException(
        'No download source for ${ref.pluginId}.',
      );
    }

    if (ref.sha256 == null || ref.sha256!.length != 64) {
      throw ManifestVerificationException('SHA256 missing for ${ref.pluginId}.');
    }

    if (hasRemote) {
      PackTrustPolicy.assertDownloadUrlAllowed(ref.downloadUrl!);
    }

    await _signatures.assertValidOrThrow(
      packId: packId,
      version: version,
      sha256Hex: ref.sha256!,
      signature: ref.signature,
      format: ref.format,
    );
  }
}

class ManifestVerificationException implements Exception {
  ManifestVerificationException(this.message);
  final String message;

  @override
  String toString() => 'ManifestVerificationException: $message';
}
