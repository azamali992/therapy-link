/// The IANA zone the server should use to decide where this person's day starts, so a check-in at
/// 1am in Lahore lands on that day and not the one before.
///
/// Dart gives the offset and an abbreviation ("PKT"), not the IANA name, and reading the real name
/// needs a platform plugin the app doesn't carry yet. So: a name that is already IANA is used as
/// is, the zones this app's people live in are named, and any other whole-hour offset maps to its
/// fixed Etc/GMT zone. A fixed zone is right for today but ignores daylight saving, which only
/// matters for points on the far side of a clock change.
String deviceTimeZone([DateTime? now]) {
  final t = now ?? DateTime.now();
  final name = t.timeZoneName;
  if (name.contains('/')) return name;
  return zoneForOffset(t.timeZoneOffset);
}

const _named = {
  300: 'Asia/Karachi',
  330: 'Asia/Kolkata',
  345: 'Asia/Kathmandu',
  270: 'Asia/Kabul',
  210: 'Asia/Tehran',
  240: 'Asia/Dubai',
  180: 'Asia/Riyadh',
};

String zoneForOffset(Duration offset) {
  final minutes = offset.inMinutes;
  final named = _named[minutes];
  if (named != null) return named;
  if (minutes == 0) return 'UTC';
  if (minutes % 60 == 0) {
    final hours = minutes ~/ 60;
    // POSIX sign: Etc/GMT-5 is five hours ahead of UTC.
    if (hours >= -12 && hours <= 14) return 'Etc/GMT${hours > 0 ? '-' : '+'}${hours.abs()}';
  }
  return 'UTC';
}
