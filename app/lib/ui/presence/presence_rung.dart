/// Rendering ladder for Eve and the breath flower.
///
/// The ladder has four rungs, from richest to lightest:
///   (a) live glTF — NOT shipped yet; interface reserved for a future engineer.
///   (b) video loop — default when the device can handle it.
///   (c) poster still — battery saver, low RAM, data saver, or reduced motion.
///   (d) painted silhouette — last resort; no asset needed.
///
/// [chooseRung] is a pure function so it can be tested without any Flutter
/// context. It takes the device/OS signals as plain booleans and returns the
/// appropriate rung.
library;

/// The four rungs of the Eve rendering ladder.
enum PresenceRung {
  /// (a) Real-time glTF via flutter_scene/Impeller — reserved, not shipped.
  gltf,

  /// (b) Pre-rendered video loop via video_player.
  video,

  /// (c) Static poster image (PNG).
  poster,

  /// (d) Painted bud silhouette — pure Flutter, no asset required.
  silhouette,
}

/// Which video resolution to use when [PresenceRung.video] is selected.
enum VideoQuality {
  /// 720 px square — default for capable devices.
  hd,

  /// 360 px square — battery saver, low RAM (<3 GB), data saver.
  low,
}

/// Signals that the ladder logic reads. All are plain booleans; callers
/// obtain them from the OS/MediaQuery/platform channel and pass them in.
class DeviceSignals {
  const DeviceSignals({
    this.reducedMotion = false,
    this.batterySaver = false,
    this.lowRam = false,
    this.dataSaver = false,
  });

  /// `MediaQuery.disableAnimationsOf(context)` — OS reduced-motion toggle.
  final bool reducedMotion;

  /// Battery saver / power-saving mode is active.
  final bool batterySaver;

  /// Detected available RAM is less than the low-RAM threshold (~3 GB).
  final bool lowRam;

  /// OS data-saver mode is active (Android: `ConnectivityManager.restrictBackgroundStatus`).
  final bool dataSaver;

  @override
  String toString() => 'DeviceSignals('
      'reducedMotion: $reducedMotion, '
      'batterySaver: $batterySaver, '
      'lowRam: $lowRam, '
      'dataSaver: $dataSaver)';
}

/// Ladder selection result: which rung to render and (if video) which quality.
class RungChoice {
  const RungChoice(this.rung, {this.quality = VideoQuality.hd});

  final PresenceRung rung;

  /// Only meaningful when [rung] is [PresenceRung.video].
  final VideoQuality quality;

  @override
  String toString() => 'RungChoice($rung, quality: $quality)';

  @override
  bool operator ==(Object other) =>
      other is RungChoice && other.rung == rung && other.quality == quality;

  @override
  int get hashCode => Object.hash(rung, quality);
}

/// Pure function — choose the rendering rung from device/OS signals.
///
/// Decision table (first matching rule wins):
/// 1. reducedMotion → poster (crossfade to poster, never animate).
/// 2. batterySaver || lowRam || dataSaver → poster or 360px video.
///    - We use 360px video here so users get motion but at minimal cost.
/// 3. Otherwise → 720px video.
///
/// glTF (rung a) is intentionally excluded: see README.md for the evaluation.
RungChoice chooseRung(DeviceSignals signals) {
  if (signals.reducedMotion) {
    return const RungChoice(PresenceRung.poster);
  }
  if (signals.batterySaver || signals.lowRam || signals.dataSaver) {
    return const RungChoice(PresenceRung.video, quality: VideoQuality.low);
  }
  return const RungChoice(PresenceRung.video, quality: VideoQuality.hd);
}
