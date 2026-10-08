import 'package:http/http.dart' as http;

/// Browser — standard HTTP client (no dart:io TLS pinning).
http.Client createTrustHttpClient() => http.Client();
