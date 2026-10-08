import 'dart:convert';

import 'package:universal_io/io.dart';

import 'package:archive/archive_io.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../core/platform/platform_storage.dart';
import '../../domain/marketplace/marketplace_models.dart';
import '../../domain/storage/storage_layout.dart';
import '../engine/zerotrace_engine_bridge.dart';
import '../security/http_client_factory.dart';
import '../security/installed_pack_trust.dart';
import '../security/pack_install_guard.dart';
import '../security/pack_trust_constants.dart';
import '../security/pack_trust_policy.dart';
import '../security/runtime_security_guard.dart';
import '../security/security_audit_log.dart';
import '../storage/installed_models_store.dart';
import 'manifest_verifier.dart';
import 'marketplace_service.dart';

typedef DownloadProgressCallback = void Function(double progress);

/// Downloads, verifies, extracts, and registers marketplace packs.
class ModelDownloadManager {
  ModelDownloadManager({
    required ZeroTraceLayout layout,
    required InstalledModelsStore store,
    required ManifestVerifier verifier,
    http.Client? httpClient,
    SecurityAuditLog? auditLog,
    RuntimeSecurityGuard? securityGuard,
  })  : _layout = layout,
        _store = store,
        _verifier = verifier,
        _audit = auditLog ?? SecurityAuditLog(layout),
        _securityGuard = securityGuard,
        _http = httpClient ?? createTrustHttpClient();

  final ZeroTraceLayout _layout;
  final InstalledModelsStore _store;
  final ManifestVerifier _verifier;
  final SecurityAuditLog _audit;
  final RuntimeSecurityGuard? _securityGuard;
  final http.Client _http;
  final PackInstallGuard _installGuard = PackInstallGuard();
  final InstalledPackTrustVerifier _packTrust = const InstalledPackTrustVerifier();

