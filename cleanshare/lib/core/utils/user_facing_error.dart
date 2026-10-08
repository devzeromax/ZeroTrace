import 'package:flutter/foundation.dart';

import '../../infrastructure/engine/engine_bootstrap_exception.dart';
import '../../infrastructure/marketplace/manifest_verifier.dart';
import '../../infrastructure/marketplace/marketplace_service.dart';
import '../../infrastructure/marketplace/model_download_manager.dart';
import '../../infrastructure/export/export_engine.dart';
import '../../infrastructure/security/app_integrity_verifier.dart';
import '../../infrastructure/security/device_integrity.dart';
import '../../infrastructure/security/catalog_integrity_verifier.dart';
import '../../infrastructure/security/pack_trust_policy.dart';
import '../../infrastructure/security/runtime_security_guard.dart';

/// Maps technical exceptions to plain-language copy for UI surfaces.
abstract final class UserFacingError {
  /// Cold-start / engine bootstrap failures (Android-aware copy).
  static String bootstrapMessage(Object error) {
    if (error is EngineBootstrapException) return error.message;
    if (error is AppIntegrityException) return error.message;
    if (error is DeviceIntegrityException) return error.message;
    if (error is RuntimeSecurityException) return error.message;

    final raw = error.toString();
    final lower = raw.toLowerCase();

    if (lower.contains('integrity') || lower.contains('unofficial')) {
      return 'The privacy scanner engine could not be verified on this device. '
          'Install the official signed ZeroTrace release APK and try again.';
    }
    if (lower.contains('could not read app signing certificate')) {
      return 'Could not verify this install\'s signature. Reinstall the official ZeroTrace APK.';
    }
    if (lower.contains('native engine failed integrity')) {
      return 'The scanner engine failed integrity checks. Reinstall the latest ZeroTrace APK.';
    }

    return message(error);
  }

  static String message(Object error) {
    if (error is MarketplaceException) {
      return error.message;
    }
    if (error is ModelDownloadException) {
      return error.message;
    }
    if (error is ExportException) {
      return error.message;
    }
    if (error is PathGuardException) {
      return 'File path is outside secure storage. Re-upload the image and try again.';
    }
    if (error is CatalogIntegrityException) {
      return 'Pack catalog could not be verified. Pull down to refresh.';
    }
    if (error is PackTrustException) {
      return error.message;
    }
    if (error is EngineBootstrapException) {
      if (error.message.toLowerCase().contains('integrity') ||
          error.message.toLowerCase().contains('unofficial')) {
        return 'The privacy scanner engine could not be verified on this device. '
            'Install the official signed ZeroTrace release APK and try again.';
      }
      return error.message;
    }
    if (error is RuntimeSecurityException) {
      return error.message;
    }
    if (error is AppIntegrityException) {
      return error.message;
    }
    if (error is DeviceIntegrityException) {
      return error.message;
    }
    if (error is ManifestVerificationException) {
      return error.message;
    }
    if (error is FormatException) {
      return 'Local app data looks corrupted. Pull down to refresh or clear scan data in Settings.';
    }

    final raw = error.toString();
    final lower = raw.toLowerCase();

    if (lower.contains('unsupported operation')) {
      if (lower.contains('namespace')) {
        return 'This feature needs local file storage. Use the Windows app for full marketplace downloads.';
      }
      return 'This feature is not available in the browser. Use the mobile or desktop app.';
    }
    if (lower.contains('type ') && lower.contains('is not a subtype')) {
      return 'App data format mismatch. Pull down to refresh or restart the app.';
    }
    if (lower.contains('zerotracepaths not initialized')) {
      return 'Storage is still starting. Pull down to refresh, or restart the app.';
    }
    if (lower.contains('missingpluginexception') ||
        lower.contains('path_provider')) {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        return 'Storage could not start on this device. Reinstall the latest ZeroTrace APK.';
      }
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
        return 'A device feature is unavailable. Try restarting the Windows desktop app.';
      }
      return 'A device feature is unavailable in the browser. Try the Windows desktop app.';
    }
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection refused')) {
      return 'No internet connection. Check your network and try again.';
    }
    if (lower.contains('timeout')) {
      return 'The request timed out. Check your connection and try again.';
    }
    if (lower.contains('built-in packs cannot be removed') ||
        lower.contains('built-in models cannot be removed')) {
      return 'Built-in packs stay installed so scans always work offline.';
    }
    if (lower.contains('pack downloads require') ||
        lower.contains('model downloads require')) {
      return 'Pack downloads need the mobile or desktop app. Built-in scanners work in the browser.';
    }
    if (lower.contains('bundled pack') && lower.contains('missing')) {
      return 'Pack files are missing from this install. Stop the app and run a full rebuild, then try again.';
    }
    if (lower.contains('no download source')) {
      return 'This pack has no install source in the current build.';
    }
    if (lower.contains('not available on this device')) {
      return raw.contains('MarketplaceException')
          ? raw.replaceFirst('MarketplaceException: ', '')
          : 'This pack is not available on your device yet.';
    }
    if (lower.contains('checksum mismatch') ||
        lower.contains('manifestverificationexception')) {
      return 'Pack file could not be verified. Try again or check for an app update.';
    }

    return 'Something went wrong. Please try again.';
  }

  static String? recoveryHint(Object error) {
    final lower = error.toString().toLowerCase();
    if (lower.contains('namespace') ||
        lower.contains('model downloads require') ||
        lower.contains('windows desktop')) {
      return 'Run flutter run -d windows on your PC for full downloads.';
    }
    if (lower.contains('zerotracepaths')) {
      return 'Pull to refresh this screen.';
    }
    if (lower.contains('socket') || lower.contains('timeout')) {
      return 'Updates work offline — you can try again later.';
    }
    return null;
  }
}
