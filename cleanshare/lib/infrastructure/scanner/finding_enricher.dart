import '../../domain/scanner/scanner_models.dart';
import '../../models/app_models.dart';
import 'pii_classifier.dart';

/// Enriches OCR findings with PII labels and smart redact hints.
/// Also normalizes detector categories so Audit grouping stays consistent.
class FindingEnricher {
  const FindingEnricher({PiiClassifier? classifier})
      : _classifier = classifier ?? const PiiClassifier();

  final PiiClassifier _classifier;

  List<PluginFinding> enrich(List<PluginFinding> findings) {
    return findings.map(_enrichOne).toList();
  }

  PluginFinding _enrichOne(PluginFinding finding) {
    final mappedCategory = _canonicalCategory(finding);
    var working = finding.category == mappedCategory
        ? finding
        : PluginFinding(
            id: finding.id,
            category: mappedCategory,
            title: finding.title,
            description: finding.description,
            severity: finding.severity,
            confidence: finding.confidence,
            recommendation: finding.recommendation,
            region: finding.region,
            metadata: finding.metadata,
            supportsBlur: finding.supportsBlur,
          );

    final ocrText = working.metadata['ocr_text'] ??
        (working.category == 'QR Codes' ? working.description : null);
    final docType = (working.metadata['doc_type'] ?? '').toLowerCase();

    // Engine already tagged Aadhaar / ID even when OCR is partial.
    if ((ocrText == null || ocrText.isEmpty) && docType.contains('aadhaar')) {
      final updatedMeta = Map<String, String>.from(working.metadata)
        ..['pii_label'] = 'Aadhaar number'
        ..['pii_types'] = PiiType.aadhaar.name;
      return PluginFinding(
        id: working.id,
        category: 'Confidential Data',
        title: 'Aadhaar number',
        description:
            'Aadhaar / UIDAI document text was detected. Enable blur before sharing.',
        severity: RiskLevel.critical,
        confidence: working.confidence.clamp(0.0, 1.0),
        recommendation: 'Enable blur to redact this ID region before sharing.',
        region: working.region,
        metadata: updatedMeta,
        supportsBlur: true,
      );
    }

    if (ocrText == null || ocrText.isEmpty) return working;

    final matches = _classifier.classify(ocrText);
    if (matches.isEmpty && !docType.contains('aadhaar')) return working;

    final label = matches.isEmpty
        ? 'Aadhaar number'
        : _classifier.primaryLabel(matches)!;
    final updatedMeta = Map<String, String>.from(working.metadata)
      ..['pii_label'] = label
      ..['pii_types'] = matches.isEmpty
          ? PiiType.aadhaar.name
          : matches.map((m) => m.type.name).toSet().join(',');

    // Plate numbers found via OCR → License Plates category for audit mapping.
    final category = matches.any((m) => m.type == PiiType.licensePlate)
        ? 'License Plates'
        : 'Confidential Data';

    return PluginFinding(
      id: working.id,
      category: category,
      title: label,
      description:
          'Recognized ${docType.isEmpty ? 'document' : docType} text contains $label. Smart redact can pixelate only this PII.',
      severity: matches.isEmpty ? RiskLevel.critical : _severityFor(matches),
      confidence: working.confidence.clamp(0.0, 1.0),
      recommendation:
          'Enable smart redact or blur this text region before sharing.',
      region: working.region,
      metadata: updatedMeta,
      supportsBlur: true,
    );
  }

  String _canonicalCategory(PluginFinding finding) {
    final key = finding.category.toLowerCase();
    if (key.contains('face')) return 'Faces';
    if (key.contains('plate') || key.contains('license')) {
      return 'License Plates';
    }
    if (key.contains('vehicle')) return 'Vehicles';
    if (key.contains('qr') || key.contains('barcode')) return 'QR Codes';
    if (key.contains('secret') || key.contains('token') || key.contains('key')) {
      return 'Secrets';
    }
    if (key.contains('metadata') || key.contains('exif') || key.contains('gps')) {
      return 'Metadata';
    }
    // Only real PII-labeled hits become Confidential — not generic PDF text notices.
    if (finding.metadata.containsKey('pii_label') ||
        key.contains('confidential') ||
        key.contains('pii')) {
      return 'Confidential Data';
    }
    if (key.contains('document') || key.contains('ocr')) {
      return 'Documents';
    }
    return finding.category;
  }

  RiskLevel _severityFor(List<PiiMatch> matches) {
    if (matches.any((m) =>
        m.type == PiiType.creditCard ||
        m.type == PiiType.ssn ||
        m.type == PiiType.aadhaar ||
        m.type == PiiType.apiSecret)) {
      return RiskLevel.critical;
    }
    if (matches.any((m) =>
        m.type == PiiType.email ||
        m.type == PiiType.iban ||
        m.type == PiiType.pan ||
        m.type == PiiType.licensePlate)) {
      return RiskLevel.high;
    }
    return RiskLevel.medium;
  }
}
