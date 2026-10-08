import 'package:flutter_test/flutter_test.dart';

import 'package:cleanshare/infrastructure/security/app_integrity_verifier.dart';
import 'package:cleanshare/infrastructure/security/device_integrity.dart';
import 'package:cleanshare/infrastructure/security/pack_trust_constants.dart';

void main() {
  test('debug/test mode skips release cert gate', () {
    const verifier = AppIntegrityVerifier();
    // flutter_test is never kReleaseMode — gate must no-op so dev installs boot.
    expect(
      () => verifier.assertReleaseSigningCert(
        const DeviceIntegrityReport(signingCertSha256: 'deadbeef'),
      ),
      returnsNormally,
    );
  });

  test('assertPinnedSigningCert enforces pinned cert when configured', () {
    const verifier = AppIntegrityVerifier();
    final pin = PackTrustConstants.androidReleaseCertSha256.trim();
    if (pin.isEmpty) {
      expect(
        () => verifier.assertPinnedSigningCert(
          const DeviceIntegrityReport(signingCertSha256: 'abc'),
        ),
        returnsNormally,
      );
      return;
    }

    expect(
      () => verifier.assertPinnedSigningCert(
        DeviceIntegrityReport(signingCertSha256: pin),
      ),
      returnsNormally,
    );
    expect(
      () => verifier.assertPinnedSigningCert(
        const DeviceIntegrityReport(signingCertSha256: 'deadbeef'),
      ),
      throwsA(isA<AppIntegrityException>()),
    );
  });

  test('hostileRuntime combines root debug frida flags', () {
    const report = DeviceIntegrityReport(
      debuggerAttached: true,
      rootSuspected: false,
    );
    expect(report.hostileRuntime, isTrue);
  });
}
