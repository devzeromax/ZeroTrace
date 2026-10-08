import 'package:flutter/foundation.dart';

import 'device_integrity.dart';
import 'pack_trust_constants.dart';

/// Verifies the installed APK matches the official release signing certificate.
class AppIntegrityVerifier {
  const AppIntegrityVerifier();

  void assertReleaseSigningCert(DeviceIntegrityReport report) {
    // Signing-cert pinning only applies to the Android *release* APK.
    // Debug/profile sideloads use the debug keystore — enforcing the release
    // pin there bricks boot with "Unofficial build detected" (dev installs).
    if (kIsWeb ||
        !kReleaseMode ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    assertPinnedSigningCert(report);
  }

  /// Pin comparison only — used by release gate and unit tests.
  @visibleForTesting
  void assertPinnedSigningCert(DeviceIntegrityReport report) {
    final expected = PackTrustConstants.androidReleaseCertSha256.trim();
    if (expected.isEmpty) {
      debugPrint(
        '[INTEGRITY] Release signing cert not pinned. '
        'Run: dart run tool/embed_release_cert.dart --sha256 <cert-sha256>',
      );
      return;
    }

    final actual = report.signingCertSha256?.toLowerCase();
    if (actual == null || actual.isEmpty) {
      throw AppIntegrityException(
        'Could not read app signing certificate.',
      );
    }
    if (actual != expected.toLowerCase()) {
      throw AppIntegrityException(
        'Unofficial build detected. Install the signed ZeroTrace release APK.',
      );
    }
  }
}

class AppIntegrityException implements Exception {
  AppIntegrityException(this.message);
  final String message;

  @override
  String toString() => message;
}
