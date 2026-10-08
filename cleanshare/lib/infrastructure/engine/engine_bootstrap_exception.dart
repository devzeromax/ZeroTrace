/// Thrown when native engine integrity or bootstrap fails (fail-closed).
class EngineBootstrapException implements Exception {
  EngineBootstrapException(this.message);
  final String message;

  @override
  String toString() => 'EngineBootstrapException: $message';
}
