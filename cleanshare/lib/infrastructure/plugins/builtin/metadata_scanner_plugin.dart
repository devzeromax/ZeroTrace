import 'package:crypto/crypto.dart';

import 'package:universal_io/io.dart';



import 'package:exif/exif.dart';

import 'package:uuid/uuid.dart';



import '../../../domain/marketplace/marketplace_models.dart';

import '../../../domain/scanner/scanner_models.dart';

import '../../../models/app_models.dart';



/// Built-in metadata scanner — EXIF, GPS, file fingerprint, privacy report.

class MetadataScannerPlugin implements ScanPlugin {

  const MetadataScannerPlugin();



  static const pluginId = 'privacy-essentials';



  @override

  String get id => pluginId;



  @override

  String get displayName => 'Privacy Essentials Pack';



  @override

  String get version => '1.0.0';



  @override

  MarketplaceCategory get category => MarketplaceCategory.metadataScanner;



  @override

  List<String> get capabilities => const [

        'metadata',

        'hash',

        'privacy_report',

      ];



  @override

  bool get isInstalled => true;



  @override

  bool get isOperational => true;



  @override

  ScanStage? get scanStage => ScanStage.metadata;



  static const _criticalTagPrefixes = ['GPS '];

  static const _highRiskTagFragments = [

    'SerialNumber',

    'BodySerialNumber',

    'LensSerialNumber',

    'ImageUniqueID',

    'CameraOwnerName',

    'Artist',

    'Copyright',

  ];

  static const _mediumRiskTagFragments = [

    'DateTime',

    'Software',

    'Make',

    'Model',

    'LensModel',

    'HostComputer',

    'UserComment',

    'ImageDescription',

    'Orientation',

    'WhiteBalance',

    'ExposureTime',

    'FNumber',

    'ISOSpeedRatings',

    'Flash',

    'FocalLength',

  ];



  @override

  Future<PluginScanResult> scan(ScanInput input) async {

    final started = DateTime.now();

    final findings = <PluginFinding>[];

    const uuid = Uuid();



    try {

      final file = File(input.filePath);

      final bytes = await file.readAsBytes();

      final digest = sha256.convert(bytes).toString();

      final shortHash = '${digest.substring(0, 12)}…';



      findings.add(

        PluginFinding(

          id: uuid.v4(),

          category: 'Privacy Report',

          title: 'File fingerprint recorded',

          description:

              'SHA-256: $shortHash — use this to verify the file was not altered after scanning.',

          severity: RiskLevel.low,

          confidence: 1.0,

          recommendation: null,

          metadata: {

            'sha256': digest,

            'size_bytes': '${bytes.length}',

            'capability': 'hash',

          },

        ),

      );



      if (_isImage(input.extension)) {

        await _scanImageExif(bytes, findings, uuid);

      } else if (_isDocument(input.extension)) {

        findings.add(

          PluginFinding(

            id: uuid.v4(),

            category: 'Metadata',

            title: 'Document metadata scan',

            description:

                '${input.extension.toUpperCase()} files may contain author, title, or revision history in the file header. '

                'Document Protection Pack scans PDF text content and image pages for sensitive text (OCR).',

            severity: RiskLevel.medium,

            confidence: 0.75,

            recommendation: 'Review document properties before sharing.',

            metadata: {'capability': 'metadata'},

          ),

        );

      }

      final baselineCount = findings.length;
      findings.add(
        PluginFinding(
          id: uuid.v4(),
          category: 'Privacy Report',
          title: 'Privacy Essentials scan complete',
          description:
              '$baselineCount baseline checks applied for ${input.fileName}. '
              'Install optional packs for face, plate, OCR, and QR detection.',

          severity: RiskLevel.low,

          confidence: 1.0,

          metadata: {

            'capability': 'privacy_report',

            'plugin': pluginId,

            'file_type': input.extension,

          },

        ),

      );

    } catch (e) {

      return PluginScanResult(

        pluginId: id,

        pluginName: displayName,

        pluginVersion: version,

        findings: findings,

        processingTime: DateTime.now().difference(started),

        errorMessage: e.toString(),

      );

    }



    return _result(started, findings);

  }



  Future<void> _scanImageExif(

    List<int> bytes,

    List<PluginFinding> findings,

    Uuid uuid,

  ) async {

    final data = await readExifFromBytes(bytes);



    if (data.isEmpty) {

      findings.add(

        PluginFinding(

          id: uuid.v4(),

          category: 'Metadata',

          title: 'No EXIF metadata detected',

          description:

              'This image has no readable embedded metadata — common for screenshots and re-shared exports.',

          severity: RiskLevel.low,

          confidence: 0.7,

          recommendation: 'Still review faces and QR codes before sharing.',

        ),

      );

      return;

    }



    final seenTitles = <String>{};



    for (final entry in data.entries) {

      final tag = entry.key;

      final value = entry.value.printable.trim();

      if (value.isEmpty) continue;



      final severity = _severityForTag(tag);

      if (severity == null) continue;



      final isGps = tag.startsWith('GPS');

      final title = isGps ? 'GPS location embedded' : _titleForTag(tag);

      if (!seenTitles.add(title)) continue;



      findings.add(

        PluginFinding(

          id: uuid.v4(),

          category: 'Metadata',

          title: title,

          description: '$tag: $value',

          severity: severity,

          confidence: isGps ? 0.98 : 0.9,

          recommendation: isGps

              ? 'Strip GPS coordinates before sharing.'

              : 'Remove EXIF metadata before export.',

          metadata: {'tag': tag},

        ),

      );

    }



    if (data.length >= 4 &&

        findings.where((f) => f.category == 'Metadata').isEmpty) {

      findings.add(

        PluginFinding(

          id: uuid.v4(),

          category: 'Metadata',

          title: 'Rich EXIF block detected',

          description:

              '${data.length} metadata fields may reveal camera, time, or device details.',

          severity: RiskLevel.medium,

          confidence: 0.85,

          recommendation: 'Enable metadata stripping on export.',

        ),

      );

    }

  }



  RiskLevel? _severityForTag(String tag) {

    if (_criticalTagPrefixes.any(tag.startsWith)) {

      return RiskLevel.critical;

    }

    if (_highRiskTagFragments.any(tag.contains)) {

      return RiskLevel.high;

    }

    if (_mediumRiskTagFragments.any(tag.contains)) {

      return RiskLevel.medium;

    }

    return null;

  }



  String _titleForTag(String tag) {

    if (tag.contains('SerialNumber')) return 'Device serial number exposed';

    if (tag.contains('Software')) return 'Editing software identified';

    if (tag.contains('DateTime')) return 'Capture timestamp embedded';

    if (tag.contains('Make') || tag.contains('Model')) {

      return 'Camera device identified';

    }

    if (tag.contains('Artist') || tag.contains('Copyright')) {

      return 'Creator information embedded';

    }

    return 'Sensitive metadata field';

  }



  PluginScanResult _result(DateTime started, List<PluginFinding> findings) {

    return PluginScanResult(

      pluginId: id,

      pluginName: displayName,

      pluginVersion: version,

      findings: findings,

      processingTime: DateTime.now().difference(started),

    );

  }



  bool _isImage(String ext) =>

      {'jpg', 'jpeg', 'png', 'heic', 'webp', 'tif', 'tiff'}

          .contains(ext.toLowerCase());



  bool _isDocument(String ext) => {

        'pdf',

        'doc',

        'docx',

        'xls',

        'xlsx',

        'ppt',

        'pptx',

        'odt',

        'zip',

      }.contains(ext.toLowerCase());

}


