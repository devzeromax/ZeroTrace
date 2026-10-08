/// Native ZeroTrace engine capabilities (Rust cdylib).
class EngineCapabilities {
  const EngineCapabilities({
    required this.nativeLibraryLoaded,
    required this.onnxRuntimeAvailable,
    required this.version,
  });

  final bool nativeLibraryLoaded;
  final bool onnxRuntimeAvailable;
  final String? version;

  static const unavailable = EngineCapabilities(
    nativeLibraryLoaded: false,
    onnxRuntimeAvailable: false,
    version: null,
  );
}
