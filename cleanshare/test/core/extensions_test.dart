import 'package:flutter_test/flutter_test.dart';

import 'package:cleanshare/core/extensions/model_extensions.dart';
import 'package:cleanshare/models/app_models.dart';

void main() {
  group('RiskLevelX', () {
    test('labels are human readable', () {
      expect(RiskLevel.critical.riskLabel, 'Critical');
      expect(RiskLevel.high.riskLabel, 'High');
      expect(RiskLevel.low.riskLabel, 'Low');
    });
  });

  group('WorkflowStepX', () {
    test('add step label', () {
      expect(WorkflowStep.upload.stepLabel, 'Add');
      expect(WorkflowStep.export.stepLabel, 'Export');
    });
  });

  group('PrivacyFinding', () {
    test('copyWith toggles isFixed', () {
      const finding = PrivacyFinding(
        id: '1',
        category: 'Metadata',
        title: 'GPS',
        description: 'test',
        level: RiskLevel.critical,
      );
      expect(finding.isFixed, false);
      expect(finding.copyWith(isFixed: true).isFixed, true);
    });
  });
}
