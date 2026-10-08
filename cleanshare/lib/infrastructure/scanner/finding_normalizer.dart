import '../../domain/scanner/scanner_models.dart';
/// Collapses noisy detector output into accurate, user-facing findings.
class FindingNormalizer {
  const FindingNormalizer();

  List<PluginFinding> normalize(List<PluginFinding> raw) {
    if (raw.isEmpty) return raw;

    final grouped = <String, List<PluginFinding>>{};
    for (final finding in raw) {
      grouped.putIfAbsent(finding.category, () => []).add(finding);
    }

    final out = <PluginFinding>[];
    for (final entry in grouped.entries) {
      if (_isSpatialCategory(entry.key)) {
        out.addAll(_mergeSpatial(entry.key, entry.value));
      } else {
        out.addAll(entry.value);
      }
    }
    return out;
  }

  /// Suppresses PPOCR heatmap false positives on casual photos (cars, streets, portraits).
  List<PluginFinding> filterDocumentFalsePositives(
    List<PluginFinding> findings, {
    required String extension,
    bool deepScan = false,
  }) {
    final isPhoto = const {
      'jpg',
      'jpeg',
      'png',
      'heic',
      'webp',
    }.contains(extension.toLowerCase());
    if (!isPhoto) return findings;

    final hasSceneSubjects = findings.any((f) {
      if (_isDocumentCategory(f.category)) return false;
      final cat = f.category.toLowerCase();
      return cat.contains('face') ||
          cat.contains('vehicle') ||
          cat.contains('license') ||
          cat.contains('plate') ||
          (f.region != null && f.confidence >= 0.5);
    });

    final nonDocument = findings
        .where((f) => !_isDocumentCategory(f.category))
        .toList();
    final documents = findings.where((f) => _isDocumentCategory(f.category));

    final kept = <PluginFinding>[];
    for (final f in documents) {
      if (_keepDocumentOnPhoto(
        f,
        hasSceneSubjects: hasSceneSubjects,
        deepScan: deepScan,
      )) {
        kept.add(f);
      }
    }

    final withPii =
        kept.where((f) => f.metadata.containsKey('pii_label')).toList();
    final withoutPii =
        kept.where((f) => !f.metadata.containsKey('pii_label')).toList();
    final maxHeatmap = deepScan ? 2 : 1;
    final capped = withoutPii.length <= maxHeatmap
        ? withoutPii
        : (List<PluginFinding>.from(withoutPii)
              ..sort((a, b) => b.confidence.compareTo(a.confidence)))
            .take(maxHeatmap)
            .toList();

    return [...nonDocument, ...withPii, ...capped];
  }

  bool _isDocumentCategory(String category) {
    final key = category.toLowerCase();
    return key.contains('document') || key.contains('confidential');
  }

  bool _keepDocumentOnPhoto(
    PluginFinding finding, {
    required bool hasSceneSubjects,
    bool deepScan = false,
  }) {
    if (finding.metadata.containsKey('pii_label')) {
      return true;
    }

    final ocrText = finding.metadata['ocr_text']?.trim() ?? '';
    final docType = finding.metadata['doc_type']?.toLowerCase() ?? '';
    final isIdDoc = docType.contains('aadhaar') ||
        docType.contains('passport') ||
        _looksLikeIndiaId(ocrText);

    // Always keep Aadhaar / PAN / ID OCR even on street photos with faces.
    if (isIdDoc && ocrText.isNotEmpty) {
      return finding.confidence >= (deepScan ? 0.28 : 0.35);
    }

    if (ocrText.length >= 8 && _looksLikeReadableText(ocrText)) {
      final minConf = deepScan ? 0.40 : 0.48;
      return finding.confidence >= minConf;
    }

    final region = finding.region;
    final isIdBand = region != null &&
        region.height <= 0.18 &&
        region.width >= 0.18 &&
        region.y >= 0.35;

    // Scene photos (cars, people, plates): never trust heatmap-only OCR.
    if (hasSceneSubjects) {
      return isIdBand && finding.confidence >= 0.55;
    }

    if (isIdBand && finding.confidence >= 0.50) {
      return true;
    }

    return false;
  }

