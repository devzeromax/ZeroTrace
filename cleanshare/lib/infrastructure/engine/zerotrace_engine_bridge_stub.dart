import '../security/security_audit_log.dart';
import 'engine_capabilities.dart';

/// Web and other non-FFI platforms — Dart scanners only.
abstract final class ZeroTraceEngineBridge {
  static EngineCapabilities probe() => EngineCapabilities.unavailable;

  static String? runScanJson(String filePath) => null;

  static Future<String?> runOnnxScanJsonAsync({
    required String filePath,
    required String modelPath,
    required String packId,
  }) =>
      Future.value(null);

  static String? runOnnxScanJson({
    required String filePath,
    required String modelPath,
    required String packId,
  }) =>
      null;

  static Future<void> ensureEngineIntegrity({
    SecurityAuditLog? auditLog,
  }) async {}

  static void clearOnnxCache() {}
}
