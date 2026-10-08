/// Bundled UI audio — short cues only (no BGM loops).
///
/// | Asset | Purpose |
/// |-------|---------|
/// | [exportSuccess] | Major success: sanitized export finished |
/// | [uiConfirm] | Light confirmation: save / pack install notification |
abstract final class AppSounds {
  /// Glockenspiel treasure sting — export / celebration success.
  static const exportSuccess = 'assets/sounds/export_success.mp3';

  /// Soft correct-answer tone — snackbar-style confirmations.
  static const uiConfirm = 'assets/sounds/ui_confirm.wav';
}
