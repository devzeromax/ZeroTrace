import 'package:flutter/services.dart';
import 'package:universal_io/io.dart';

/// Resolves on-device paths for native engine libraries.
abstract final class PlatformEnginePaths {
  static const _channel = MethodChannel('com.cleanshare.cleanshare/engine');

  /// Absolute path to `libzerotrace_engine.so` on Android (release APK layout).
  static Future<String?> androidNativeEngineLibPath() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('nativeEngineLibPath');
    } on PlatformException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
