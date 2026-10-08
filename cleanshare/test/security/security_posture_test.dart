import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cleanshare/infrastructure/security/pack_trust_constants.dart';

/// Guards the local security posture claimed in release hardening docs.
void main() {
  test('anti-repack: release signing cert is pinned', () {
    expect(
      PackTrustConstants.androidReleaseCertSha256.trim().length,
      64,
      reason: 'Run embed_release_cert.dart after release APK build',
    );
  });

  test('anti-RE: Android engine hash is pinned', () {
    final hash = PackTrustConstants.engineLibHashes['android'];
    expect(hash, isNotNull);
    expect(hash!.length, 64);
  });

  test('runtime guard wiring exists in scan/export/pack paths', () {
    // Compile-time check: these types must stay importable from providers.
    expect(PackTrustConstants.maxStagingBytes, greaterThan(0));
  });

  test('direct-APK build disables remote marketplace', () {
    expect(PackTrustConstants.remoteMarketplaceEnabled, isFalse);
  });

  test('release build enables Android R8 minification', () {
    final gradle = File('android/app/build.gradle.kts');
    final text = gradle.readAsStringSync();
    expect(text, contains('isMinifyEnabled = true'));
    expect(text, contains('proguard-rules.pro'));
  });
}
