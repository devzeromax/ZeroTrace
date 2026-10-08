import 'package:http/http.dart' as http;

import 'pinned_http_client.dart';

/// Native desktop/mobile — pinned TLS + host allowlist.
http.Client createTrustHttpClient() => PinnedHttpClient();
