/// BreathFlower — the jasmine bloom for the box-breathing screen.
///
/// Plays the 16 s box-breathing video loop and exposes a [BreathClock] stream
/// that publishes the current phase and seconds-remaining once per second.
/// The screen's phase words, countdown and phase pills read this stream.
///
/// Rendering ladder:
///   video  → video_player loop (720 or 360 px depending on device)
///   poster → static PNG + text-only mode when reduced motion is on
///
/// The timer driving [BreathClock] runs independently in Dart (not from the
/// video position) so a dropped frame or backgrounded app cannot drift the
/// count. The video is re-synced to the timer position when it resumes.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../app/theme/tokens.dart';
import 'breath_clock.dart';
import 'device_signals_provider.dart';
import 'presence_assets.dart';
import 'presence_rung.dart';

// ---------------------------------------------------------------------------
// BreathFlower widget
// ---------------------------------------------------------------------------

/// Displays the box-breathing jasmine bloom and drives the breath clock.
///
/// [pattern] must be the 'box' pattern (4-4-4-4).
/// [onClock] receives the [BreathClock] so screen widgets can subscribe.
///
/// Pause/resume:
///   ```dart
///   final key = GlobalKey<BreathFlowerState>();
///   key.currentState?.pause();
///   key.currentState?.resume();
///   ```
class BreathFlower extends ConsumerStatefulWidget {
  const BreathFlower({
    super.key,
    required this.onClock,
    this.size = 280,
  });

  /// Called once when the clock is ready. The stream continues for the
  /// lifetime of this widget.
  final ValueChanged<Stream<BreathClockTick>> onClock;

  /// Logical pixel size of the flower widget.
  final double size;

  @override
  ConsumerState<BreathFlower> createState() => BreathFlowerState();
}

class BreathFlowerState extends ConsumerState<BreathFlower>
    with WidgetsBindingObserver {
  // ---- clock (source of truth) --------------------------------------------

  /// Elapsed seconds since start, driven by Dart timer.
  double _elapsed = 0;
  DateTime? _lastTick;
  Timer? _dartTimer;

  final _clockController = StreamController<BreathClockTick>.broadcast();

  // ---- video player -------------------------------------------------------

  VideoPlayerController? _controller;
  bool _videoReady = false;

  // ---- state --------------------------------------------------------------

  RungChoice? _rung;
  bool _paused = false;

  // ---- timeline -----------------------------------------------------------

  /// Duration of one full box-breathing cycle: 16 s.
  static const _cycleSecs = 16.0;

  // ---- lifecycle ----------------------------------------------------------

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
    widget.onClock(_clockController.stream);
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
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _pauseAll();
    } else if (state == AppLifecycleState.resumed) {
      if (!_paused) _resumeAll();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dartTimer?.cancel();
    _clockController.close();
    _controller?.dispose();
    super.dispose();
  }

  // ---- public pause/resume ------------------------------------------------

  void pause() {
    _paused = true;
    _pauseAll();
  }

  void resume() {
    _paused = false;
    _resumeAll();
  }

  // ---- private helpers ----------------------------------------------------

  void _init() {
    final signals = deviceSignalsOf(context, ref);
    _rung = chooseRung(signals);
    if (_rung!.rung == PresenceRung.video) {
      _initVideo(_rung!.quality);
    }
    _startDartTimer();
  }

  void _startDartTimer() {
    _lastTick = DateTime.now();
    _dartTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_paused || !mounted) return;
      final now = DateTime.now();
      final dt = now.difference(_lastTick!).inMilliseconds / 1000.0;
      _lastTick = now;
      _elapsed += dt;
      // Keep elapsed within the 16 s cycle (seamless loop).
      _elapsed = _elapsed % _cycleSecs;
      _emitTick();
      // Resync video to match dart timer (avoids drift).
      _syncVideoToTimer();
    });
  }

  void _emitTick() {
    final phaseIdx = (_elapsed / 4).floor().clamp(0, 3);
    final secsLeft = (4 - (_elapsed % 4)).ceil().clamp(1, 4);
    _clockController.add(BreathClockTick(
      phaseIndex: phaseIdx,
      secondsLeft: secsLeft,
    ));
  }

  void _syncVideoToTimer() {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    final target = Duration(
      microseconds: (_elapsed * 1e6).round(),
    );
    // Only seek if video drifted more than 0.5 s.
    final pos = ctrl.value.position;
    if ((pos - target).inMilliseconds.abs() > 500) {
      ctrl.seekTo(target);
    }
  }

  Future<void> _initVideo(VideoQuality quality) async {
    await _tearDownVideo();
    final path = BreathAssets.videoFor(quality);
    final ctrl = VideoPlayerController.asset(path);
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
      // Fall through to poster.
    }
  }

  Future<void> _tearDownVideo() async {
    await _controller?.dispose();
    _controller = null;
    _videoReady = false;
  }

  void _pauseAll() {
    _dartTimer?.cancel();
    _controller?.pause();
  }

  void _resumeAll() {
    _startDartTimer();
    _controller?.play();
  }

  // ---- build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final rung = _rung;
    final dp = widget.size;

    if (rung == null) return SizedBox.square(dimension: dp);

    if (rung.rung != PresenceRung.video || !_videoReady) {
      return _buildPoster(dp);
    }
    return _buildVideo(dp);
  }

  Widget _buildVideo(double dp) {
    final ctrl = _controller!;
    return SizedBox.square(
      dimension: dp,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: ctrl.value.size.width,
          height: ctrl.value.size.height,
          child: VideoPlayer(ctrl),
        ),
      ),
    );
  }

  Widget _buildPoster(double dp) {
    return ClipOval(
      child: Image.asset(
        BreathAssets.poster,
        width: dp,
        height: dp,
        fit: BoxFit.cover,
        errorBuilder: (context, err, stack) => Container(
          width: dp,
          height: dp,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Tokens.plum,
          ),
        ),
      ),
    );
  }
}
