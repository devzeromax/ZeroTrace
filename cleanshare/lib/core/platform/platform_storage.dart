import 'package:flutter/foundation.dart' show kIsWeb;

/// Platform file-system capabilities.
abstract final class PlatformStorage {
  static bool get supportsLocalFileSystem => !kIsWeb;
}
