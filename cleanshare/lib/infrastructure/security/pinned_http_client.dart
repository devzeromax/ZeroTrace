import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'pack_trust_constants.dart';
import 'pack_trust_policy.dart';

/// HTTP client with host allowlist + TLS SPKI pinning (ASI-09).
class PinnedHttpClient extends http.BaseClient {
  PinnedHttpClient({HttpClient? inner}) : _inner = inner ?? _createClient();

  final HttpClient _inner;
  late final http.Client _delegate = IOClient(_inner);

  static HttpClient _createClient() {
    final pinsReady = PackTrustConstants.marketplaceTlsReady;
    final context = kReleaseMode && pinsReady
        ? SecurityContext(withTrustedRoots: false)
        : SecurityContext(withTrustedRoots: true);

    final client = HttpClient(context: context);
    client.badCertificateCallback = (cert, host, port) {
      return _verifyCertificate(cert, host, port);
    };
    return client;
  }

  static bool _verifyCertificate(X509Certificate cert, String host, int port) {
    final normalized = host.toLowerCase();
    if (!PackTrustConstants.allowedDownloadHosts.contains(normalized)) {
      return false;
    }

    final pins = PackTrustConstants.tlsSpkiPins[normalized];
    final derPin = sha256.convert(cert.der).toString();

    if (pins == null || pins.isEmpty) {
      if (kReleaseMode) return false;
      if (kDebugMode) {
        debugPrint(
          '[TLS-PIN] No SPKI pins for $normalized. '
          'Cert DER SHA-256: $derPin — run tool/extract_tls_pins.dart when CDN is live.',
        );
      }
      return true;
    }

    return pins.any((p) => p.toLowerCase() == derPin);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (kReleaseMode && !PackTrustConstants.remoteMarketplaceEnabled) {
      throw PackTrustException(
        'Remote downloads are disabled. ZeroTrace runs fully offline.',
      );
    }
    final uri = request.url;
    if (uri.scheme != 'https') {
      throw PackTrustException('Only HTTPS marketplace requests are allowed.');
    }
    PackTrustPolicy.assertDownloadUrlAllowed(uri.toString());
    return _delegate.send(request);
  }

  @override
  void close() {
    _delegate.close();
    _inner.close(force: true);
  }
}
