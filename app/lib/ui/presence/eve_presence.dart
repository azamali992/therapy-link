/// EvePresence — Eve's animated avatar at three display sizes.
///
/// Renders Eve using the rendering ladder (video → poster → silhouette),
/// crossing-fading state changes in 240 ms. Follows reduced-motion, battery-
/// saver and low-RAM signals automatically.
///
/// Usage:
/// ```dart
/// EvePresence(
///   state: EvePresenceState.listening,
///   size: EvePresentSize.welcome,
/// )
/// ```
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../app/theme/tokens.dart';
import 'device_signals_provider.dart';
import 'eve_halo.dart';
import 'presence_assets.dart';
import 'presence_rung.dart';

// ---------------------------------------------------------------------------
// Size variants
// ---------------------------------------------------------------------------

/// The three display contexts for Eve.
enum EvePresentSize {
  /// Welcome screen hero — 232 dp square.
  welcome(232),

  /// Chat screen header avatar — 52 dp square.
  chatHeader(52),

  /// Inline dot in conversation list — 20 dp square.
  inlineDot(20);

  const EvePresentSize(this.dp);

  /// Logical pixel size.
  final double dp;
}

// ---------------------------------------------------------------------------
// Provider for the crisis-override flag
// ---------------------------------------------------------------------------

/// When true, Eve is forced to the idle state regardless of what the caller
/// requests. Set this from the crisis mode provider.
final evePresenceCrisisHoldProvider =
    NotifierProvider<EvePresenceCrisisHoldNotifier, bool>(
        EvePresenceCrisisHoldNotifier.new);

/// Holds the crisis-mode override flag for [EvePresence].
///
/// Set [hold] to true from the crisis mode controller to freeze Eve at idle.
class EvePresenceCrisisHoldNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Activate or release the crisis hold.
  void hold(bool active) => state = active;
}

// ---------------------------------------------------------------------------
// Main widget
// ---------------------------------------------------------------------------

/// Eve's animated presence widget.
///
/// [state] is the desired animation state (idle / listening / thinking).
/// A crisis-mode hold from [evePresenceCrisisHoldProvider] overrides this to
/// idle and prevents state changes until the hold is released.
///
/// [size] selects one of three pre-defined display contexts.
///
/// The halo (violet→pink radial gradient that breathes/pulses behind Eve) is
/// rendered by [EveHalo]; pass [showHalo] = false to suppress it on small sizes.
class EvePresence extends ConsumerStatefulWidget {
  const EvePresence({
    super.key,
    required this.state,
    this.size = EvePresentSize.chatHeader,
    this.showHalo = true,
  });

  final EvePresenceState state;
  final EvePresentSize size;

  /// Show the breathing halo behind Eve. Defaults to true; pass false for
  /// the 20 dp inline dot where it would be too small to be meaningful.
  final bool showHalo;

  @override
  ConsumerState<EvePresence> createState() => _EvePresenceState();
}

