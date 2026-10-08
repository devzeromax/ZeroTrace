import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:universal_io/io.dart';

import 'secure_key_store.dart';

/// AES-GCM encryption for sensitive settings files (scan history).
class SecureSettingsCipher {
  SecureSettingsCipher();

  static const _keyName = 'master_key_v1';
  final _algorithm = AesGcm.with256bits();

  Future<SecretKey> _masterKey() async {
    var hex = await SecureKeyStore.read(_keyName);
    if (hex == null || hex.length != 64) {
      final seed = await _algorithm.newSecretKey();
      final bytes = await seed.extractBytes();
      hex = _bytesToHex(Uint8List.fromList(bytes));
      await SecureKeyStore.write(_keyName, hex);
    }
    return SecretKey(_hexToBytes(hex));
  }

  Future<void> writeEncryptedFile(File file, String plaintext) async {
    final key = await _masterKey();
    final secretBox = await _algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
    );
    final payload = jsonEncode({
      'v': 1,
      'nonce': _bytesToHex(Uint8List.fromList(secretBox.nonce)),
      'cipher': _bytesToHex(Uint8List.fromList(secretBox.cipherText)),
      'mac': _bytesToHex(Uint8List.fromList(secretBox.mac.bytes)),
    });
    await file.parent.create(recursive: true);
    await file.writeAsString(payload, flush: true);
  }

  Future<String?> readEncryptedFile(File file) async {
    if (!await file.exists()) return null;
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final key = await _masterKey();
      final secretBox = SecretBox(
        _hexToBytes(json['cipher'] as String),
        nonce: _hexToBytes(json['nonce'] as String),
        mac: Mac(_hexToBytes(json['mac'] as String)),
      );
      final clear = await _algorithm.decrypt(secretBox, secretKey: key);
      return utf8.decode(clear);
    } catch (_) {
      return null;
    }
  }

  static String _bytesToHex(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static Uint8List _hexToBytes(String hex) {
    final out = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }
}
