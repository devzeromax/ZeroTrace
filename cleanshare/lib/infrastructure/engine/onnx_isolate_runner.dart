import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

/// Runs ONNX FFI on a background isolate so inference never blocks the UI thread.
Future<String?> runOnnxScanOnBackground({
  required String dllPath,
  required String filePath,
  required String modelPath,
  required String packId,
}) {
  final args = _OnnxScanMessage(
    dllPath: dllPath,
    filePath: filePath,
    modelPath: modelPath,
    packId: packId,
  );
  return Isolate.run(() => _runOnnxScan(args));
}

class _OnnxScanMessage {
  const _OnnxScanMessage({
    required this.dllPath,
    required this.filePath,
    required this.modelPath,
    required this.packId,
  });

  final String dllPath;
  final String filePath;
  final String modelPath;
  final String packId;
}

String? _runOnnxScan(_OnnxScanMessage args) {
  try {
    final lib = DynamicLibrary.open(args.dllPath);
    final scanFn = lib
        .lookup<
            NativeFunction<
                Pointer<Utf8> Function(
                  Pointer<Utf8>,
                  Pointer<Utf8>,
                  Pointer<Utf8>,
                )>>('zerotrace_run_onnx_scan_json')
        .asFunction<
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

    final filePtr = args.filePath.toNativeUtf8();
    final modelPtr = args.modelPath.toNativeUtf8();
    final packPtr = args.packId.toNativeUtf8();
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
