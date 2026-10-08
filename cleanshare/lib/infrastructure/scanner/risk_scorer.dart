import '../../domain/scanner/scanner_models.dart';
import '../../models/app_models.dart';

/// Computes aggregate risk score from plugin findings.
class RiskScorer {
  const RiskScorer();

  int score(List<PluginFinding> findings) {
    if (findings.isEmpty) return 0;

    var total = 0.0;
    for (final f in findings) {
      total += switch (f.severity) {
        RiskLevel.critical => 28.0,
        RiskLevel.high => 18.0,
        RiskLevel.medium => 10.0,
        RiskLevel.low => 4.0,
        RiskLevel.none => 0.0,
      } * f.confidence;
    }

    return total.clamp(0, 100).round();
  }
}
