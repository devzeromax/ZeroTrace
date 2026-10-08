import 'package:cleanshare/core/utils/export_status_steps.dart';
import 'package:cleanshare/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('null session uses neutral on-device copy', () {
    final steps = ExportStatusSteps.forSession(null);
    expect(steps.first, contains('Sanitizing on your device'));
    expect(steps.any((s) => s.contains('Blurring')), isFalse);
  });

  test('face findings claim face blur only', () {
    final session = ScanSession(
      id: 's1',
      fileName: 'a.jpg',
      fileSize: '1 MB',
      fileType: 'JPEG',
      scannedAt: DateTime(2026, 1, 1),
      riskScore: 40,
      findings: const [
        PrivacyFinding(
          id: 'f1',
          category: 'Faces',
          title: 'Face',
          description: 'Face',
          level: RiskLevel.high,
        ),
      ],
    );
    final steps = ExportStatusSteps.forSession(session);
    expect(steps.any((s) => s.contains('faces')), isTrue);
    expect(steps.any((s) => s.contains('QR')), isFalse);
  });
}
