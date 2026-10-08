import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cleanshare/domain/storage/storage_layout.dart';
import 'package:cleanshare/infrastructure/security/security_audit_log.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('verifyChain accepts valid append-only log', () async {
    final layout = ZeroTraceLayout(
      root: Directory.systemTemp.createTempSync('audit_chain_'),
    );
    await layout.ensureCreated();
    final log = SecurityAuditLog(layout);

    await log.record(event: 'boot', detail: 'ok');
    await log.record(event: 'scan', detail: 'started');

    expect(await log.verifyChain(), isTrue);
  });

  test('verifyChain rejects tampered mac', () async {
    final layout = ZeroTraceLayout(
      root: Directory.systemTemp.createTempSync('audit_tamper_'),
    );
    await layout.ensureCreated();
    final log = SecurityAuditLog(layout);

    await log.record(event: 'boot', detail: 'ok');
    final file = File('${layout.logs.path}/security_audit.jsonl');
    final lines = await file.readAsLines();
    final entry = jsonDecode(lines.single) as Map<String, dynamic>;
    entry['mac'] = '0' * 64;
    await file.writeAsString('${jsonEncode(entry)}\n');

    expect(await log.verifyChain(), isFalse);
  });
}
