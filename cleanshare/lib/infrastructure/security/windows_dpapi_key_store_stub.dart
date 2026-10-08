import 'dart:convert';
import 'dart:typed_data';

/// No-op stub — Windows DPAPI is unavailable on this platform.
abstract final class WindowsDpapiKeyStore {
  static String? readFileBytes(Uint8List encrypted) => null;

  static Uint8List? writeFileBytes(String value) =>
      Uint8List.fromList(utf8.encode(value));
}
