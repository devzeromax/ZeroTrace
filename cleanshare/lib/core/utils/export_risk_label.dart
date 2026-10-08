import '../../models/app_models.dart';

/// Plain-language export risk labels (shared by export screen and sheet).
String exportRiskLabel(RiskLevel level) => switch (level) {
      RiskLevel.critical => 'Critical risk',
      RiskLevel.high => 'High risk',
      RiskLevel.medium => 'Moderate risk',
      RiskLevel.low => 'Low risk',
      RiskLevel.none => 'Clean',
    };

RiskLevel riskLevelFromScore(int score) {
  if (score >= 70) return RiskLevel.critical;
  if (score >= 50) return RiskLevel.high;
  if (score >= 30) return RiskLevel.medium;
  if (score > 0) return RiskLevel.low;
  return RiskLevel.none;
}
