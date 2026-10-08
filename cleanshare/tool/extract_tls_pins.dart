// ignore_for_file: avoid_print

/// Fetches TLS certificate SPKI SHA-256 pins for ZeroTrace CDN hosts and
/// patches [PackTrustConstants.tlsSpkiPins] when hosts are reachable.
///
/// Run when CDN is live:
///   dart run tool/extract_tls_pins.dart
///
/// Or set pins manually (when DNS is not live yet):
///   dart run tool/extract_tls_pins.dart --pin releases.zerotrace.app=abc123...
///   dart run tool/extract_tls_pins.dart --pin cdn.zerotrace.app=def456...
library;

import 'dart:io';

import 'package:crypto/crypto.dart';

import 'supply_chain_utils.dart';

Future<void> main(List<String> args) async {
  final manualPins = _parseManualPins(args);
  if (manualPins.isNotEmpty) {
    patchTlsPins(manualPins);
    print('Updated ${SupplyChainPaths.constantsFile.path} with manual pins.');
    return;
  }

  final hosts = args.isEmpty
      ? ['releases.zerotrace.app', 'cdn.zerotrace.app']
      : args.where((a) => !a.startsWith('--')).toList();

  final collected = <String, List<String>>{};

  for (final host in hosts) {
    try {
      final socket = await SecureSocket.connect(
        host,
        443,
        onBadCertificate: (_) => true,
      );
      final cert = socket.peerCertificate;
      await socket.close();
      if (cert == null) {
        print('$host: no certificate');
        continue;
      }
      final spkiPin = sha256.convert(cert.der).toString();
      print('$host SPKI/der pin: sha256/$spkiPin');
      collected[host] = [spkiPin];
    } catch (e) {
      print('$host: unreachable ($e)');
    }
  }

  if (collected.isEmpty) {
    print('');
    print('No pins collected — CDN hosts are not live yet.');
    print('');
    print('Bundled marketplace packs still work without TLS pins.');
    print('Remote catalog/downloads use host allowlist + system CA until pins are set.');
    print('');
    print('When CDN is live, run:');
    print('  dart run tool/extract_tls_pins.dart');
    print('');
    print('Or embed pins manually after you have the cert hash:');
    print('  dart run tool/extract_tls_pins.dart --pin releases.zerotrace.app=SHA256');
    exit(0);
  }

  patchTlsPins(collected);
  print('');
  print('Updated ${SupplyChainPaths.constantsFile.path}');
}

Map<String, List<String>> _parseManualPins(List<String> args) {
  final pins = <String, List<String>>{};
  for (var i = 0; i < args.length; i++) {
    if (args[i] != '--pin' || i + 1 >= args.length) continue;
    final pair = args[i + 1];
    final eq = pair.indexOf('=');
    if (eq <= 0) continue;
    final host = pair.substring(0, eq).trim().toLowerCase();
    final hash = pair.substring(eq + 1).trim().toLowerCase();
    if (host.isEmpty || hash.length != 64) {
      print('Invalid --pin value: $pair (expected host=64-char-sha256)');
      exit(1);
    }
    pins[host] = [hash];
    i++;
  }
  return pins;
}

void patchTlsPins(Map<String, List<String>> pinsByHost) {
  final file = SupplyChainPaths.constantsFile;
  var content = file.readAsStringSync();

  final buffer = StringBuffer('  static const tlsSpkiPins = <String, List<String>>{\n');
  for (final host in ['releases.zerotrace.app', 'cdn.zerotrace.app']) {
    final pins = pinsByHost[host] ?? [];
    final pinList = pins.map((p) => "'$p'").join(', ');
    buffer.writeln("    '$host': [$pinList],");
  }
  buffer.write('  };');

  content = content.replaceFirst(
    RegExp(
      r'static const tlsSpkiPins = <String, List<String>>\{[\s\S]*?\};',
    ),
    buffer.toString(),
  );

  file.writeAsStringSync(content);
}
