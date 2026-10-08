import 'package:cleanshare/domain/scanner/scanner_models.dart';
import 'package:cleanshare/infrastructure/scanner/finding_normalizer.dart';
import 'package:cleanshare/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const normalizer = FindingNormalizer();

  test('merges overlapping face boxes into distinct faces', () {
    PluginFinding box(double x, double y, double score) => PluginFinding(
          id: 'f-$x',
          category: 'Faces',
          title: 'Face detected',
          description: 'x',
          severity: RiskLevel.high,
          confidence: score,
          region: FindingRegion(x: x, y: y, width: 0.2, height: 0.2),
        );

    final merged = normalizer.normalize([
      box(0.1, 0.1, 0.9),
      box(0.12, 0.11, 0.85),
      box(0.12, 0.12, 0.8),
      box(0.7, 0.6, 0.75),
    ]);

    expect(merged.length, 2);
    expect(merged.first.title, 'Face 1 detected');
    expect(merged.last.title, 'Face 2 detected');
  });

  test('drops low-confidence document OCR noise on portrait photos', () {
    const normalizer = FindingNormalizer();
    final findings = [
      const PluginFinding(
        id: 'face-1',
        category: 'Faces',
        title: 'Face detected',
        description: 'One face',
        severity: RiskLevel.high,
        confidence: 0.9,
        region: FindingRegion(x: 0.3, y: 0.2, width: 0.3, height: 0.4),
      ),
      const PluginFinding(
        id: 'doc-1',
        category: 'Documents',
        title: 'Sensitive text region detected',
        description: 'OCR noise',
        severity: RiskLevel.medium,
        confidence: 0.45,
        region: FindingRegion(x: 0.1, y: 0.1, width: 0.2, height: 0.1),
      ),
    ];

    final filtered = normalizer.filterDocumentFalsePositives(
      findings,
      extension: 'jpg',
    );

    expect(filtered.length, 1);
    expect(filtered.single.category, 'Faces');
  });

  test('keeps localized document text on ID-style photos with faces', () {
    final findings = [
      const PluginFinding(
        id: 'face-1',
        category: 'Faces',
        title: 'Face detected',
        description: 'One face',
        severity: RiskLevel.high,
        confidence: 0.9,
        region: FindingRegion(x: 0.3, y: 0.2, width: 0.3, height: 0.4),
      ),
      const PluginFinding(
        id: 'doc-1',
        category: 'Documents',
        title: 'Sensitive text detected',
        description: 'Name field',
        severity: RiskLevel.medium,
        confidence: 0.71,
        region: FindingRegion(x: 0.12, y: 0.62, width: 0.35, height: 0.08),
      ),
    ];

    final filtered = normalizer.filterDocumentFalsePositives(
      findings,
      extension: 'jpg',
    );

    expect(filtered.length, 2);
  });

  test('drops document OCR noise on car photos with plate detection', () {
    PluginFinding doc(double x, double y, double score) => PluginFinding(
          id: 'doc-$x',
          category: 'Documents',
          title: 'Text region detected',
          description: 'OCR noise',
          severity: RiskLevel.medium,
          confidence: score,
          region: FindingRegion(x: x, y: y, width: 0.15, height: 0.08),
        );

    final findings = [
      const PluginFinding(
        id: 'plate-1',
        category: 'Vehicles',
        title: 'License plate detected',
        description: 'Plate region',
        severity: RiskLevel.medium,
        confidence: 0.82,
        region: FindingRegion(x: 0.4, y: 0.7, width: 0.2, height: 0.06),
      ),
      doc(0.12, 0.15, 0.58),
      doc(0.55, 0.22, 0.52),
      doc(0.3, 0.45, 0.61),
      doc(0.7, 0.5, 0.55),
    ];

    final filtered = normalizer.filterDocumentFalsePositives(
      findings,
      extension: 'jpg',
    );

    expect(filtered.length, 1);
    expect(filtered.single.category, 'Vehicles');
  });

  test('drops all heatmap OCR boxes on car photo without plate hits', () {
    PluginFinding doc(double x, double score) => PluginFinding(
          id: 'doc-$x',
          category: 'Documents',
          title: 'Text region detected',
          description: 'OCR noise',
          severity: RiskLevel.medium,
          confidence: score,
          region: FindingRegion(x: x, y: 0.2, width: 0.15, height: 0.08),
        );

    final findings = [
      doc(0.12, 0.78),
      doc(0.55, 0.74),
      doc(0.3, 0.81),
      doc(0.7, 0.76),
    ];

    final filtered = normalizer.filterDocumentFalsePositives(
      findings,
      extension: 'jpg',
    );

    expect(filtered, isEmpty);
  });
}
