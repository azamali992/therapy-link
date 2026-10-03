/// Asset paths for Eve and BreathFlower.
///
/// All paths are relative to the pubspec `assets/3d/` declaration.
/// The [VideoQuality] import comes from presence_rung.dart.
library;

import 'presence_rung.dart';

/// Asset paths for Eve's three animated states plus her poster and hero image.
abstract final class EveAssets {
  static const _base = 'assets/3d/';

  // ---- video loops --------------------------------------------------------

  /// 720px idle loop (8 s, H.264 on #1D1E2C).
  static const idleHd = '${_base}eve-idle.mp4';

  /// 360px idle loop (low-end / battery saver).
  static const idleLow = '${_base}eve-idle-360.mp4';

  /// 720px listening loop (4 s).
  static const listeningHd = '${_base}eve-listening.mp4';

  /// 360px listening loop.
  static const listeningLow = '${_base}eve-listening-360.mp4';

  /// 720px thinking loop (8 s).
  static const thinkingHd = '${_base}eve-thinking.mp4';

  /// 360px thinking loop.
  static const thinkingLow = '${_base}eve-thinking-360.mp4';

  // ---- stills -------------------------------------------------------------

  /// 720px poster — first frame of the idle loop (exhaled).
  static const poster = '${_base}eve.png';

  /// 1080×1920 onboarding hero: Eve in a plum-to-night space, lower 40% clear.
  static const hero = '${_base}eve-hero.png';

  // ---- glTF (rung a — reserved) -------------------------------------------

  /// glTF binary with all three animation clips (idle / listening / thinking).
  static const glb = '${_base}eve.glb';

  // ---- helpers ------------------------------------------------------------

  /// Returns the correct video asset path for the given state and quality.
  static String videoFor(EvePresenceState state, VideoQuality quality) {
    final low = quality == VideoQuality.low;
    return switch (state) {
      EvePresenceState.idle => low ? idleLow : idleHd,
      EvePresenceState.listening => low ? listeningLow : listeningHd,
      EvePresenceState.thinking => low ? thinkingLow : thinkingHd,
    };
  }
}

/// Asset paths for the BreathFlower.
abstract final class BreathAssets {
  static const _base = 'assets/3d/';

  /// 720px box-breathing loop (16 s, four 4-second phases).
  static const boxHd = '${_base}breath-box.mp4';

  /// 360px box-breathing loop (low-end).
  static const boxLow = '${_base}breath-box-360.mp4';

  /// Poster — the 6 s frame (flower held open).
  static const poster = '${_base}breath.png';

  /// glTF with the `box` animation clip.
  static const glb = '${_base}breath.glb';

  /// Returns the correct video asset for the given quality.
  static String videoFor(VideoQuality quality) =>
      quality == VideoQuality.low ? boxLow : boxHd;
}

/// The three animated states Eve can be in.
///
/// Renamed from [EveState] to avoid a clash with the [EveState] value-class in
/// `eve_controller.dart`, which describes the full chat controller state.
enum EvePresenceState {
  idle,
  listening,
  thinking,
}
