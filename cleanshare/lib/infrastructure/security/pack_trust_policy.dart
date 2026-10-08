import 'package:path/path.dart' as p;
import 'package:universal_io/io.dart';

import 'pack_trust_constants.dart';

/// Host allowlist and download URL policy for marketplace packs.
abstract final class PackTrustPolicy {
  static void assertDownloadUrlAllowed(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') {
      throw PackTrustException('Pack downloads must use HTTPS URLs.');
    }
    final host = uri.host.toLowerCase();
    if (!PackTrustConstants.allowedDownloadHosts.contains(host)) {
      throw PackTrustException(
        'Untrusted download host "$host". '
        'Only ZeroTrace release CDN hosts are permitted.',
      );
    }
  }

  /// Downloadable pack formats require Ed25519 publisher signatures.
  static bool requiresSignature({required String format}) {
    return format == 'onnx' || format == 'rules';
  }

  static void assertSignaturePresent({
    required String? signature,
    required String format,
  }) {
    if (!requiresSignature(format: format)) return;
    final sig = signature?.trim() ?? '';
    if (sig.isEmpty || !sig.startsWith('ed25519:')) {
      throw PackTrustException(
        'Pack format "$format" requires a valid ed25519 publisher signature.',
      );
    }
  }
}

class PackTrustException implements Exception {
  PackTrustException(this.message);
  final String message;

  @override
  String toString() => 'PackTrustException: $message';
}

/// Canonical path under a trusted root (zip-slip / traversal guard).
abstract final class PathGuard {
  static String resolveUnderRoot(String rootPath, String relativePath) {
    final root = p.normalize(p.absolute(rootPath));
    final joined = p.normalize(p.join(root, relativePath));
    final prefix = root.endsWith(p.separator) ? root : '$root${p.separator}';
    if (joined != root && !joined.startsWith(prefix)) {
      throw PathGuardException('Path escapes trusted directory: $relativePath');
    }
    return joined;
  }

  static bool isUnderRoot(String rootPath, String candidatePath) {
    try {
      final root = p.normalize(p.absolute(rootPath));
      final target = p.normalize(p.absolute(candidatePath));
      final rootKey = _pathKey(root);
      final targetKey = _pathKey(target);
      return targetKey == rootKey || targetKey.startsWith('$rootKey${p.separator}');
    } catch (_) {
      return false;
    }
  }

  static String _pathKey(String path) {
    if (Platform.isWindows) {
      return path.replaceAll('/', '\\').toLowerCase();
    }
    return path;
  }

  static void assertScanPathAllowed({
    required String rootPath,
    required String filePath,
  }) {
    if (!isUnderRoot(rootPath, filePath)) {
      throw PathGuardException(
        'Scan rejected: file must stay under ZeroTrace storage.',
      );
    }
  }
}

class PathGuardException implements Exception {
  PathGuardException(this.message);
  final String message;

  @override
  String toString() => 'PathGuardException: $message';
}
