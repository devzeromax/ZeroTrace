import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_io/io.dart';

import 'platform_secure_storage.dart';
import 'windows_dpapi_key_store.dart'
    if (dart.library.html) 'windows_dpapi_key_store_stub.dart';

/// OS-backed secret storage.
/// - Windows: DPAPI-protected files
/// - Android/iOS: Keystore / Keychain via platform channel
/// - Web: SharedPreferences (expected limitation)
abstract final class SecureKeyStore {
  static const _legacyPrefix = 'zerotrace_secure_';
  static const _secretDirName = 'ZeroTrace/.secrets';

  static Future<String?> read(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('$_legacyPrefix$key');
    }

    if (Platform.isAndroid || Platform.isIOS) {
      if (await PlatformSecureStorage.isSupported) {
        final value = await PlatformSecureStorage.read(key);
        if (value != null && value.isNotEmpty) return value;
        return _migrateLegacyMobile(key);
      }
    }

    if (Platform.isWindows) {
      try {
        final file = await _secretFile(key);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final value = WindowsDpapiKeyStore.readFileBytes(bytes);
          if (value != null && value.isNotEmpty) return value;
        }
      } catch (_) {
        // Test VMs / sandboxes without path_provider — fall back to prefs.
      }
      return _migrateLegacy(key);
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_legacyPrefix$key');
  }

  static Future<void> write(String key, String value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_legacyPrefix$key', value);
      return;
    }

    if (Platform.isAndroid || Platform.isIOS) {
      if (await PlatformSecureStorage.isSupported) {
        await PlatformSecureStorage.write(key, value);
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('$_legacyPrefix$key');
        return;
      }
    }

    if (Platform.isWindows) {
      try {
        final encrypted = WindowsDpapiKeyStore.writeFileBytes(value);
        if (encrypted == null) {
          throw StateError('Windows DPAPI failed to protect secret for $key.');
        }
        final file = await _secretFile(key);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(encrypted, flush: true);
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('$_legacyPrefix$key');
        return;
      } catch (_) {
        // Fall back to prefs when DPAPI / path_provider unavailable (tests).
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_legacyPrefix$key', value);
  }

  static Future<void> delete(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_legacyPrefix$key');
      return;
    }

    if (Platform.isAndroid || Platform.isIOS) {
      if (await PlatformSecureStorage.isSupported) {
        await PlatformSecureStorage.delete(key);
      }
    }

    if (Platform.isWindows) {
      try {
        final file = await _secretFile(key);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // path_provider unavailable in tests.
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_legacyPrefix$key');
  }

  /// Removes all known encryption / audit chain secrets.
  static Future<void> wipeAllSecrets() async {
    const keys = ['master_key_v1', 'audit_chain_v1'];
    for (final key in keys) {
      await delete(key);
    }
  }

  static Future<File> _secretFile(String key) async {
    final base = await getApplicationSupportDirectory();
    final safeName = key.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return File('${base.path}/$_secretDirName/$safeName.dpapi');
  }

  static Future<String?> _migrateLegacy(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString('$_legacyPrefix$key');
    if (legacy == null || legacy.isEmpty) return null;
    await write(key, legacy);
    return legacy;
  }

  static Future<String?> _migrateLegacyMobile(String key) async {
    return _migrateLegacy(key);
  }
}
