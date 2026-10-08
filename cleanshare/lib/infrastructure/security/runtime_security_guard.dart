import 'package:flutter/foundation.dart';

import '../engine/zerotrace_engine_bridge.dart';
import 'app_integrity_verifier.dart';
import 'device_integrity.dart';
import 'security_audit_log.dart';

/// Central local security policy — no server required.
class RuntimeSecurityGuard {
  RuntimeSecurityGuard({
    AppIntegrityVerifier? appIntegrity,
    SecurityAuditLog? auditLog,
  })  : _appIntegrity = appIntegrity ?? const AppIntegrityVerifier(),
        _audit = auditLog;

  final AppIntegrityVerifier _appIntegrity;
  final SecurityAuditLog? _audit;

  DeviceIntegrityReport? _cachedDeviceReport;

  Future<DeviceIntegrityReport> deviceReport({bool forceRefresh = false}) async {
    if (forceRefresh) {
      return _cachedDeviceReport = await DeviceIntegrity.load();
    }
    return _cachedDeviceReport ??= await DeviceIntegrity.load();
  }

  /// Cold-start checks: signing cert + engine + device audit.
  Future<void> assertBootstrap({SecurityAuditLog? auditLog}) async {
    final audit = auditLog ?? _audit;
    final report = await deviceReport();
    _appIntegrity.assertReleaseSigningCert(report);

    await ZeroTraceEngineBridge.ensureEngineIntegrity(auditLog: audit);

    if (audit != null) {
      final chainOk = await audit.verifyChain();
      if (!chainOk) {
        await audit.record(
          event: 'audit_chain_tampered',
          detail: 'Security audit log failed verification.',
        );
      }
    }

    if (report.hostileRuntime) {
      await audit?.record(
        event: 'hostile_runtime_detected',
        detail: _hostileDetail(report),
      );
      if (kReleaseMode) {
        throw RuntimeSecurityException(
          'ZeroTrace cannot run on modified, rooted, or debugged devices. '
          'Install the official APK on a standard device.',
        );
      }
    }
    if (report.emulator && kReleaseMode) {
      await audit?.record(
        event: 'emulator_detected',
        detail: 'Release build running on emulator.',
      );
    }
  }

  /// Re-verify engine + device before scan, export, or pack install.
  Future<void> assertSensitiveOperation({
    required String operation,
    bool requiresNeuralEngine = false,
    SecurityAuditLog? auditLog,
  }) async {
    if (kIsWeb) return;

    final audit = auditLog ?? _audit;
    await ZeroTraceEngineBridge.ensureEngineIntegrity(auditLog: audit);

    final report = await deviceReport(forceRefresh: kReleaseMode);
    if (kReleaseMode && report.hostileRuntime) {
      await audit?.record(
        event: 'operation_blocked',
        detail: '$operation blocked: ${_hostileDetail(report)}',
      );
      throw RuntimeSecurityException(
        'This action is disabled on modified or debugged devices '
        'to protect your privacy. Use a standard device build.',
      );
    }

    if (kReleaseMode && requiresNeuralEngine && report.emulator) {
      throw RuntimeSecurityException(
        'Neural scanning is disabled on emulators in release builds.',
      );
    }
  }

  Future<bool> neuralPacksAllowed() async {
    if (kIsWeb || kDebugMode) return true;
    final report = await deviceReport();
    return !report.hostileRuntime && !report.emulator;
  }

  String _hostileDetail(DeviceIntegrityReport report) {
    final parts = <String>[];
    if (report.debuggerAttached) parts.add('debugger');
    if (report.rootSuspected) parts.add('root');
    if (report.fridaSuspected) parts.add('frida');
    return parts.join(', ');
  }
}

class RuntimeSecurityException implements Exception {
  RuntimeSecurityException(this.message);
  final String message;

  @override
  String toString() => message;
}
