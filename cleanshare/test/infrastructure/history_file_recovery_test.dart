import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:cleanshare/domain/storage/storage_layout.dart';
import 'package:cleanshare/infrastructure/storage/history_file_recovery.dart';

void main() {
  test('findStagedPath matches timestamped scan files', () async {
    final root = await Directory.systemTemp.createTemp('zt_recovery_');
    addTearDown(() => root.deleteSync(recursive: true));

    final layout = ZeroTraceLayout(root: root);
    await layout.ensureCreated();

    final staged = File(p.join(layout.scans.path, '1700000000000_photo.jpg'));
    await staged.writeAsBytes([1, 2, 3]);

    final found = HistoryFileRecovery.findStagedPath(layout, 'photo.jpg');
    expect(found, staged.path);
  });

  test('findExportPath locates sanitized export by file name', () async {
    final root = await Directory.systemTemp.createTemp('zt_recovery_');
    addTearDown(() => root.deleteSync(recursive: true));

    final layout = ZeroTraceLayout(root: root);
    await layout.ensureCreated();

    final exported =
        File(p.join(layout.exports.path, 'invoice_photo_sanitized.jpg'));
    await exported.writeAsBytes([9, 9, 9]);

    final found = HistoryFileRecovery.findExportPath(layout, 'invoice_photo.jpg');
    expect(found, exported.path);
  });
}
