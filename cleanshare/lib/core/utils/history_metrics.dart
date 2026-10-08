import '../../models/app_models.dart';

/// Honest dashboard metrics derived from local scan history.
abstract final class HistoryMetrics {
  static const _day = Duration(hours: 24);

  static int scansLast24h(List<ScanSession> history) {
    final cutoff = DateTime.now().subtract(_day);
    return history.where((s) => s.scannedAt.isAfter(cutoff)).length;
  }

  static int fixesApplied(List<ScanSession> history) {
    return history.fold<int>(
      0,
      (sum, s) => sum + s.findings.where((f) => f.isFixed).length,
    );
  }

  /// Normalized sparkline (0–1) from recent session counts; empty → flat zeros.
  static List<double> scanSparkline(List<ScanSession> history, {int points = 5}) {
    if (history.isEmpty) return List.filled(points, 0);

    final recent = history.take(points).toList().reversed.toList();
    final maxVal = recent.map((s) => s.findings.length).fold(1, (a, b) => a > b ? a : b);
    return recent
        .map((s) => s.findings.isEmpty ? 0.0 : s.findings.length / maxVal)
        .toList();
  }

  static List<double> fixesSparkline(List<ScanSession> history, {int points = 5}) {
    if (history.isEmpty) return List.filled(points, 0);

    final recent = history.take(points).toList().reversed.toList();
    final counts = recent.map((s) => s.findings.where((f) => f.isFixed).length);
    final maxVal = counts.fold(1, (a, b) => a > b ? a : b);
    return counts.map((c) => c / maxVal).toList();
  }
}
