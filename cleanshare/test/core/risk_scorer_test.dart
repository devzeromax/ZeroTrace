import 'package:flutter_test/flutter_test.dart';

import 'package:cleanshare/domain/scanner/scanner_models.dart';
import 'package:cleanshare/infrastructure/scanner/risk_scorer.dart';
import 'package:cleanshare/models/app_models.dart';

void main() {
  group('RiskScorer', () {
    const scorer = RiskScorer();

    test('empty findings returns zero', () {
      expect(scorer.score([]), 0);
    });

    test('critical finding produces high score', () {
      final score = scorer.score([
        const PluginFinding(
          id: '1',
          category: 'Metadata',
          title: 'GPS',
          description: 'GPS embedded',
          severity: RiskLevel.critical,
          confidence: 1.0,
        ),
      ]);
      expect(score, greaterThan(20));
    });
  });
}
