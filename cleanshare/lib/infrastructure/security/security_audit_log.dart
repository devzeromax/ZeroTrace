import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:universal_io/io.dart';

import '../../domain/storage/storage_layout.dart';
import 'secure_key_store.dart';

/// Append-only security audit trail with secret-bound hash chaining (ASI-06).
class SecurityAuditLog {
  SecurityAuditLog(this._layout);

  final ZeroTraceLayout _layout;
  String? _lastHash;
  String? _chainSecret;

  static const _chainKeyName = 'audit_chain_v1';

  File get _file => File('${_layout.logs.path}/security_audit.jsonl');

  Future<void> record({
    required String event,
    required String detail,
    Map<String, String>? metadata,
  }) async {
    await _layout.logs.create(recursive: true);
    final secret = await _chainSecretBytes();
    final prev = _lastHash ?? await _readLastHash();
    final ts = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'ts': ts,
      'event': event,
      'detail': detail,
    };
    if (metadata != null) payload['meta'] = metadata;
    if (prev != null) payload['prev'] = prev;

    final body = jsonEncode(payload);
    final mac = Hmac(sha256, secret).convert(utf8.encode(body)).toString();
    final hash = sha256.convert(utf8.encode('$body|$mac')).toString();
    final entry = {...payload, 'hash': hash, 'mac': mac};
    await _file.writeAsString(
      '${jsonEncode(entry)}\n',
      mode: FileMode.append,
      flush: true,
    );
    _lastHash = hash;
  }

  Future<Uint8List> _chainSecretBytes() async {
    if (_chainSecret != null) {
      return _hexToBytes(_chainSecret!);
    }
    var hex = await SecureKeyStore.read(_chainKeyName);
    if (hex == null || hex.length != 64) {
      final random = Random.secure();
      final seed = List<int>.generate(32, (_) => random.nextInt(256));
      hex = sha256.convert(seed).toString();
      await SecureKeyStore.write(_chainKeyName, hex);
    }
    _chainSecret = hex;
    return _hexToBytes(hex);
  }

  Future<String?> _readLastHash() async {
    if (!await _file.exists()) return null;
    final lines = await _file.readAsLines();
    if (lines.isEmpty) return null;
    try {
      final last = jsonDecode(lines.last) as Map<String, dynamic>;
      return last['hash'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Verifies HMAC chain integrity. Returns false if tampered.
  Future<bool> verifyChain() async {
    if (!await _file.exists()) return true;
    final secret = await _chainSecretBytes();
    final lines = await _file.readAsLines();
    String? prev;

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      Map<String, dynamic> entry;
      try {
        entry = jsonDecode(line) as Map<String, dynamic>;
      } catch (_) {
        return false;
      }

      final storedMac = entry['mac'] as String?;
      final storedHash = entry['hash'] as String?;
      final entryPrev = entry['prev'] as String?;

      if (entryPrev != prev) return false;

      final bodyMap = Map<String, dynamic>.from(entry)
        ..remove('mac')
        ..remove('hash');
      final body = jsonEncode(bodyMap);
      final mac = Hmac(sha256, secret).convert(utf8.encode(body)).toString();
      if (storedMac == null || mac != storedMac) return false;

      final hash = sha256.convert(utf8.encode('$body|$mac')).toString();
      if (storedHash == null || hash != storedHash) return false;
      prev = storedHash;
    }
    return true;
  }

  static Uint8List _hexToBytes(String hex) {
    final normalized = hex.toLowerCase();
    final out = Uint8List(normalized.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(normalized.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }
}
