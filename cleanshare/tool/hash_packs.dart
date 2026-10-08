import 'dart:io';

import 'package:crypto/crypto.dart';

void main() {
  final dir = Directory('assets/marketplace/packs');
  for (final entity in dir.listSync().whereType<File>()) {
    if (!entity.path.endsWith('.zip')) continue;
    final digest = sha256.convert(entity.readAsBytesSync()).toString();
    stdout.writeln('${entity.uri.pathSegments.last}: $digest');
  }
}
