import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'pack_trust_constants.dart';
import 'security_audit_log.dart';

/// Verifies native engine binary integrity before FFI load.
abstract final class EngineIntegrity {
  static Future<bool> verifyAtPath(
    String libPath, {
    SecurityAuditLog? auditLog,
  }) async {
    final file = File(libPath);
    if (!await file.exists()) {
      await auditLog?.record(
        event: 'engine_lib_missing',
        detail: 'Native library not found at $libPath',
        metadata: {'path': libPath},
      );
      return false;
    }

    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes).toString();
    final expected = _expectedHash;

    if (expected == null || expected.isEmpty) {
      await auditLog?.record(
        event: 'engine_hash_not_pinned',
        detail: 'No hash pinned for ${Platform.operatingSystem}; '
            'computed $digest. Pin this value for release integrity checks.',
        metadata: {'path': libPath, 'computed_hash': digest},
      );
      return !kReleaseMode;
    }

    if (kDebugMode) {
      if (digest != expected && auditLog != null) {
        await auditLog.record(
          event: 'engine_hash_mismatch_debug',
          detail: 'Lib hash $digest != pinned $expected',
          metadata: {'path': libPath},
        );
      }
      return true;
    }

    if (digest != expected) {
      await auditLog?.record(
        event: 'engine_hash_mismatch',
        detail: 'RELEASE lib hash $digest != pinned $expected — BLOCKED',
        metadata: {'path': libPath},
      );
      return false;
    }
    return true;
  }

  static Future<bool> verifyDllAtPath(
    String dllPath, {
    SecurityAuditLog? auditLog,
  }) =>
      verifyAtPath(dllPath, auditLog: auditLog);

  static String? get _expectedHash {
    if (Platform.isWindows) {
      return PackTrustConstants.engineDllSha256Windows;
    }
    return PackTrustConstants.engineLibHashes[Platform.operatingSystem];
  }
}
