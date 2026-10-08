// ignore_for_file: avoid_print

/// Generates (or loads) the ZeroTrace ed25519 publisher keypair and embeds the
/// public key in [pack_trust_constants.dart].
///
/// Run from cleanshare/:
///   dart run tool/embed_publisher_key.dart
///
/// Private seed: tool/keys/publisher_seed.hex (gitignored — back up offline).
library;

import 'supply_chain_utils.dart';

Future<void> main() async {
  final keyPair = await PackSigning.loadOrCreatePublisherKeyPair();
  final publicKey = await keyPair.extractPublicKey();
  final publicHex = PackSigning.bytesToHex(publicKey.bytes);

  patchConstant('publisherPublicKeyHex', publicHex);

  print('ZeroTrace publisher key embedded.');
  print('');
  print('PUBLIC KEY (embedded in app):');
  print(publicHex);
  print('');
  print('Private seed: ${SupplyChainPaths.publisherSeedFile.path}');
  print('(Keep offline. Never commit tool/keys/.)');
  print('');
  print('Next: dart run tool/sign_catalog_packs.dart');
}
