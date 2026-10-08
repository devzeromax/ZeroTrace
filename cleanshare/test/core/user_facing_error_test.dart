import 'package:flutter_test/flutter_test.dart';

import 'package:cleanshare/core/utils/user_facing_error.dart';
import 'package:cleanshare/infrastructure/marketplace/marketplace_service.dart';

void main() {
  test('maps namespace errors to friendly copy', () {
    expect(
      UserFacingError.message(Exception('Unsupported operation: _Namespace')),
      contains('Windows app'),
    );
  });

  test('passes through marketplace exceptions', () {
    expect(
      UserFacingError.message(
        MarketplaceException('Built-in models cannot be removed.'),
      ),
      'Built-in models cannot be removed.',
    );
  });

  test('maps network errors', () {
    expect(
      UserFacingError.message(Exception('SocketException: failed host lookup')),
      contains('internet'),
    );
  });

  test('generic fallback for unknown errors', () {
    expect(
      UserFacingError.message(Exception('weird internal xyz')),
      'Something went wrong. Please try again.',
    );
  });
}
