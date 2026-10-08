import '../../models/app_models.dart';

/// Honest, findings-driven status lines for export processing UI.
abstract final class ExportStatusSteps {
  /// Builds progressive status copy from the session (never claims work that
  /// was not requested by findings / applied fixes).
  static List<String> forSession(ScanSession? session) {
    if (session == null) return _neutral;

    final categories = session.findings
        .where((f) => !f.isFixed)
        .map((f) => f.category.toLowerCase())
        .toSet();
    // Also respect toggles already applied as fixed — export still runs them.
    final allCategories = session.findings.map((f) => f.category.toLowerCase()).toSet();
    final cats = {...categories, ...allCategories};

    final steps = <String>['Preparing a local sanitized copy…'];

    if (cats.any((c) => c.contains('metadata') || c.contains('exif') || c.contains('gps'))) {
      steps.add('Removing GPS, device info, and metadata…');
    }
    if (cats.any((c) => c.contains('face'))) {
      steps.add('Blurring detected faces…');
    }
    if (cats.any((c) => c.contains('plate') || c.contains('vehicle') || c.contains('license'))) {
      steps.add('Redacting vehicle and plate regions…');
    }
    if (cats.any((c) => c.contains('qr') || c.contains('barcode'))) {
      steps.add('Sanitizing QR and barcode data…');
    }
    if (cats.any((c) =>
        c.contains('document') ||
        c.contains('ocr') ||
        c.contains('pii') ||
        c.contains('personal') ||
        c.contains('text'))) {
      steps.add('Redacting sensitive text…');
    }
    if (cats.any((c) => c.contains('secret') || c.contains('token') || c.contains('key'))) {
      steps.add('Scrubbing secrets and tokens…');
    }

    if (steps.length == 1) {
      return _neutral;
    }

    steps.add('Packaging your safe copy…');
    return steps;
  }

  static const _neutral = [
    'Sanitizing on your device…',
    'Writing a local safe copy…',
    'Packaging your safe copy…',
  ];
}
