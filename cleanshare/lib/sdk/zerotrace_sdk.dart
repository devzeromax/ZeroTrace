/// ZeroTrace third-party plugin manifest schema (`zerotrace.plugin.json`).
///
/// ```json
/// {
///   "id": "acme-face-blur",
///   "name": "ACME Face Blur",
///   "version": "1.2.0",
///   "developer": "ACME Corp",
///   "category": "face_detection",
///   "capabilities": ["faces"],
///   "model": {
///     "format": "onnx",
///     "file": "face.onnx",
///     "sha256": "<64-char-hex>",
///     "sizeBytes": 16777216
///   },
///   "minAppVersion": "1.0.0",
///   "license": "MIT",
///   "signature": "ed25519:<base64>"
/// }
/// ```
///
/// SDK publishing flow (future):
/// 1. Author implements `ScanPlugin` in Rust or Dart FFI adapter.
/// 2. Package ONNX + manifest into a signed `.zip`.
/// 3. Submit to marketplace registry (official / verified / community tiers).
/// 4. ZeroTrace downloads, verifies SHA256 + optional ed25519 signature.
/// 5. PluginDiscovery auto-registers without app update.
library;

export '../domain/marketplace/marketplace_models.dart' show PluginManifest;
export '../domain/scanner/scanner_models.dart' show ScanPlugin, PluginFinding;