class _EvePresenceState extends ConsumerState<EvePresence>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  VideoPlayerController? _nextController;
  RungChoice? _rung;
  EvePresenceState? _activeState;
  double _opacity = 1.0;
  Timer? _crossfadeTimer;

  // ---- lifecycle ----------------------------------------------------------

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Deferred init so MediaQuery is available.
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-evaluate rung when MediaQuery changes (e.g. reduced-motion toggled).
    final signals = deviceSignalsOf(context, ref);
    final newRung = chooseRung(signals);
    if (newRung != _rung) {
      _rung = newRung;
      _applyState(_effectiveState, force: true);
    }
  }

  @override
  void didUpdateWidget(EvePresence old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) {
      _applyState(_effectiveState);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause video when the app goes to background (battery).
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _controller?.pause();
    } else if (state == AppLifecycleState.resumed) {
      _controller?.play();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _crossfadeTimer?.cancel();
    _controller?.dispose();
    _nextController?.dispose();
    super.dispose();
  }

  // ---- state helpers ------------------------------------------------------

  /// The state to actually render — overridden to idle in crisis mode.
  EvePresenceState get _effectiveState {
    final crisisHold = ref.read(evePresenceCrisisHoldProvider);
    return crisisHold ? EvePresenceState.idle : widget.state;
  }

  void _init() {
    final signals = deviceSignalsOf(context, ref);
    _rung = chooseRung(signals);
    _applyState(_effectiveState, force: true);
  }

  /// Start playing the appropriate asset for [state].
  ///
  /// If [force] is true the switch is immediate (first load). Otherwise a
  /// 240 ms crossfade is used — unless reduced motion is active, in which
  /// case even crossfades are omitted.
  void _applyState(EvePresenceState state, {bool force = false}) {
    if (_rung == null) return;
    if (!force && state == _activeState) return;
    final rung = _rung!;

    if (rung.rung != PresenceRung.video) {
      // Poster or silhouette — no video to manage; just rebuild.
      setState(() => _activeState = state);
      return;
    }

    final path = EveAssets.videoFor(state, rung.quality);
    final next = VideoPlayerController.asset(path);
    next
        .initialize()
        .then((_) {
          if (!mounted) {
            next.dispose();
            return;
          }
          next.setLooping(true);
          next.setVolume(0);
          next.play();

          if (force || _controller == null) {
            // Immediate swap on first load.
            final old = _controller;
            setState(() {
              _controller = next;
              _nextController = null;
              _activeState = state;
              _opacity = 1.0;
            });
            old?.dispose();
          } else {
            // Crossfade: fade out the current controller over 240 ms.
            final reducedMotion = MediaQuery.disableAnimationsOf(context);
            if (reducedMotion) {
              final old = _controller;
              setState(() {
                _controller = next;
                _nextController = null;
                _activeState = state;
                _opacity = 1.0;
              });
              old?.dispose();
            } else {
              _nextController = next;
              _crossfadeTimer?.cancel();
              setState(() => _opacity = 0.0);
              _crossfadeTimer = Timer(Tokens.normal, () {
                if (!mounted) return;
                final old = _controller;
                setState(() {
                  _controller = _nextController;
                  _nextController = null;
                  _activeState = state;
                  _opacity = 1.0;
                });
                old?.dispose();
              });
            }
          }
        })
        .onError((err, stack) {
          // Video failed to load — fall back silently to poster.
          if (!mounted) return;
          next.dispose();
          setState(() => _activeState = state);
        });
  }

  // ---- build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Listen to crisis hold changes.
    ref.listen(evePresenceCrisisHoldProvider, (_, next) {
      if (next) _applyState(EvePresenceState.idle, force: true);
    });

    final dp = widget.size.dp;
    final rung = _rung;
    final showHalo = widget.showHalo && widget.size != EvePresentSize.inlineDot;

    Widget child;
    if (rung == null) {
      // Not yet initialised.
      child = _buildSilhouette(dp);
    } else {
      child = switch (rung.rung) {
        PresenceRung.gltf => _buildSilhouette(dp), // not shipped
        PresenceRung.video => _buildVideo(dp),
        PresenceRung.poster => _buildPoster(dp),
        PresenceRung.silhouette => _buildSilhouette(dp),
      };
    }

    if (!showHalo) {
      return SizedBox.square(dimension: dp, child: child);
    }

    return SizedBox.square(
      dimension: dp,
      child: Stack(
        alignment: Alignment.center,
        children: [
          EveHalo(
            size: dp,
            mode: _haloMode,
            reducedMotion:
                rung?.rung == PresenceRung.poster || rung == null,
          ),
          child,
        ],
      ),
    );
  }

  HaloMode get _haloMode => switch (_activeState ?? EvePresenceState.idle) {
        EvePresenceState.idle => HaloMode.breathe,
        EvePresenceState.listening => HaloMode.breathe,
        EvePresenceState.thinking => HaloMode.pulse,
      };

  Widget _buildVideo(double dp) {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) {
      return _buildPoster(dp);
    }
    return AnimatedOpacity(
      opacity: _opacity,
      duration: Tokens.normal,
      child: ClipOval(
        child: SizedBox.square(
          dimension: dp,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: ctrl.value.size.width,
              height: ctrl.value.size.height,
              child: VideoPlayer(ctrl),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPoster(double dp) {
    return ClipOval(
      child: Image.asset(
        EveAssets.poster,
        width: dp,
        height: dp,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => _buildSilhouette(dp),
      ),
    );
  }

  Widget _buildSilhouette(double dp) => _EveSilhouette(size: dp);
}

// ---------------------------------------------------------------------------
// Painted silhouette fallback (rung d — no asset needed)
// ---------------------------------------------------------------------------

/// Rung (d): a pure-Flutter violet bud silhouette. Shows without any asset.
class _EveSilhouette extends StatelessWidget {
  const _EveSilhouette({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _BudPainter()),
    );
  }
}

class _BudPainter extends CustomPainter {
  // Presence palette — same violet and pink as EveHalo so the silhouette
  // reads as clearly Eve even when the video / poster assets aren't loaded.
  static const _violet = Color(0xFF8A4FFF);
  static const _pink = Color(0xFFF23598);
  static const _pinkLight = Color(0xFFFFD3EA);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.38;

    // Soft violet halo — stronger than before so it is visible on dark bg.
    final aura = Paint()
      ..shader = RadialGradient(
        colors: [
          _violet.withValues(alpha: 0.55),
          _violet.withValues(alpha: 0.18),
          const Color(0x00000000),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r * 1.65));
    canvas.drawCircle(Offset(cx, cy), r * 1.65, aura);

    // Five petals: pink→violet gradient fill from tip to base so the shape
    // reads clearly on both dark (#1D1E2C) and light backgrounds.
    const petalCount = 5;
    for (var i = 0; i < petalCount; i++) {
      final angle = (i / petalCount) * 2 * 3.14159265 - 3.14159265 / 2;
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(angle);

      // Gradient: pink at the tip (0, -r*0.95) → violet at the base (0, 0).
      final petalFill = Paint()
        ..style = PaintingStyle.fill
        ..shader = ui.Gradient.linear(
          Offset(0, -r * 0.95),
          const Offset(0, 0),
          const [_pink, _violet],
        );
      final petalEdge = Paint()
        ..style = PaintingStyle.stroke
        ..color = _pinkLight.withValues(alpha: 0.55)
        ..strokeWidth = size.width * 0.013;

      final petalPath = Path()
        ..moveTo(0, 0)
        ..cubicTo(
          -r * 0.22, -r * 0.15,
          -r * 0.22, -r * 0.82,
          0, -r * 0.95,
        )
        ..cubicTo(
          r * 0.22, -r * 0.82,
          r * 0.22, -r * 0.15,
          0, 0,
        );
      canvas.drawPath(petalPath, petalFill);
      canvas.drawPath(petalPath, petalEdge);
      canvas.restore();
    }

    // Core glow — brighter centre for depth.
    final core = Paint()
      ..shader = RadialGradient(
        colors: [_pinkLight, _pink, _violet],
        stops: const [0.0, 0.42, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.30));
    canvas.drawCircle(Offset(cx, cy), r * 0.30, core);
  }

  @override
  bool shouldRepaint(_BudPainter old) => false;
}

