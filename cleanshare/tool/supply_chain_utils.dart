// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Shared helpers for ASI-09 supply-chain tooling.
abstract final class SupplyChainPaths {
  static String get repoRoot {
    final script = Platform.script.toFilePath();
    return Directory(script).parent.parent.path;
  }

  static File get constantsFile => File(
      '$repoRoot${Platform.pathSeparator}lib'
      '${Platform.pathSeparator}infrastructure'
      '${Platform.pathSeparator}security'
      '${Platform.pathSeparator}pack_trust_constants.dart',
      );

  static File get catalogFile => File(
      '$repoRoot${Platform.pathSeparator}assets'
        '${Platform.pathSeparator}marketplace'
        '${Platform.pathSeparator}catalog.json',
      );

  static File get publisherSeedFile => File(
      '$repoRoot${Platform.pathSeparator}tool'
        '${Platform.pathSeparator}keys'
        '${Platform.pathSeparator}publisher_seed.hex',
      );

  static File get publisherPublicFile => File(
      '$repoRoot${Platform.pathSeparator}tool'
        '${Platform.pathSeparator}keys'
        '${Platform.pathSeparator}publisher_public.hex',
      );

  static File engineDll({required bool release}) {
    final profile = release ? 'release' : 'debug';
    return File(
      '$repoRoot${Platform.pathSeparator}engine'
      '${Platform.pathSeparator}zerotrace_engine'
      '${Platform.pathSeparator}target'
      '${Platform.pathSeparator}$profile'
      '${Platform.pathSeparator}zerotrace_engine.dll',
    );
  }
}

abstract final class PackSigning {
  static final algorithm = Ed25519();

  static String messageFor({
    required String packId,
    required String version,
    required String sha256Hex,
  }) =>
      'zerotrace|$packId|$version|$sha256Hex';

  static String bytesToHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static Uint8List hexToBytes(String hex) {
    final normalized = hex.toLowerCase();
    final out = Uint8List(normalized.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(normalized.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  static Future<SimpleKeyPair> loadOrCreatePublisherKeyPair() async {
    final seedFile = SupplyChainPaths.publisherSeedFile;
    if (await seedFile.exists()) {
      final hex = (await seedFile.readAsString()).trim();
      return algorithm.newKeyPairFromSeed(hexToBytes(hex));
    }

    final keyPair = await algorithm.newKeyPair();
    final seed = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();
    await seedFile.parent.create(recursive: true);
    await seedFile.writeAsString(bytesToHex(seed));
    await SupplyChainPaths.publisherPublicFile
        .writeAsString(bytesToHex(publicKey.bytes));
    return keyPair;
  }

  static Future<String> signManifest({
    required SimpleKeyPair keyPair,
    required String packId,
    required String version,
    required String sha256Hex,
  }) async {
    final message = utf8.encode(
      messageFor(packId: packId, version: version, sha256Hex: sha256Hex),
    );
    final signature = await algorithm.sign(message, keyPair: keyPair);
    return 'ed25519:${bytesToHex(signature.bytes)}';
  }
}

void patchConstant(String fieldName, String newValue) {
  final file = SupplyChainPaths.constantsFile;
  var content = file.readAsStringSync();
  final pattern = RegExp(
    "static const $fieldName\\s*=\\s*'[^']*';",
  );
  if (!pattern.hasMatch(content)) {
    throw StateError('Could not find $fieldName in ${file.path}');
  }
  content = content.replaceFirst(
    pattern,
    "static const $fieldName = '$newValue';",
  );
  file.writeAsStringSync(content);
}

void patchConstantList(String fieldName, List<String> values) {
  final file = SupplyChainPaths.constantsFile;
  var content = file.readAsStringSync();
  final formatted = values.map((v) => "    '$v',").join('\n');
  final block = 'static const $fieldName = <String>[\n$formatted\n  ];';
  final pattern = RegExp(
    'static const $fieldName = <String>\\[[\\s\\S]*?\\];',
  );
  if (!pattern.hasMatch(content)) {
    throw StateError('Could not find $fieldName list in ${file.path}');
  }
  content = content.replaceFirst(pattern, block);
  file.writeAsStringSync(content);
}
