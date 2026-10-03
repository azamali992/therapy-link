/// EveHero — full-bleed welcome screen hero with optional idle video.
///
/// Displays `eve-hero.png` full-bleed. The lower 40% of the image is
/// intentionally empty so screen copy can sit over it without obscuring Eve.
///
/// Where video is allowed (not reduced motion, not battery/data saver),
/// the idle video is composited on top of the hero at Eve's natural position.
/// Otherwise just the static PNG is shown — the hero looks complete on its own.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import 'device_signals_provider.dart';
import 'presence_assets.dart';
import 'presence_rung.dart';

/// Full-bleed hero for the welcome screen.
///
/// Fills its parent's constraints. Wrap in a [SizedBox] or [AspectRatio]
/// to control dimensions:
/// ```dart
/// AspectRatio(
///   aspectRatio: 1080 / 1920,
///   child: EveHero(),
/// )
/// ```
///
/// [overlayAlignment] controls where the video loop is positioned within the
/// full-bleed frame. Defaults to the upper-center third where Eve appears
/// in the hero image.
class EveHero extends ConsumerStatefulWidget {
  const EveHero({
    super.key,
    this.overlayAlignment = const Alignment(0, -0.35),
    this.overlayFraction = 0.48,
  });

  /// Alignment within the full-bleed frame for the video overlay.
  final Alignment overlayAlignment;

  /// The video loop's width as a fraction of the widget's width.
  final double overlayFraction;

  @override
  ConsumerState<EveHero> createState() => _EveHeroState();
}

class _EveHeroState extends ConsumerState<EveHero>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _videoReady = false;
  RungChoice? _rung;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final signals = deviceSignalsOf(context, ref);
    final newRung = chooseRung(signals);
    if (newRung != _rung) {
      _rung = newRung;
      if (newRung.rung == PresenceRung.video) {
        _initVideo(newRung.quality);
      } else {
        _tearDownVideo();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _controller?.pause();
    } else if (state == AppLifecycleState.resumed) {
      _controller?.play();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  void _init() {
    final signals = deviceSignalsOf(context, ref);
    _rung = chooseRung(signals);
    if (_rung!.rung == PresenceRung.video) {
      _initVideo(_rung!.quality);
    }
  }

  Future<void> _initVideo(VideoQuality quality) async {
    await _tearDownVideo();
    final ctrl = VideoPlayerController.asset(EveAssets.videoFor(EveState.idle, quality));
    try {
      await ctrl.initialize();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      ctrl.setLooping(true);
      ctrl.setVolume(0);
      ctrl.play();
      setState(() {
        _controller = ctrl;
        _videoReady = true;
      });
    } catch (_) {
      ctrl.dispose();
    }
  }

  Future<void> _tearDownVideo() async {
    await _controller?.dispose();
    _controller = null;
    if (mounted) setState(() => _videoReady = false);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          fit: StackFit.expand,
          children: [
            // Base: full-bleed hero PNG.
            Image.asset(
              EveAssets.hero,
              width: w,
              height: h,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
            // Overlay: idle video where allowed.
            if (_videoReady && _controller != null)
              Align(
                alignment: widget.overlayAlignment,
                child: _buildVideoOverlay(w),
              ),
          ],
        );
      },
    );
  }

  Widget _buildVideoOverlay(double parentWidth) {
    final ctrl = _controller!;
    final size = parentWidth * widget.overlayFraction;
    return SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: ctrl.value.size.width,
            height: ctrl.value.size.height,
            child: VideoPlayer(ctrl),
          ),
        ),
      ),
    );
  }
}
