import 'package:flutter_test/flutter_test.dart';

import 'package:cleanshare/infrastructure/security/pack_trust_policy.dart';

void main() {
  group('PathGuard', () {
    const root = r'C:\Users\test\AppData\ZeroTrace';

    test('allows paths under root', () {
      final resolved = PathGuard.resolveUnderRoot(root, 'scans/file.jpg');
      expect(resolved, contains('scans'));
      expect(
        PathGuard.isUnderRoot(root, resolved),
        isTrue,
      );
    });

    test('rejects zip-slip traversal', () {
      expect(
        () => PathGuard.resolveUnderRoot(root, r'..\..\Windows\System32\evil.dll'),
        throwsA(isA<PathGuardException>()),
      );
    });

    test('rejects absolute escape via parent segments', () {
      expect(
        () => PathGuard.resolveUnderRoot(root, '../outside/secret.txt'),
        throwsA(isA<PathGuardException>()),
      );
    });
  });
}
