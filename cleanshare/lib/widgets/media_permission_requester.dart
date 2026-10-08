import 'package:flutter/material.dart';

import '../core/platform/media_permissions.dart';

/// Requests media / photo permissions when the main app first appears.
class MediaPermissionRequester extends StatefulWidget {
  const MediaPermissionRequester({super.key, required this.child});

  final Widget child;

  @override
  State<MediaPermissionRequester> createState() =>
      _MediaPermissionRequesterState();
}

class _MediaPermissionRequesterState extends State<MediaPermissionRequester> {
  static var _requestedThisSession = false;

  @override
  void initState() {
    super.initState();
    if (!_requestedThisSession && MediaPermissions.applies) {
      _requestedThisSession = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        MediaPermissions.requestOnAppEntry();
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
