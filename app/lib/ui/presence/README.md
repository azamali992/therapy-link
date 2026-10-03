# `ui/presence` — Eve and BreathFlower rendering

Motion / 3D module. Owns the rendering ladder for Eve and the breathing object.

## Widgets

| Widget | Where used | dp size |
|---|---|---|
| `EvePresence` | Welcome hero, chat header, conversation list dot | 232 / 52 / 20 |
| `EveHalo` | Behind Eve (violet→pink radial) | auto |
| `EveHero` | Welcome screen full-bleed background | fills parent |
| `BreathFlower` | Box-breathing screen | 280 (default) |

Import everything from the barrel:
```dart
import 'package:therapylink/ui/presence/presence.dart';
```

## Rendering ladder

The ladder is chosen by `chooseRung(DeviceSignals)` — a pure function with tests in `test/presence_rung_test.dart`.

| Rung | Trigger | Asset |
|---|---|---|
| **(a) glTF** | not shipped | `eve.glb` / `breath.glb` (reserved) |
| **(b) video HD** | default | 720 px MP4 |
| **(b) video low** | battery saver / low RAM (<3 GB) / data saver | 360 px MP4 |
| **(c) poster** | reduced motion | 720 px PNG |
| **(d) silhouette** | asset load failure | pure Flutter `CustomPainter` |

Rule: reduced motion → poster regardless of other flags.

## glTF evaluation (Flutter 3.47, October 2026)

**`flutter_scene`** (Impeller only)
: Imports glTF at *build time* via `flutter_scene_importer`, meaning the `.glb` is transcoded to a proprietary binary at compile time rather than loaded at runtime. It supports node TRS animation and clip switching, which is exactly what these files use. The two blockers on Android today are: (1) Impeller is the default renderer on Android but there is still a device-specific fallback path to Skia where `flutter_scene` will not render at all; (2) `KHR_materials_emissive_strength` (used on all of Eve's emissive meshes) is silently ignored — petals will look noticeably dimmer. A workaround (baking the multiplier into the emission textures at export time) is possible but requires rebuilding the GLBs. **Verdict: conditional green — use it if you can accept the emissive-strength limitation or bake the textures, and accept the Skia fallback path on older devices.**

**`model_viewer_plus`** (WebView)
: Wraps Google's `<model-viewer>` inside a `WebView`. The GLBs have been verified to load and animate correctly in `<model-viewer>` 4 (see `src/preview.html`). The WebView costs ~80–120 MB of extra memory on Android, significantly more than the video player, and has a longer cold-start. On a chat screen where Eve is always visible, that cost is paid once; on the welcome screen it may not warm up fast enough. Also, the `camera-orbit` and `field-of-view` settings from the README must be applied to avoid Eve appearing small. **Verdict: viable for the welcome screen hero where a few hundred ms of startup is acceptable. Too heavy for the chat header (52 dp) or inline dot (20 dp). Not suitable for low-end devices.**

**Decision for this branch**: ship rungs (b)–(d) now. The clean interface for rung (a) is `PresenceRung.gltf` in `presence_rung.dart` — the widget already has a branch for it that currently falls through to the silhouette. A future engineer adds the `flutter_scene` or `model_viewer_plus` widget into that branch.

## EveHalo animation table

| State | Mode | Period | Scale range |
|---|---|---|---|
| idle / listening | breathe | 6 s | 1.00 – 1.08 |
| thinking | pulse | 1.6 s | 1.00 – 1.12 |
| reduced motion | static | — | 1.00 |

## BreathFlower clock

`BreathFlower` emits `BreathClockTick` on a `Stream<BreathClockTick>` once per second. The stream is driven by a Dart `Timer.periodic`, **not** the video position. The video is re-synced to the timer on each tick (seeking if it drifted > 0.5 s), so a dropped frame or a backgrounded-then-resumed app cannot desynchronise the countdown from the visual.

```dart
BreathFlower(
  onClock: (stream) => stream.listen((tick) {
    print('${tick.phaseLabel}: ${tick.secondsLeft}');
  }),
)
```

Phase index → label:
- 0 → Breathe in
- 1 → Hold
- 2 → Breathe out
- 3 → Hold

## Battery / background

- `WidgetsBindingObserver.didChangeAppLifecycleState` pauses all video controllers when the app is backgrounded and resumes them on foreground.
- `EvePresence` and `EveHero` pause when `AppLifecycleState.paused` and resume on `resumed`.
- `BreathFlower` pauses both the Dart timer and the video; `resume()` restarts the timer from the paused position and seeks the video to match.

## Device signals

`DeviceSignals` is populated by `deviceSignalsOf(context, ref)`:
- `reducedMotion` — `MediaQuery.disableAnimationsOf(context)`
- `lowRam` — `device_info_plus` `androidInfo.totalMemory < 3 GB`; iOS defaults false
- `batterySaver` / `dataSaver` — `com.therapylink/power_info` MethodChannel; defaults false if not registered (add native implementations in `android/app/src/main/…/PowerInfoPlugin.kt`)

## What screen engineers must know

1. **Import only the barrel**: `import 'package:therapylink/ui/presence/presence.dart';`
2. **EvePresence crisis hold**: read `evePresenceCrisisHoldProvider` from Riverpod and set it to `true` when crisis mode activates. Eve will freeze at idle until you release it.
3. **BreathFlower clock is the source of truth** for phase labels, countdown number and phase pills. Do not derive them from the video position.
4. **No audio focus is taken**: all video controllers are muted and `setVolume(0)` is called. This is intentional — the breathing exercise may play alongside ambient sound.
5. **Eve is always clipped to a circle** in the `EvePresence` widget. If you need a non-circular crop (e.g. a rounded rectangle), subclass or extend — do not patch the existing widget.
6. **EveHero lower 40%**: `eve-hero.png` is 1080×1920 and its lower 40% is intentionally empty. Place the welcome-screen copy (title, language picker, CTA) in a `Column` that starts at `0.6 * height` from the top.