  Future<InstalledModelRecord> install(
    ModelCatalogEntry entry, {
    DownloadProgressCallback? onProgress,
  }) async {
    if (entry.builtin) {
      return _registerBuiltin(entry);
    }

    if (!PlatformStorage.supportsLocalFileSystem) {
      throw MarketplaceException(
        'Pack downloads require the mobile or desktop app. Built-in scanners work in the browser.',
      );
    }

    if (!entry.compatibility.supportsCurrentPlatform) {
      throw MarketplaceException(
        '${entry.name} is not available on this device yet.',
      );
    }

    if (entry.manifest.isOnnx) {
      await _securityGuard?.assertSensitiveOperation(
        operation: 'pack_install',
        requiresNeuralEngine: true,
        auditLog: _audit,
      );
    }

    _installGuard.assertCanInstall();

    await _verifier.validateDownloadManifest(
      entry.manifest,
      bundleAsset: entry.bundleAsset,
      packId: entry.id,
      version: entry.version,
    );

    final packDir = _layout.packDirectory(entry.id);
    if (await packDir.exists()) {
      await packDir.delete(recursive: true);
    }
    await packDir.create(recursive: true);
    await _layout.downloads.create(recursive: true);

    await _store.upsert(
      InstalledModelRecord(
        id: entry.id,
        version: entry.version,
        installedAt: DateTime.now(),
        pluginDirectory: packDir.path,
        state: ModelInstallState.downloading,
      ),
    );

    final zipPath =
        p.join(_layout.downloads.path, '${entry.id}-${entry.version}.zip');
    final zipFile = File(zipPath);

    try {
      await _resolvePackArchive(
        entry: entry,
        zipFile: zipFile,
        onProgress: onProgress,
      );

      final zipSha256 = entry.manifest.sha256;
      if (zipSha256 == null || zipSha256.length != 64) {
        throw ModelDownloadException(
          'Pack zip SHA-256 missing for ${entry.id}.',
        );
      }
      await _verifier.verifySha256(zipFile, zipSha256);

      await _extractZip(zipFile, packDir);

      ZeroTraceEngineBridge.clearOnnxCache();

      final manifestFile = await _verifier.resolvePackManifestFile(packDir);
      if (manifestFile == null) {
        throw ModelDownloadException(
          'Pack manifest missing after extraction for ${entry.id}.',
        );
      }

      final manifest = await _verifier.readAndValidate(manifestFile);

      await _packTrust.assertTrustworthy(
        packDir: packDir,
        manifest: manifest,
        catalogSignature: entry.manifest.signature,
        artifactSha256: entry.manifest.sha256,
      );

      if (entry.manifest.signature != null && entry.manifest.sha256 != null) {
        await _persistPackTrustMetadata(
          manifestFile,
          artifactSha256: entry.manifest.sha256!,
          signature: entry.manifest.signature!,
        );
      }

      final modelFile = await _resolveModelFile(packDir, manifest);
      if (modelFile != null && manifest.model.format != 'builtin') {
        await _verifier.verifySha256(modelFile, manifest.model.sha256);
      }

      final record = InstalledModelRecord(
        id: entry.id,
        version: entry.version,
        installedAt: DateTime.now(),
        pluginDirectory: packDir.path,
        state: ModelInstallState.installed,
      );
      await _store.upsert(record);
      try {
        await _audit.record(
          event: 'pack_installed',
          detail: '${entry.name} v${entry.version}',
          metadata: {
            'packId': entry.id,
            'sha256': entry.manifest.sha256 ?? '',
            'source': entry.bundleAsset ?? entry.manifest.downloadUrl ?? 'unknown',
          },
        );
      } catch (_) {
        // Audit log failure must not block a verified install.
      }
      _installGuard.recordSuccess();
      onProgress?.call(1.0);
      return record;
    } catch (e) {
      if (await packDir.exists()) {
        await packDir.delete(recursive: true);
      }
      await _store.upsert(
        InstalledModelRecord(
          id: entry.id,
          version: entry.version,
          installedAt: DateTime.now(),
          pluginDirectory: packDir.path,
          state: ModelInstallState.failed,
        ),
      );
      await _audit.record(
        event: 'pack_install_failed',
        detail: '${entry.id}: $e',
      );
      _installGuard.recordFailure();
      if (e is ModelDownloadException) rethrow;
      if (e is MarketplaceException) rethrow;
      if (e is PackTrustException) {
        throw ModelDownloadException(e.message);
      }
      if (e is RuntimeSecurityException) {
        throw ModelDownloadException(e.message);
      }
      if (e is PathGuardException) {
        throw ModelDownloadException(e.message);
      }
      throw ModelDownloadException(
        'Install failed for ${entry.name}: $e',
      );
    } finally {
      if (await zipFile.exists()) await zipFile.delete();
    }
  }

