import 'package:flutter_test/flutter_test.dart';

import 'package:cleanshare/core/utils/history_metrics.dart';
import 'package:cleanshare/models/app_models.dart';

void main() {
  group('HistoryMetrics', () {
    test('scansLast24h counts only recent sessions', () {
      final now = DateTime.now();
      final history = [
        ScanSession(
          id: '1',
          fileName: 'a.jpg',
          fileSize: '1 MB',
          fileType: 'JPEG',
          scannedAt: now.subtract(const Duration(hours: 2)),
          riskScore: 40,
          findings: const [],
        ),
        ScanSession(
          id: '2',
          fileName: 'b.jpg',
          fileSize: '1 MB',
          fileType: 'JPEG',
          scannedAt: now.subtract(const Duration(days: 3)),
          riskScore: 40,
          findings: const [],
        ),
      ];

      expect(HistoryMetrics.scansLast24h(history), 1);
    });

    test('fixesApplied sums fixed findings', () {
      final history = [
        ScanSession(
          id: '1',
          fileName: 'a.jpg',
          fileSize: '1 MB',
          fileType: 'JPEG',
          scannedAt: DateTime.now(),
          riskScore: 40,
          findings: const [
            PrivacyFinding(
              id: 'f1',
              category: 'Metadata',
              title: 'GPS',
              description: 'Location embedded',
              level: RiskLevel.high,
              isFixed: true,
            ),
            PrivacyFinding(
              id: 'f2',
              category: 'Faces',
              title: 'Face',
              description: 'Face detected',
              level: RiskLevel.medium,
            ),
          ],
        ),
      ];

      expect(HistoryMetrics.fixesApplied(history), 1);
    });
  });
}
