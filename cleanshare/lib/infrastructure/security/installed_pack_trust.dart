import 'package:universal_io/io.dart';

import '../../domain/marketplace/marketplace_models.dart';
import '../marketplace/manifest_verifier.dart';
import 'pack_signature_verifier.dart';
import 'pack_trust_policy.dart';

/// Verifies publisher signatures on packs already on disk (ASI-09).
class InstalledPackTrustVerifier {
  const InstalledPackTrustVerifier({
    ManifestVerifier? manifestVerifier,
    PackSignatureVerifier? signatureVerifier,
  })  : _manifestVerifier = manifestVerifier ?? const ManifestVerifier(),
        _signatures = signatureVerifier ?? const PackSignatureVerifier();

  final ManifestVerifier _manifestVerifier;
  final PackSignatureVerifier _signatures;

  Future<void> assertTrustworthy({
    required Directory packDir,
    required PluginManifest manifest,
    String? catalogSignature,
    String? artifactSha256,
  }) async {
    if (manifest.model.format == 'builtin') return;
    if (!PackTrustPolicy.requiresSignature(format: manifest.model.format)) {
      return;
    }

    final signature = manifest.signature ?? catalogSignature;
    PackTrustPolicy.assertSignaturePresent(
      signature: signature,
      format: manifest.model.format,
    );

    final signedArtifactHash =
        artifactSha256 ?? manifest.artifactSha256 ?? manifest.model.sha256;
    if (signedArtifactHash.length != 64) {
      throw PackTrustException(
        'Pack "${manifest.id}" is missing a signed artifact hash.',
      );
    }

    final modelFile = await _resolveModelFile(packDir, manifest);
    if (modelFile != null && manifest.model.format != 'builtin') {
      await _manifestVerifier.verifySha256(modelFile, manifest.model.sha256);
    }

    await _signatures.assertValidOrThrow(
      packId: manifest.id,
      version: manifest.version,
      sha256Hex: signedArtifactHash,
      signature: signature,
      format: manifest.model.format,
    );
  }

  Future<File?> _resolveModelFile(
    Directory packDir,
    PluginManifest manifest,
  ) async {
    final relative = manifest.model.file;
    final candidates = <String>{
      '${packDir.path}/$relative',
      if (!relative.contains('/'))
        '${packDir.path}/models/$relative',
      '${packDir.path}/${relative.split('/').last}',
    };
    for (final path in candidates) {
      final file = File(path);
      if (await file.exists()) return file;
    }
    return null;
  }
}
