import 'package:share_plus/share_plus.dart';

import '../constants/app_branding.dart';
import '../../models/app_models.dart';

/// Native share sheet for exports and audit summaries.
abstract final class ShareExport {
  static Future<void> shareSanitizedExport({
    required String fileName,
    required int fixesApplied,
    required int riskScoreAfter,
  }) async {
    final body = StringBuffer()
      ..writeln('${AppBranding.name} — sanitized export')
      ..writeln()
      ..writeln('File: $fileName')
      ..writeln('Fixes applied: $fixesApplied')
      ..writeln('Risk score after export: $riskScoreAfter')
      ..writeln()
      ..writeln('Processed locally on this device. No cloud upload.');

    await SharePlus.instance.share(
      ShareParams(
        text: body.toString(),
        subject: 'Sanitized file: $fileName',
      ),
    );
  }

  static Future<void> shareAuditReport(ScanSession session) async {
    final openFindings =
        session.findings.where((f) => !f.isFixed).length;
    final body = StringBuffer()
      ..writeln('${AppBranding.name} — audit report')
      ..writeln()
      ..writeln('File: ${session.fileName}')
      ..writeln('Scanned: ${session.scannedAt.toIso8601String()}')
      ..writeln('Risk score: ${session.riskScore}')
      ..writeln('Findings: ${session.findings.length} ($openFindings open)')
      ..writeln()
      ..writeln('Processed locally on this device.');

    await SharePlus.instance.share(
      ShareParams(
        text: body.toString(),
        subject: 'Audit: ${session.fileName}',
      ),
    );
  }
}
