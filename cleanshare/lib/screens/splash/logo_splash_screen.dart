import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_branding.dart';
import '../../widgets/zerotrace_logo.dart';

/// Startup splash video shown before any permission prompts or onboarding.
class LogoSplashScreen extends StatefulWidget {
  const LogoSplashScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<LogoSplashScreen> createState() => _LogoSplashScreenState();
}

class _LogoSplashScreenState extends State<LogoSplashScreen>
    with SingleTickerProviderStateMixin {
  static const _fadeOut = Duration(milliseconds: 420);
  static const _maxSplash = Duration(seconds: 12);
  static const _initTimeout = Duration(seconds: 6);

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
    _maxTimer = Timer(_maxSplash, _beginExit);
    _initVideo();
  }

  Future<void> _initVideo() async {
    VideoPlayerController? controller;
    try {
      controller = VideoPlayerController.asset(AppAssets.splashVideo);
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
        _durationTimer = Timer(dur + const Duration(milliseconds: 300), () {
          if (mounted && !_exiting) _beginExit();
        });
      }
    } catch (e, st) {
      developer.log(
        'Splash video failed; fallback to logo',
        name: 'SplashVideo',
        error: e,
        stackTrace: st,
      );
      await _disposeVideo();
      if (mounted && !_exiting) {
        Future<void>.delayed(const Duration(milliseconds: 1200), () {
          if (mounted && !_exiting) _beginExit();
        });
      }
    }
  }

  void _onVideoTick() {
    final c = _video;
    if (c == null || _videoDisposed || _exiting || !c.value.isInitialized) {
      return;
    }
    final pos = c.value.position;
    final dur = c.value.duration;
    final finished = dur > Duration.zero &&
        pos >= dur - const Duration(milliseconds: 150);
    if (c.value.hasError || finished) _beginExit();
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

  void _beginExit() {
    if (_exiting) return;
    _exiting = true;
    _maxTimer?.cancel();
    _durationTimer?.cancel();
    _video?.removeListener(_onVideoTick);
    _exit.forward().then((_) async {
      await _disposeVideo();
      if (mounted) widget.onComplete();
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
      label: AppBranding.name,
      child: ColoredBox(
        color: Colors.black,
        child: FadeTransition(
          opacity: Tween<double>(begin: 1, end: 0).animate(_exitFade),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const Center(child: ZeroTraceLogo(size: 150, showWordmark: false)),
              if (_videoReady && _video != null && !_videoDisposed)
                _CoverVideo(controller: _video!),
            ],
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
    final h = size.height > 0 ? size.height : 720.0;
    return IgnorePointer(
      child: SizedBox.expand(
        // ponytail: force true center alignment for startup video.
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          child: SizedBox(
            width: w,
            height: h,
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }
}
