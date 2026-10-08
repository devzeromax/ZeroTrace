// ignore_for_file: avoid_print

/// Pins SHA-256 of native engine libraries in pack_trust_constants.dart.
///
/// Run after building the engine (from cleanshare/):
///   dart run tool/embed_engine_hash.dart
///   dart run tool/embed_engine_hash.dart --platform android
///   dart run tool/embed_engine_hash.dart --debug
library;

import 'dart:io';

import 'package:crypto/crypto.dart';

import 'supply_chain_utils.dart';

Future<void> main(List<String> args) async {
  final release = !args.contains('--debug');
  final platform = _readPlatformArg(args);

  if (platform == 'android') {
    final fromApk = args.contains('--release-apk');
    final so = fromApk
        ? _androidStrippedEngineFromBuild()
        : File(
            '${SupplyChainPaths.repoRoot}${Platform.pathSeparator}android'
            '${Platform.pathSeparator}app${Platform.pathSeparator}src'
            '${Platform.pathSeparator}main${Platform.pathSeparator}jniLibs'
            '${Platform.pathSeparator}arm64-v8a'
            '${Platform.pathSeparator}libzerotrace_engine.so',
          );
    if (!await so.exists()) {
      print('Android engine not found: ${so.path}');
      if (fromApk) {
        print('Build release APK first: flutter build apk --release --target-platform android-arm64');
      } else {
        print('Build first: .\\tool\\build_engine_android.ps1');
        print('Or pin from release APK: dart run tool/embed_engine_hash.dart --platform android --release-apk');
      }
      exit(1);
    }
    final hash = sha256.convert(await so.readAsBytes()).toString();
    patchEngineLibHash('android', hash);
    print('Pinned Android arm64 engine (${fromApk ? 'release/stripped' : 'jniLibs'}):');
    print('  Path: ${so.path}');
    print('  SHA256: $hash');
    return;
  }

  final dll = SupplyChainPaths.engineDll(release: release);
  if (!await dll.exists()) {
    print('DLL not found: ${dll.path}');
    print('Build first: .\\tool\\build_engine.ps1');
    exit(1);
  }

  final hash = sha256.convert(await dll.readAsBytes()).toString();
  patchConstant('engineDllSha256Windows', hash);

  print('Pinned ${release ? 'release' : 'debug'} engine DLL:');
  print('  Path: ${dll.path}');
  print('  SHA256: $hash');
}

String? _readPlatformArg(List<String> args) {
  final index = args.indexOf('--platform');
  if (index < 0 || index + 1 >= args.length) return null;
  return args[index + 1];
}

File _androidStrippedEngineFromBuild() {
  final root = SupplyChainPaths.repoRoot;
  final sep = Platform.pathSeparator;
  return File(
    '$root${sep}build${sep}app${sep}intermediates${sep}stripped_native_libs'
    '${sep}release${sep}stripReleaseDebugSymbols${sep}out${sep}lib'
    '${sep}arm64-v8a${sep}libzerotrace_engine.so',
  );
}

void patchEngineLibHash(String os, String hash) {
  final file = SupplyChainPaths.constantsFile;
  var content = file.readAsStringSync();
  final pattern = RegExp(
    r"static const engineLibHashes = <String, String>\{[\s\S]*?\};",
  );
  if (!pattern.hasMatch(content)) {
    throw StateError('Could not find engineLibHashes in ${file.path}');
  }

  final existing = pattern.firstMatch(content)!.group(0)!;
  final entry = "'$os': '$hash',";
  String updated;
  if (existing.contains("'$os':")) {
    updated = existing.replaceFirst(
      RegExp("'$os':\\s*'[^']*',"),
      entry,
    );
  } else {
    updated = existing.replaceFirst(
      '};',
      '    $entry\n  };',
    );
  }

  content = content.replaceFirst(pattern, updated);
  file.writeAsStringSync(content);
}