  bool _looksLikeIndiaId(String text) {
    if (text.isEmpty) return false;
    final lower = text.toLowerCase();
    if (lower.contains('aadhaar') ||
        lower.contains('aadhar') ||
        lower.contains('uidai') ||
        lower.contains('permanent account')) {
      return true;
    }
    return RegExp(r'\b\d{4}\s?\d{4}\s?\d{4}\b').hasMatch(text) ||
        RegExp(r'\b[A-Z]{5}\d{4}[A-Z]\b').hasMatch(text);
  }

  bool _looksLikeReadableText(String text) {
    final letters = text.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    return letters.length >= 6;
  }

  bool _isSpatialCategory(String category) {
    final key = category.toLowerCase();
    return key.contains('face') ||
        key.contains('license') ||
        key.contains('plate') ||
        key.contains('vehicle') ||
        key.contains('document');
  }

  List<PluginFinding> _mergeSpatial(String category, List<PluginFinding> items) {
    final withRegion =
        items.where((f) => f.region != null).toList(growable: false);
    final withoutRegion =
        items.where((f) => f.region == null).toList(growable: false);

    if (withRegion.isEmpty) {
      return _capCategory(category, withoutRegion, 12);
    }

    final sorted = List<PluginFinding>.from(withRegion)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    final kept = <PluginFinding>[];
    for (final candidate in sorted) {
      final region = candidate.region!;
      if (kept.any((k) => _iou(k.region!, region) >= 0.35)) {
        continue;
      }
      kept.add(candidate);
    }

    final merged = _capCategory(category, kept, _maxForCategory(category));
    if (withoutRegion.isNotEmpty && merged.isEmpty) {
      return _capCategory(category, withoutRegion, 3);
    }
    return [
      ...merged,
      ..._capCategory(category, withoutRegion, 2),
    ];
  }

  int _maxForCategory(String category) {
    final key = category.toLowerCase();
    if (key.contains('face')) return 12;
    if (key.contains('license') || key.contains('plate')) return 2;
    if (key.contains('document')) return 4;
    return 10;
  }

  List<PluginFinding> _capCategory(
    String category,
    List<PluginFinding> items,
    int maxItems,
  ) {
    if (items.length <= maxItems) {
      return _relabelSpatial(category, items);
    }
    final top = List<PluginFinding>.from(items)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    return _relabelSpatial(category, top.take(maxItems).toList());
  }

  List<PluginFinding> _relabelSpatial(
    String category,
    List<PluginFinding> items,
  ) {
    if (items.isEmpty) return items;
    final key = category.toLowerCase();
    final isFace = key.contains('face');

    return items.asMap().entries.map((entry) {
      final index = entry.key;
      final f = entry.value;
      final count = items.length;
      final title = isFace
          ? (count == 1 ? 'Face detected' : 'Face ${index + 1} detected')
          : key.contains('document')
              ? (count == 1
                  ? 'Sensitive text detected'
                  : 'Text region ${index + 1} detected')
              : f.title;
      final description = isFace
          ? (count == 1
              ? 'One face was detected in this image. Enable blur before sharing.'
              : '$count distinct faces were detected. Enable blur for each region you want hidden.')
          : key.contains('document')
              ? 'Personal or confidential text was detected. Enable blur to redact before sharing.'
              : f.description;

      return PluginFinding(
        id: '${f.id}-n$index',
        category: f.category,
        title: f.title.contains('detected') ? title : f.title,
        description: f.metadata.containsKey('pii_label') ? f.description : description,
        severity: f.severity,
        confidence: f.confidence,
        recommendation: f.recommendation,
        region: f.region,
        metadata: f.metadata,
        supportsBlur: f.supportsBlur,
      );
    }).toList();
  }

  double _iou(FindingRegion a, FindingRegion b) {
    final ax2 = a.x + a.width;
    final ay2 = a.y + a.height;
    final bx2 = b.x + b.width;
    final by2 = b.y + b.height;
    final ix1 = a.x > b.x ? a.x : b.x;
    final iy1 = a.y > b.y ? a.y : b.y;
    final ix2 = ax2 < bx2 ? ax2 : bx2;
    final iy2 = ay2 < by2 ? ay2 : by2;
    final iw = (ix2 - ix1).clamp(0.0, 1.0);
    final ih = (iy2 - iy1).clamp(0.0, 1.0);
    final inter = iw * ih;
    final union = a.width * a.height + b.width * b.height - inter;
    if (union <= 0) return 0;
    return inter / union;
  }
}
