import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_io/io.dart';

/// Runtime photo / media access for picking files to scan.
enum MediaAccessState {
  granted,
  denied,
  restricted,
  notApplicable,
}

abstract final class MediaPermissions {
  static bool get applies =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Called once when the main app UI appears (after splash).
  static Future<MediaAccessState> requestOnAppEntry() async {
    if (!applies) return MediaAccessState.notApplicable;
    return _requestAll();
  }

  /// Ensures access before opening the file picker; shows guidance if blocked.
  static Future<bool> ensureForFilePicker(BuildContext context) async {
    if (!applies) return true;

    final state = await _requestAll();
    if (state == MediaAccessState.granted) return true;
    if (!context.mounted) return false;

    if (state == MediaAccessState.restricted) {
      await _showSettingsDialog(context);
      return false;
    }

    if (state == MediaAccessState.denied && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Photo access was denied. You can still pick files from the system '
            'picker, or allow access in Settings.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
    }
    // System document picker may still work without broad media access.
    return true;
  }

  static Future<MediaAccessState> _requestAll() async {
    final targets = _targetsForPlatform();
    var granted = false;
    var permanentlyDenied = false;
    var restricted = false;

    for (final permission in targets) {
      final current = await permission.status;
      if (current.isGranted || current.isLimited) {
        granted = true;
        continue;
      }
      if (current.isRestricted) {
        restricted = true;
        continue;
      }
      if (current.isPermanentlyDenied) {
        permanentlyDenied = true;
        continue;
      }

      final result = await permission.request();
      if (result.isGranted || result.isLimited) granted = true;
      if (result.isPermanentlyDenied) permanentlyDenied = true;
      if (result.isRestricted) restricted = true;
    }

    if (granted) return MediaAccessState.granted;
    if (restricted || permanentlyDenied) return MediaAccessState.restricted;
    return MediaAccessState.denied;
  }

  static List<Permission> _targetsForPlatform() {
    if (Platform.isIOS) return [Permission.photos];
    if (Platform.isAndroid) {
      return [
        Permission.photos,
        Permission.storage,
      ];
    }
    return const [];
  }

  static Future<void> _showSettingsDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Allow file access'),
        content: const Text(
          'ZeroTrace needs permission to read photos and files on your device '
          'so you can select them for privacy scanning. Enable access in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
