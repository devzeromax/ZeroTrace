// ignore_for_file: avoid_print

/// Pins the release APK signing certificate SHA-256 in pack_trust_constants.dart.
///
/// Get cert hash from a built APK (v2/v3 signing — use apksigner, not keytool):
///   apksigner verify --print-certs build\app\outputs\flutter-apk\app-release.apk
///   (copy SHA-256 digest, lowercase, no colons)
///
/// Then:
///   dart run tool/embed_release_cert.dart --sha256 <64-char-hex>
library;

import 'dart:io';

import 'supply_chain_utils.dart';

Future<void> main(List<String> args) async {
  final shaIndex = args.indexOf('--sha256');
  if (shaIndex < 0 || shaIndex + 1 >= args.length) {
    print('Usage: dart run tool/embed_release_cert.dart --sha256 <cert-sha256-hex>');
    print('');
    print('Extract from APK:');
  print('  keytool -printcert -jarfile build\\app\\outputs\\flutter-apk\\app-release.apk');
    exit(1);
  }

  final sha = args[shaIndex + 1].trim().toLowerCase().replaceAll(':', '');
  if (sha.length != 64) {
    print('Expected 64-char SHA-256 hex, got ${sha.length} chars.');
    exit(1);
  }

  patchConstant('androidReleaseCertSha256', sha);
  print('Pinned androidReleaseCertSha256:');
  print('  $sha');
  print('');
  print('Updated ${SupplyChainPaths.constantsFile.path}');
  print('Rebuild the release APK after pinning.');
}
