// ponytail: assert-based self-check — fail if startup media asset paths break.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cleanshare/core/constants/app_assets.dart';

void main() {
  void expectRealMp4(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: path);
    // ponytail: small splash clips are valid; only assert non-trivial payload.
    expect(file.lengthSync(), greaterThan(40 * 1024));
    final head = file.readAsBytesSync().sublist(0, 12);
    expect(String.fromCharCodes(head.sublist(4, 8)), 'ftyp');
  }

  test('splash asset exists and is a real mp4', () {
    expectRealMp4(AppAssets.splashVideo);
  });

  test('intro logomotion asset exists and is a real mp4', () {
    expectRealMp4(AppAssets.introLogomotion);
  });
}
