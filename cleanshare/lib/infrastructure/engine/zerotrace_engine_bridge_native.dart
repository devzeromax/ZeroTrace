import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../security/engine_integrity.dart';
import '../security/security_audit_log.dart';
import 'engine_capabilities.dart';
import 'onnx_isolate_runner.dart';
import 'platform_engine_paths.dart';

/// Loads `zerotrace_engine` native library when present on disk.
abstract final class ZeroTraceEngineBridge {
  static DynamicLibrary? _lib;

  static EngineCapabilities probe() {
    try {
      _lib ??= _openLibrary();
      final lib = _lib!;
      final versionFn = lib
          .lookup<NativeFunction<Pointer<Utf8> Function()>>(
            'zerotrace_engine_version',
          )
          .asFunction<Pointer<Utf8> Function()>();
      final onnxFn = lib
          .lookup<NativeFunction<Int32 Function()>>('zerotrace_onnx_available')
          .asFunction<int Function()>();

      final versionPtr = versionFn();
      final version = versionPtr.toDartString();
      malloc.free(versionPtr);

      return EngineCapabilities(
        nativeLibraryLoaded: true,
        onnxRuntimeAvailable: onnxFn() != 0,
        version: version,
      );
    } catch (e, stack) {
      debugPrint('ZeroTrace engine probe failed: $e\n$stack');
      return EngineCapabilities.unavailable;
    }
  }

  static Future<String?> runOnnxScanJsonAsync({
    required String filePath,
    required String modelPath,
    required String packId,
  }) async {
    try {
      _lib ??= _openLibrary();
      final dllPath = _resolveDllPath();
      return runOnnxScanOnBackground(
        dllPath: dllPath,
        filePath: filePath,
        modelPath: modelPath,
        packId: packId,
      );
    } catch (_) {
      return null;
    }
  }

  static String? runOnnxScanJson({
    required String filePath,
    required String modelPath,
    required String packId,
  }) {
    final lib = _lib;
    if (lib == null) return null;

    try {
      final scanFn = lib.lookup<
          NativeFunction<
              Pointer<Utf8> Function(
                Pointer<Utf8>,
                Pointer<Utf8>,
                Pointer<Utf8>,
              )>>('zerotrace_run_onnx_scan_json').asFunction<
          Pointer<Utf8> Function(
            Pointer<Utf8>,
            Pointer<Utf8>,
            Pointer<Utf8>,
          )>();
      final freeFn = lib
          .lookup<NativeFunction<Void Function(Pointer<Utf8>)>>(
            'zerotrace_free_string',
          )
          .asFunction<void Function(Pointer<Utf8>)>();

      final filePtr = filePath.toNativeUtf8();
      final modelPtr = modelPath.toNativeUtf8();
      final packPtr = packId.toNativeUtf8();
      final resultPtr = scanFn(filePtr, modelPtr, packPtr);
      malloc.free(filePtr);
      malloc.free(modelPtr);
      malloc.free(packPtr);

      if (resultPtr == nullptr) return null;
      final json = resultPtr.toDartString();
      freeFn(resultPtr);
      return json;
    } catch (_) {
      return null;
    }
  }

  /// Drops cached ONNX sessions after pack uninstall or model swap.
  static void clearOnnxCache() {
    final lib = _lib;
    if (lib == null) return;
    try {
      lib
          .lookup<NativeFunction<Void Function()>>('zerotrace_clear_onnx_cache')
          .asFunction<void Function()>()();
    } catch (_) {
      // Older engine builds may not export the symbol.
    }
  }

  static String? runScanJson(String filePath) {
    final lib = _lib;
    if (lib == null) return null;

    try {
      final scanFn = lib
          .lookup<NativeFunction<Pointer<Utf8> Function(Pointer<Utf8>)>>(
            'zerotrace_run_scan_json',
          )
          .asFunction<Pointer<Utf8> Function(Pointer<Utf8>)>();
      final freeFn = lib
          .lookup<NativeFunction<Void Function(Pointer<Utf8>)>>(
            'zerotrace_free_string',
          )
          .asFunction<void Function(Pointer<Utf8>)>();

      final pathPtr = filePath.toNativeUtf8();
      final resultPtr = scanFn(pathPtr);
      malloc.free(pathPtr);

      if (resultPtr == nullptr) return null;
      final json = resultPtr.toDartString();
      freeFn(resultPtr);
      return json;
    } catch (_) {
      return null;
    }
  }

  static DynamicLibrary _openLibrary() {
    if (Platform.isIOS) {
      return DynamicLibrary.process();
    }
    if (Platform.isAndroid) {
      return _openAndroidLibrary();
    }
    return DynamicLibrary.open(_resolveDllPath());
  }

  /// Android may not resolve JNI libs by bare name on all devices.
  static DynamicLibrary _openAndroidLibrary() {
    const libName = 'libzerotrace_engine.so';
    const appLibDir = '/data/data/com.cleanshare.cleanshare/lib';
    final errors = <Object>[];
    for (final path in [libName, '$appLibDir/$libName']) {
      try {
        return DynamicLibrary.open(path);
      } catch (e) {
        errors.add('$path: $e');
      }
    }
    throw StateError('Failed to load $libName ($errors)');
  }

  static String _resolveDllPath() {
    if (Platform.isWindows) {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      final bundled = p.join(exeDir, 'zerotrace_engine.dll');

      if (kReleaseMode) {
        if (!File(bundled).existsSync()) {
          throw StateError('zerotrace_engine.dll not found beside executable.');
        }
        return bundled;
      }

      final candidates = [
        bundled,
        r'engine\zerotrace_engine\target\release\zerotrace_engine.dll',
        r'engine\zerotrace_engine\target\debug\zerotrace_engine.dll',
      ];
      for (final path in candidates) {
        if (File(path).existsSync()) {
          return path;
        }
      }
      throw StateError('zerotrace_engine.dll not found.');
    } else if (Platform.isLinux) {
      return 'libzerotrace_engine.so';
    } else if (Platform.isMacOS) {
      return 'libzerotrace_engine.dylib';
    } else if (Platform.isAndroid) {
      return 'libzerotrace_engine.so';
    } else if (Platform.isIOS) {
      // DynamicLibrary.process() has no path — ONNX isolate not used on iOS here.
      throw UnsupportedError('ONNX background isolate requires a library path.');
    }
    throw UnsupportedError('Platform not supported for native engine');
  }

  /// Call before first probe in release builds.
  static Future<void> ensureEngineIntegrity({
    SecurityAuditLog? auditLog,
  }) async {
    if (kDebugMode) return;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final libName = Platform.isWindows
          ? 'zerotrace_engine.dll'
          : Platform.isMacOS
              ? 'libzerotrace_engine.dylib'
              : 'libzerotrace_engine.so';
      final libPath = p.join(
        p.dirname(Platform.resolvedExecutable),
        libName,
      );
      final ok = await EngineIntegrity.verifyAtPath(libPath, auditLog: auditLog);
      if (!ok) {
        throw StateError('Native engine failed integrity verification.');
      }
      return;
    }

    if (Platform.isAndroid) {
      final platformPath = await PlatformEnginePaths.androidNativeEngineLibPath();
      final candidates = <String>[
        if (platformPath != null && platformPath.isNotEmpty) platformPath,
        'libzerotrace_engine.so',
      ];
      final errors = <Object>[];
      for (final path in candidates) {
        final ok = await EngineIntegrity.verifyAtPath(path, auditLog: auditLog);
        if (ok) return;
        errors.add(path);
      }
      throw StateError(
        'Native engine failed integrity verification ($errors).',
      );
    }
  }
}
