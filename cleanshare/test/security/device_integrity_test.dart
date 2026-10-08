import 'package:flutter_test/flutter_test.dart';

import 'package:cleanshare/infrastructure/security/device_integrity.dart';

void main() {
  test('hostileRuntime combines root debug frida flags', () {
    const report = DeviceIntegrityReport(
      debuggerAttached: true,
      rootSuspected: false,
    );
    expect(report.hostileRuntime, isTrue);
  });

  test('safe report is not hostile', () {
    expect(DeviceIntegrityReport.safe.hostileRuntime, isFalse);
  });
}
