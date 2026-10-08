import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

void main() {
  final raw = File('assets/marketplace/catalog.json').readAsStringSync();
  final digest = sha256.convert(utf8.encode(raw)).toString();
  stdout.writeln(digest);
}
