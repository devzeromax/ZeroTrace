// ignore_for_file: avoid_print

/// Signs ONNX pack entries in catalog.json and writes INTEGRITY.json (ASI-09).
///
/// Run from cleanshare/:
///   dart run tool/embed_publisher_key.dart
///   dart run tool/sign_catalog_packs.dart
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'supply_chain_utils.dart';

Future<void> main() async {
  final keyPair = await PackSigning.loadOrCreatePublisherKeyPair();
  final catalogFile = SupplyChainPaths.catalogFile;
  final raw = await catalogFile.readAsString();
  final json = jsonDecode(raw) as Map<String, dynamic>;
  final packs = (json['packs'] as List<dynamic>).cast<Map<String, dynamic>>();

  final integrityEntries = <Map<String, String>>[];

  for (final pack in packs) {
    final manifest = pack['manifest'] as Map<String, dynamic>?;
    if (manifest == null) continue;
    if (manifest['format'] != 'onnx') continue;

    final packId = pack['id'] as String;
    final version = pack['version'] as String;
    final bundleAsset = pack['bundleAsset'] as String?;
    if (bundleAsset != null && bundleAsset.trim().isNotEmpty) {
      final zipFile = File(
        '${SupplyChainPaths.repoRoot}${Platform.pathSeparator}'
        '${bundleAsset.replaceAll('/', Platform.pathSeparator)}',
      );
      if (!await zipFile.exists()) {
        throw StateError('Bundled zip missing for $packId: ${zipFile.path}');
      }
      final bytes = await zipFile.readAsBytes();
      final zipSha = sha256.convert(bytes).toString();
      manifest['sha256'] = zipSha;
      pack['sizeBytes'] = bytes.length;
      print('Synced $packId zip sha256 -> $zipSha (${bytes.length} bytes)');
    }

    final sha256Hex = manifest['sha256'] as String?;
    if (sha256Hex == null || sha256Hex.length != 64) {
      throw StateError('Missing sha256 for $packId');
    }

    final signature = await PackSigning.signManifest(
      keyPair: keyPair,
      packId: packId,
      version: version,
      sha256Hex: sha256Hex,
    );
    manifest['signature'] = signature;

    integrityEntries.add({
      'packId': packId,
      'version': version,
      'sha256': sha256Hex,
      'signature': signature,
    });

    print('Signed $packId v$version');
    print('  $signature');
  }

  json['publisherKeyId'] = 'zerotrace-publisher-v1';
  json['signedAt'] = DateTime.now().toUtc().toIso8601String();

  await catalogFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(json),
  );

  final integrity = {
    'version': 1,
    'algorithm': 'ed25519',
    'publisherKeyId': 'zerotrace-publisher-v1',
    'publicKeyHex': PackSigning.bytesToHex(
      (await keyPair.extractPublicKey()).bytes,
    ),
    'packs': integrityEntries,
    'catalogSha256': sha256.convert(utf8.encode(await catalogFile.readAsString())).toString(),
  };

  final integrityFile = File(
    '${SupplyChainPaths.repoRoot}${Platform.pathSeparator}assets'
    '${Platform.pathSeparator}marketplace'
    '${Platform.pathSeparator}INTEGRITY.json',
  );
  await integrityFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(integrity),
  );

  print('');
  print('Updated ${catalogFile.path}');
  print('Wrote ${integrityFile.path}');
}
