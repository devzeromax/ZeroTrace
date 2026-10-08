import 'package:universal_io/io.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/scanner/scanner_models.dart';
import '../../../infrastructure/scanner/pii_classifier.dart';
import '../../../models/app_models.dart';

/// Text-layer extraction for PDFs — PPOCR ONNX only handles raster images.
class DocumentPdfTextScanner {
  const DocumentPdfTextScanner._();

  static const _classifier = PiiClassifier();
  static const _uuid = Uuid();

  static Future<PluginScanResult> scan({
    required ScanInput input,
    required String pluginId,
    required String pluginName,
    required String pluginVersion,
  }) async {
    final started = DateTime.now();
    try {
      final bytes = await File(input.filePath).readAsBytes();
      final text = extractPdfText(bytes);
      final findings = <PluginFinding>[];

      if (text.trim().length < 12) {
        // Informational only — not Confidential Data.
        findings.add(
          PluginFinding(
            id: _uuid.v4(),
            category: 'Documents',
            title: 'PDF text layer not readable',
            description:
                'This PDF has little or no extractable text (often a scanned image PDF). '
                'Metadata was still checked. For photo scans of documents, upload as JPG/PNG '
                'with Document Protection Pack installed.',
            severity: RiskLevel.low,
            confidence: 0.7,
            recommendation:
                'Export a photo scan of each page, or use a PDF with a selectable text layer.',
            metadata: const {
              'doc_type': 'pdf',
              'ocr_engine': 'pdf_text',
              'informational': 'true',
            },
            supportsBlur: false,
          ),
        );
      } else {
        final matches = _classifier.classify(text);
        final byType = <PiiType, PiiMatch>{};
        for (final m in matches) {
          byType.putIfAbsent(m.type, () => m);
        }

        // Only real validated PII — never invent IBAN/bank findings from PDF noise.
        for (final match in byType.values) {
          findings.add(
            PluginFinding(
              id: _uuid.v4(),
              category: 'Confidential Data',
              title: match.label,
              description:
                  'Validated ${match.label.toLowerCase()} found in the PDF text layer: '
                  '"${_mask(match.value)}". '
                  'ZeroTrace cannot pixelate PDF text in-app — redact in a PDF editor before sharing.',
              severity: _severityFor(match.type),
              confidence: 0.92,
              recommendation:
                  'Open the PDF in an editor and permanently redact this value before sharing.',
              metadata: {
                'doc_type': 'pdf',
                'ocr_engine': 'pdf_text',
                'ocr_text': _mask(match.value),
                'pii_label': match.label,
                'pii_types': match.type.name,
                'redact_capable': 'false',
              },
              supportsBlur: false,
            ),
          );
        }
      }

      return PluginScanResult(
        pluginId: pluginId,
        pluginName: pluginName,
        pluginVersion: pluginVersion,
        findings: findings,
        processingTime: DateTime.now().difference(started),
      );
    } catch (e) {
      return PluginScanResult(
        pluginId: pluginId,
        pluginName: pluginName,
        pluginVersion: pluginVersion,
        findings: const [],
        processingTime: DateTime.now().difference(started),
        errorMessage: e.toString(),
      );
    }
  }

  /// Pulls visible strings from PDF content streams (text layer, not OCR).
  static String extractPdfText(List<int> bytes) {
    final sample = bytes.length > 4 * 1024 * 1024
        ? bytes.sublist(0, 4 * 1024 * 1024)
        : bytes;
    final raw = String.fromCharCodes(
      sample.where((b) => (b >= 32 && b <= 126) || b == 9 || b == 10 || b == 13),
    );

    final buffer = StringBuffer();
    final literal = RegExp(r'\((?:\\.|[^\\)])*\)');
    for (final match in literal.allMatches(raw)) {
      final inner = match.group(0)!;
      if (inner.length <= 2) continue;
      final decoded = _unescapePdfString(inner.substring(1, inner.length - 1));
      if (decoded.trim().isNotEmpty) {
        buffer.writeln(decoded);
      }
    }

    final hex = RegExp(r'<([0-9A-Fa-f\s]+)>');
    for (final match in hex.allMatches(raw)) {
      final decoded = _decodeHexPdfString(match.group(1) ?? '');
      if (decoded.trim().isNotEmpty) {
        buffer.writeln(decoded);
      }
    }

    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _unescapePdfString(String value) {
    return value
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\r')
        .replaceAll(r'\t', '\t')
        .replaceAll(r'\(', '(')
        .replaceAll(r'\)', ')')
        .replaceAll(r'\\', r'\');
  }

  static String _decodeHexPdfString(String hex) {
    final cleaned = hex.replaceAll(RegExp(r'\s'), '');
    if (cleaned.length < 4 || cleaned.length.isOdd) return '';
    final chars = <int>[];
    for (var i = 0; i + 1 < cleaned.length; i += 2) {
      final byte = int.tryParse(cleaned.substring(i, i + 2), radix: 16);
      if (byte == null) continue;
      if (byte >= 32 && byte <= 126) {
        chars.add(byte);
      }
    }
    return String.fromCharCodes(chars);
  }

  static String _mask(String value) {
    if (value.length <= 4) return '****';
    return '${value.substring(0, 2)}${'*' * (value.length - 4)}${value.substring(value.length - 2)}';
  }

  static RiskLevel _severityFor(PiiType type) => switch (type) {
        PiiType.creditCard ||
        PiiType.ssn ||
        PiiType.apiSecret ||
        PiiType.aadhaar =>
          RiskLevel.critical,
        PiiType.email || PiiType.iban || PiiType.phone || PiiType.pan =>
          RiskLevel.high,
        _ => RiskLevel.medium,
      };
}
