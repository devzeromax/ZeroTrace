import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:universal_io/io.dart';

/// Native device integrity signals (Android). Used for local anti-tamper policy.
class DeviceIntegrityReport {
  const DeviceIntegrityReport({
    this.signingCertSha256,
    this.debuggerAttached = false,
    this.emulator = false,
    this.rootSuspected = false,
    this.fridaSuspected = false,
  });

  final String? signingCertSha256;
  final bool debuggerAttached;
  final bool emulator;
  final bool rootSuspected;
  final bool fridaSuspected;

  bool get hostileRuntime =>
      debuggerAttached || fridaSuspected || rootSuspected;

  factory DeviceIntegrityReport.fromMap(Map<dynamic, dynamic> map) {
    return DeviceIntegrityReport(
      signingCertSha256: map['signingCertSha256'] as String?,
      debuggerAttached: map['debuggerAttached'] == true,
      emulator: map['emulator'] == true,
      rootSuspected: map['rootSuspected'] == true,
      fridaSuspected: map['fridaSuspected'] == true,
    );
  }

  static const safe = DeviceIntegrityReport();
}

class DeviceIntegrityException implements Exception {
  DeviceIntegrityException(this.message);
  final String message;

  @override
  String toString() => message;
}

abstract final class DeviceIntegrity {
  static const _channel = MethodChannel('com.cleanshare.cleanshare/engine');

  static Future<DeviceIntegrityReport> load() async {
    if (!Platform.isAndroid) return DeviceIntegrityReport.safe;
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'deviceIntegrityReport',
      );
      if (raw == null) {
        if (kReleaseMode) {
          throw DeviceIntegrityException(
            'Device integrity check returned no data. '
            'Reinstall the official ZeroTrace APK.',
          );
        }
        return DeviceIntegrityReport.safe;
      }
      return DeviceIntegrityReport.fromMap(raw);
    } on DeviceIntegrityException {
      rethrow;
    } catch (_) {
      if (kReleaseMode) {
        throw DeviceIntegrityException(
          'Device integrity check failed. '
          'Reinstall the official ZeroTrace APK.',
        );
      }
      return DeviceIntegrityReport.safe;
    }
  }
}
