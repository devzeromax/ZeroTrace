/// User-facing product identity (display only — Dart package remains `cleanshare`).
abstract final class AppBranding {
  static const name = 'ZeroTrace';
  static const nameUpper = 'ZERØTRACE';
  static const tagline = 'Sanitize files privately on your device.';
  static const taglineShort = 'Share files. Leave zero trace.';
  static const description =
      'Scans, fixes, and exports stay on this device. Nothing is uploaded.';
  static const version = '1.0.0';

  /// When true, Settings/About show a beta banner and "Beta" version label.
  static const isBeta = false;
  static const versionLabel = isBeta ? '$version Beta' : version;
}
