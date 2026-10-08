import 'package:flutter/services.dart';

/// Android Keystore / iOS Keychain backed secret storage (no SharedPreferences).
abstract final class PlatformSecureStorage {
  static const _channel = MethodChannel('com.cleanshare.cleanshare/secure_store');

  static Future<bool> get isSupported async {
    try {
      final ok = await _channel.invokeMethod<bool>('isSupported');
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> read(String key) async {
    try {
      return await _channel.invokeMethod<String>('read', {'key': key});
    } on PlatformException {
      return null;
    }
  }

  static Future<void> write(String key, String value) async {
    await _channel.invokeMethod<void>('write', {'key': key, 'value': value});
  }

  static Future<void> delete(String key) async {
    await _channel.invokeMethod<void>('delete', {'key': key});
  }
}