  Future<void> _persistPackTrustMetadata(
    File manifestFile, {
    required String artifactSha256,
    required String signature,
  }) async {
    final json =
        jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
    json['artifactSha256'] = artifactSha256;
    json['signature'] = signature;
    await manifestFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(json),
      flush: true,
    );
  }

  Future<File?> _resolveModelFile(
    Directory packDir,
    PluginManifest manifest,
  ) async {
    final relative = manifest.model.file;
    final candidates = <String>{
      PathGuard.resolveUnderRoot(packDir.path, relative),
      if (!relative.contains('/'))
        PathGuard.resolveUnderRoot(packDir.path, p.join('models', relative)),
      PathGuard.resolveUnderRoot(packDir.path, p.basename(relative)),
    };
    for (final path in candidates) {
      final file = File(path);
      if (await file.exists()) return file;
    }
    return null;
  }

  Future<void> _resolvePackArchive({
    required ModelCatalogEntry entry,
    required File zipFile,
    DownloadProgressCallback? onProgress,
  }) async {
    final bundle = entry.bundleAsset?.trim();
    if (bundle != null && bundle.isNotEmpty) {
      try {
        await _copyBundledAsset(bundle, zipFile, onProgress: onProgress);
        return;
      } catch (e) {
        throw ModelDownloadException(
          'Bundled pack "${entry.id}" is missing from this app build. '
          'Reinstall the app or run a full rebuild (not hot reload). '
          '($e)',
        );
      }
    }

    if (!PackTrustConstants.remoteMarketplaceEnabled) {
      throw ModelDownloadException(
        'Optional packs download when the marketplace CDN is enabled. '
        'Built-in scanners still work offline without this pack.',
      );
    }

    final url = entry.manifest.downloadUrl?.trim();
    if (url == null || url.isEmpty) {
      throw ModelDownloadException('No download source for ${entry.id}.');
    }

    PackTrustPolicy.assertDownloadUrlAllowed(url);
    await _downloadFile(url, zipFile, onProgress: onProgress);
  }

  Future<void> _copyBundledAsset(
    String assetPath,
    File destination, {
    DownloadProgressCallback? onProgress,
  }) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    await destination.writeAsBytes(bytes, flush: true);
    onProgress?.call(1.0);
  }

  Future<InstalledModelRecord> _registerBuiltin(ModelCatalogEntry entry) async {
    if (!PlatformStorage.supportsLocalFileSystem) {
      final record = InstalledModelRecord(
        id: entry.id,
        version: entry.version,
        installedAt: DateTime.now(),
        pluginDirectory: 'builtin://${entry.id}',
        state: ModelInstallState.installed,
      );
      await _store.upsert(record);
      return record;
    }

    final packDir = _layout.packDirectory(entry.id);
    if (!await packDir.exists()) {
      await packDir.create(recursive: true);
    }

    final manifestFile = _layout.packManifestFile(entry.id);
    if (!await manifestFile.exists()) {
      await _writeBuiltinManifest(entry, manifestFile);
    }

    final record = InstalledModelRecord(
      id: entry.id,
      version: entry.version,
      installedAt: DateTime.now(),
      pluginDirectory: packDir.path,
      state: ModelInstallState.installed,
    );
    await _store.upsert(record);
    return record;
  }

  Future<void> _downloadFile(
    String url,
    File destination, {
    DownloadProgressCallback? onProgress,
  }) async {
    PackTrustPolicy.assertDownloadUrlAllowed(url);
    final request = http.Request('GET', Uri.parse(url));
    final response = await _http.send(request);

    if (response.statusCode != 200) {
      throw ModelDownloadException(
        'Download failed (${response.statusCode}) for $url',
      );
    }

    final total = response.contentLength ?? 0;
    var received = 0;
    final sink = destination.openWrite();

    await for (final chunk in response.stream) {
      received += chunk.length;
      sink.add(chunk);
      if (total > 0) {
        onProgress?.call(received / total);
      } else {
        onProgress?.call(0.5);
      }
    }

    await sink.close();
    onProgress?.call(1.0);
  }

  Future<void> _extractZip(File zipFile, Directory destination) async {
    final destRoot = p.normalize(p.absolute(destination.path));
    final archive = ZipDecoder().decodeBytes(await zipFile.readAsBytes());

    for (final file in archive) {
      final outPath = PathGuard.resolveUnderRoot(destRoot, file.name);
      if (file.isFile) {
        final outFile = File(outPath);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      } else {
        await Directory(outPath).create(recursive: true);
      }
    }
  }

  Future<void> _writeBuiltinManifest(
    ModelCatalogEntry entry,
    File manifestFile,
  ) async {
    final manifest = PluginManifest(
      id: entry.id,
      name: entry.name,
      version: entry.version,
      developer: entry.developer,
      category: entry.category,
      capabilities: entry.capabilities,
      model: const PluginModelSpec(
        format: 'builtin',
        file: 'builtin',
        sha256: '0000000000000000000000000000000000000000000000000000000000000000',
        sizeBytes: 0,
      ),
      minAppVersion: entry.compatibility.minAppVersion,
      license: entry.license,
    );
    await manifestFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(manifest.toJson()),
    );
  }

  void dispose() => _http.close();
}

class ModelDownloadException implements Exception {
  ModelDownloadException(this.message);
  final String message;

  @override
  String toString() => 'ModelDownloadException: $message';
}
