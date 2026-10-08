import 'package:flutter_test/flutter_test.dart';

import 'package:cleanshare/core/utils/export_risk_label.dart';
import 'package:cleanshare/models/app_models.dart';

void main() {
  test('exportRiskLabel distinguishes clean from low risk', () {
    expect(exportRiskLabel(RiskLevel.none), 'Clean');
    expect(exportRiskLabel(RiskLevel.low), 'Low risk');
    expect(riskLevelFromScore(0), RiskLevel.none);
    expect(riskLevelFromScore(10), RiskLevel.low);
  });
}
