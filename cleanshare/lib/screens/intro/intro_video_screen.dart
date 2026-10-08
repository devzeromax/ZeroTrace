import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_branding.dart';
import '../../core/platform/media_permissions.dart';
import '../../core/routing/app_routes.dart';
import '../../providers/intro_video_provider.dart';
import '../../widgets/zerotrace_logo.dart';

/// First-launch (and replay) logomotion — plays once after splash, then onboarding.
///
/// Asset must be H.264 + AAC (Opus fails on Android ExoPlayer).
class IntroVideoScreen extends ConsumerStatefulWidget {
  const IntroVideoScreen({super.key});

  @override
  ConsumerState<IntroVideoScreen> createState() => _IntroVideoScreenState();
}

class _IntroVideoScreenState extends ConsumerState<IntroVideoScreen>
    with SingleTickerProviderStateMixin {
  static const _fadeOut = Duration(milliseconds: 480);
  static const _maxPlay = Duration(seconds: 18);
  static const _initTimeout = Duration(seconds: 8);

  VideoPlayerController? _video;
  late final AnimationController _exit;
  late final Animation<double> _exitFade;
  Timer? _maxTimer;
  Timer? _durationTimer;

  bool _videoReady = false;
  bool _exiting = false;
  bool _videoDisposed = false;

  @override
  void initState() {
    super.initState();
    _exit = AnimationController(vsync: this, duration: _fadeOut);
    _exitFade = CurvedAnimation(parent: _exit, curve: Curves.easeInOut);
    _maxTimer = Timer(_maxPlay, _finish);
    Future.microtask(_requestThenPlay);
  }

  Future<void> _requestThenPlay() async {
    try {
      await MediaPermissions.requestOnAppEntry();
    } catch (_) {
      // ponytail: permission prompt outcome isn't a blocker; start video anyway.
    }
    if (!mounted || _exiting) return;
    await _initVideo();
  }

  Future<void> _initVideo() async {
    VideoPlayerController? controller;
    try {
      controller = VideoPlayerController.asset(AppAssets.introLogomotion);
      if (_exiting || _videoDisposed) {
        await controller.dispose();
        return;
      }
      _video = controller;
      await controller.initialize().timeout(_initTimeout);
      if (!mounted || _exiting || _videoDisposed) {
        await _disposeVideo();
        return;
      }
      await controller.setLooping(false);
      await controller.setVolume(1);
      await controller.play();
      if (!mounted || _exiting || _videoDisposed) {
        await _disposeVideo();
        return;
      }
      setState(() => _videoReady = true);
      controller.addListener(_onVideoTick);

      final dur = controller.value.duration;
      if (dur > Duration.zero) {
        _durationTimer?.cancel();
        _durationTimer = Timer(dur + const Duration(milliseconds: 400), () {
          if (mounted && !_exiting) _finish();
        });
      }
    } catch (e, st) {
      developer.log(
        'Intro video failed; skipping to onboarding',
        name: 'IntroVideo',
        error: e,
        stackTrace: st,
      );
      await _disposeVideo();
      if (mounted && !_exiting) _finish();
    }
  }

  void _onVideoTick() {
    final c = _video;
    if (c == null || _videoDisposed || _exiting) return;
    if (!c.value.isInitialized) return;

    if (c.value.hasError) {
      developer.log(
        'Intro playback error: ${c.value.errorDescription}',
        name: 'IntroVideo',
      );
      _finish();
      return;
    }

    final pos = c.value.position;
    final dur = c.value.duration;
    final nearEnd =
        dur > Duration.zero && pos >= dur - const Duration(milliseconds: 200);
    final finishedIdle = dur > Duration.zero &&
        !c.value.isPlaying &&
        pos > Duration.zero &&
        pos >= dur - const Duration(milliseconds: 500);
    if (nearEnd || finishedIdle) {
      _finish();
    }
  }

  Future<void> _disposeVideo() async {
    if (_videoDisposed) return;
    _videoDisposed = true;
    _videoReady = false;
    final c = _video;
    _video = null;
    if (c == null) return;
    c.removeListener(_onVideoTick);
    try {
      await c.pause();
    } catch (_) {}
    try {
      await c.dispose();
    } catch (_) {}
  }

  void _finish() {
    if (_exiting) return;
    _exiting = true;
    _maxTimer?.cancel();
    _durationTimer?.cancel();
    _video?.removeListener(_onVideoTick);
    _exit.forward().then((_) async {
      await _disposeVideo();
      if (!mounted) return;
      await ref.read(introVideoProvider.notifier).markSeen();
      if (!mounted) return;
      context.go(AppRoutes.onboarding);
    });
  }

  @override
  void dispose() {
    _maxTimer?.cancel();
    _durationTimer?.cancel();
    unawaited(_disposeVideo());
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${AppBranding.name} introduction',
      button: true,
      onTap: _finish,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finish,
        child: ColoredBox(
          color: Colors.black,
          child: FadeTransition(
            opacity: Tween<double>(begin: 1, end: 0).animate(_exitFade),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const Center(
                  child: ZeroTraceLogo(size: 160, showWordmark: false),
                ),
                if (_videoReady && _video != null && !_videoDisposed)
                  _CoverVideo(controller: _video!),
                Positioned(
                  right: 16,
                  top: MediaQuery.paddingOf(context).top + 8,
                  child: TextButton(
                    onPressed: _finish,
                    child: const Text('Skip'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverVideo extends StatelessWidget {
  const _CoverVideo({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.size;
    final w = size.width > 0 ? size.width : 720.0;
    final h = size.height > 0 ? size.height : 1280.0;
    return IgnorePointer(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: w,
          height: h,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}
