import 'package:cleanshare/domain/scanner/scanner_models.dart';
import 'package:cleanshare/infrastructure/scanner/finding_enricher.dart';
import 'package:cleanshare/infrastructure/scanner/finding_normalizer.dart';
import 'package:cleanshare/infrastructure/scanner/pii_classifier.dart';
import 'package:cleanshare/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps Aadhaar OCR on street photos with faces', () {
    const normalizer = FindingNormalizer();
    final findings = [
      const PluginFinding(
        id: 'face',
        category: 'Faces',
        title: 'Face',
        description: 'd',
        severity: RiskLevel.medium,
        confidence: 0.9,
        region: FindingRegion(x: 0.2, y: 0.1, width: 0.2, height: 0.2),
        supportsBlur: true,
      ),
      const PluginFinding(
        id: 'aadhaar',
        category: 'Confidential Data',
        title: 'Sensitive text',
        description: 'd',
        severity: RiskLevel.high,
        confidence: 0.45,
        region: FindingRegion(x: 0.1, y: 0.5, width: 0.8, height: 0.2),
        metadata: {
          'ocr_text': 'UIDAI Aadhaar 2345 6789 0123',
          'doc_type': 'aadhaar',
          'pii_label': 'Aadhaar number',
        },
        supportsBlur: true,
      ),
    ];
    final kept = normalizer.filterDocumentFalsePositives(
      findings,
      extension: 'jpg',
      deepScan: true,
    );
    expect(kept.any((f) => f.id == 'aadhaar'), isTrue);
  });

  test('enricher promotes Aadhaar doc_type without OCR body', () {
    const enricher = FindingEnricher();
    final out = enricher.enrich(const [
      PluginFinding(
        id: 'doc',
        category: 'Documents',
        title: 'Sensitive text',
        description: 'd',
        severity: RiskLevel.medium,
        confidence: 0.6,
        region: FindingRegion(x: 0.1, y: 0.2, width: 0.8, height: 0.5),
        metadata: {'doc_type': 'aadhaar'},
        supportsBlur: true,
      ),
    ]);
    expect(out.single.category, 'Confidential Data');
    expect(out.single.metadata['pii_label'], 'Aadhaar number');
    expect(out.single.supportsBlur, isTrue);
  });

  test('India plate regex matches DL 7CX 6587', () {
    const c = PiiClassifier();
    final matches = c.classify('DL 7CX 6587');
    expect(matches.any((m) => m.type == PiiType.licensePlate), isTrue);
  });
}
