/// Builds [DeviceSignals] from MediaQuery + device_info_plus.
///
/// RAM detection: on Android we read the system memory class via the MethodChannel
/// (see `com.therapylink/power_info`). `device_info_plus` v11 does not expose RAM
/// directly, so we use our own channel for that too. iOS doesn't expose RAM, so we
/// default to false there.
///
/// Battery saver and data saver are read from the same MethodChannel.
/// If the channel is not registered on the native side both flags stay false
/// (safe conservative choice — worst outcome is playing HD on a battery-saver device).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'presence_rung.dart';

/// MethodChannel for power-related flags. Native-side implementation optional;
/// all flags default to false when the channel is missing.
const _powerChannel = MethodChannel('com.therapylink/power_info');

/// Cached [DeviceSignals] without the MediaQuery.disableAnimations part
/// (which must be read from BuildContext each time).
final _deviceBaseProvider = FutureProvider<_BaseSignals>((ref) async {
  var lowRam = false;
  var batterySaver = false;
  var dataSaver = false;

  if (!Platform.isAndroid) {
    return _BaseSignals(lowRam: lowRam, batterySaver: batterySaver, dataSaver: dataSaver);
  }

  try {
    // Expected keys: batterySaver (bool), dataSaver (bool), totalMemoryMb (int).
    final result = await _powerChannel.invokeMapMethod<String, Object>('getPowerInfo');
    if (result != null) {
      batterySaver = (result['batterySaver'] as bool?) ?? false;
      dataSaver = (result['dataSaver'] as bool?) ?? false;
      final totalMb = (result['totalMemoryMb'] as int?) ?? 0;
      // Flag low-RAM if less than 3 GB.
      if (totalMb > 0) lowRam = totalMb < 3 * 1024;
    }
  } on MissingPluginException {
    // Channel not registered — safe to ignore; defaults stay false.
  } on PlatformException {
    // Permission denied or other platform error — defaults stay false.
  } catch (_) {
    // Any other error — defaults stay false.
  }

  return _BaseSignals(lowRam: lowRam, batterySaver: batterySaver, dataSaver: dataSaver);
});

class _BaseSignals {
  const _BaseSignals({
    required this.lowRam,
    required this.batterySaver,
    required this.dataSaver,
  });

  final bool lowRam;
  final bool batterySaver;
  final bool dataSaver;
}

/// Reads [DeviceSignals] from the current [BuildContext] and the cached base.
/// Call this inside a widget's build method.
///
/// Falls back to safe defaults while the async provider is loading or has errored.
DeviceSignals deviceSignalsOf(BuildContext context, WidgetRef ref) {
  final reducedMotion = MediaQuery.disableAnimationsOf(context);
  final base = ref.watch(_deviceBaseProvider).asData?.value;
  return DeviceSignals(
    reducedMotion: reducedMotion,
    batterySaver: base?.batterySaver ?? false,
    lowRam: base?.lowRam ?? false,
    dataSaver: base?.dataSaver ?? false,
  );
}
