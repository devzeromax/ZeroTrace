import '../models/app_models.dart';

/// Demo data for UI scaffolding — replace with Rust engine integration.
abstract final class DemoData {
  /// `false` when the on-device engine and marketplace are active.
  static const isDemoMode = false;

  static const sampleFile = SelectedFile(
    name: 'invoice_photo.jpg',
    size: '2.4 MB',
    type: 'JPEG',
    sizeBytes: 2516582,
  );

  static const previewBeforeUrl =
      'https://dimg.dreamflow.cloud/v1/image/original%20photo%20of%20a%20street%20with%20metadata%20and%20faces%20visible';

  static const previewAfterUrl =
      'https://dimg.dreamflow.cloud/v1/image/cleaned%20photo%20with%20faces%20blurred%20and%20metadata%20removed';

  static const sampleMetadata = <String, String>{
    'Software': 'Adobe Photoshop 25.0',
    'Timestamp': '2024-05-12 14:30:05',
    'Lens': '24mm f/1.8',
    'Exposure': '1/500s ISO 100',
  };

  static final sampleFindings = [
    const PrivacyFinding(
      id: 'f1',
      category: 'Metadata',
      title: 'GPS coordinates in EXIF',
      description:
          'Latitude and longitude embedded in image metadata from camera capture.',
      level: RiskLevel.critical,
      recommendedAction: 'Strip EXIF location data',
    ),
    const PrivacyFinding(
      id: 'f2',
      category: 'Metadata',
      title: 'Device serial number',
      description: 'Camera model and serial identifier found in metadata.',
      level: RiskLevel.high,
      recommendedAction: 'Remove device identifiers',
    ),
    const PrivacyFinding(
      id: 'f3',
      category: 'Faces',
      title: '2 faces detected',
      description: 'Identifiable individuals visible in the image.',
      level: RiskLevel.high,
      recommendedAction: 'Apply Gaussian blur to face regions',
    ),
    const PrivacyFinding(
      id: 'f4',
      category: 'QR Codes',
      title: 'QR code detected',
      description: 'Encoded URL may contain tracking or personal tokens.',
      level: RiskLevel.medium,
      recommendedAction: 'Blur QR code region',
    ),
    const PrivacyFinding(
      id: 'f5',
      category: 'License Plates',
      title: 'License plate detected',
      description: 'Vehicle registration visible in background.',
      level: RiskLevel.low,
      recommendedAction: 'Blur plate region',
    ),
  ];

  static ScanSession buildSession(SelectedFile file) => ScanSession(
        id: 'scan-${DateTime.now().millisecondsSinceEpoch}',
        fileName: file.name,
        fileSize: file.size,
        fileType: file.type,
        scannedAt: DateTime.now(),
        riskScore: 72,
        findings: sampleFindings,
      );

  static final sampleSession = ScanSession(
    id: 'scan-001',
    fileName: sampleFile.name,
    fileSize: sampleFile.size,
    fileType: sampleFile.type,
    scannedAt: DateTime.now().subtract(const Duration(minutes: 12)),
    riskScore: 72,
    findings: sampleFindings,
  );

  static final recentSessions = [
    sampleSession,
    ScanSession(
      id: 'scan-002',
      fileName: 'contract_scan.pdf',
      fileSize: '890 KB',
      fileType: 'PDF',
      scannedAt: DateTime.now().subtract(const Duration(hours: 3)),
      riskScore: 34,
      findings: sampleFindings.take(2).toList(),
      isExported: true,
    ),
    ScanSession(
      id: 'scan-003',
      fileName: 'team_photo.png',
      fileSize: '5.1 MB',
      fileType: 'PNG',
      scannedAt: DateTime.now().subtract(const Duration(days: 1)),
      riskScore: 58,
      findings: sampleFindings.take(4).toList(),
    ),
  ];
}
