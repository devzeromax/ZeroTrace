import 'pack_trust_policy.dart';

/// Trips after repeated failed pack installs (ASI-10 behavioral guard).
class PackInstallGuard {
  PackInstallGuard({this.maxFailures = 3, this.cooldown = const Duration(minutes: 15)});

  final int maxFailures;
  final Duration cooldown;

  int _failures = 0;
  DateTime? _trippedAt;

  void recordSuccess() {
    _failures = 0;
    _trippedAt = null;
  }

  void recordFailure() {
    _failures++;
    if (_failures >= maxFailures) {
      _trippedAt = DateTime.now();
    }
  }

  void assertCanInstall() {
    if (_trippedAt == null) return;
    final elapsed = DateTime.now().difference(_trippedAt!);
    if (elapsed >= cooldown) {
      _failures = 0;
      _trippedAt = null;
      return;
    }
    throw PackTrustException(
      'Pack installs paused after repeated failures. '
      'Try again in ${(cooldown - elapsed).inMinutes + 1} minutes.',
    );
  }
}
