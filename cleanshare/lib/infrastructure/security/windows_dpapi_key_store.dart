import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// Windows DPAPI via crypt32.dll (no ATL / flutter_secure_storage plugin).
abstract final class WindowsDpapiKeyStore {
  static const _cryptProtectUiForbidden = 0x00000001;

  static DynamicLibrary get _crypt32 => DynamicLibrary.open('crypt32.dll');

  static final _protect = _crypt32
      .lookupFunction<
          Int32 Function(
            Pointer<DataBlob>,
            Pointer<Utf16>,
            Pointer<DataBlob>,
            Pointer<Void>,
            Pointer<Void>,
            Uint32,
            Pointer<DataBlob>,
          ),
          int Function(
            Pointer<DataBlob>,
            Pointer<Utf16>,
            Pointer<DataBlob>,
            Pointer<Void>,
            Pointer<Void>,
            int,
            Pointer<DataBlob>,
          )>('CryptProtectData');

  static final _unprotect = _crypt32
      .lookupFunction<
          Int32 Function(
            Pointer<DataBlob>,
            Pointer<Pointer<Utf16>>,
            Pointer<DataBlob>,
            Pointer<Void>,
            Pointer<Void>,
            Uint32,
            Pointer<DataBlob>,
          ),
          int Function(
            Pointer<DataBlob>,
            Pointer<Pointer<Utf16>>,
            Pointer<DataBlob>,
            Pointer<Void>,
            Pointer<Void>,
            int,
            Pointer<DataBlob>,
          )>('CryptUnprotectData');

  static String? readFileBytes(Uint8List encrypted) {
    final decrypted = _unprotectBytes(encrypted);
    if (decrypted == null) return null;
    return utf8.decode(decrypted);
  }

  static Uint8List? writeFileBytes(String value) {
    return _protectBytes(Uint8List.fromList(utf8.encode(value)));
  }

  static Uint8List? _protectBytes(Uint8List plain) {
    final input = calloc<DataBlob>();
    final output = calloc<DataBlob>();
    final plainPtr = calloc<Uint8>(plain.length);

    try {
      for (var i = 0; i < plain.length; i++) {
        plainPtr[i] = plain[i];
      }
      input.ref
        ..cbData = plain.length
        ..pbData = plainPtr;

      final ok = _protect(
        input,
        nullptr,
        nullptr,
        nullptr,
        nullptr,
        _cryptProtectUiForbidden,
        output,
      );
      if (ok == 0) return null;

      final length = output.ref.cbData;
      return Uint8List.fromList(output.ref.pbData.asTypedList(length));
    } finally {
      if (output.ref.pbData != nullptr) {
        calloc.free(output.ref.pbData);
      }
      calloc.free(plainPtr);
      calloc.free(input);
      calloc.free(output);
    }
  }

  static Uint8List? _unprotectBytes(Uint8List cipher) {
    final input = calloc<DataBlob>();
    final output = calloc<DataBlob>();
    final cipherPtr = calloc<Uint8>(cipher.length);

    try {
      for (var i = 0; i < cipher.length; i++) {
        cipherPtr[i] = cipher[i];
      }
      input.ref
        ..cbData = cipher.length
        ..pbData = cipherPtr;

      final ok = _unprotect(
        input,
        nullptr,
        nullptr,
        nullptr,
        nullptr,
        _cryptProtectUiForbidden,
        output,
      );
      if (ok == 0) return null;

      final length = output.ref.cbData;
      return Uint8List.fromList(output.ref.pbData.asTypedList(length));
    } finally {
      if (output.ref.pbData != nullptr) {
        calloc.free(output.ref.pbData);
      }
      calloc.free(cipherPtr);
      calloc.free(input);
      calloc.free(output);
    }
  }
}

final class DataBlob extends Struct {
  @Uint32()
  external int cbData;

  external Pointer<Uint8> pbData;
}
