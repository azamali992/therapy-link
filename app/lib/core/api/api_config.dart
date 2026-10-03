/// Where the TherapyLink API lives. Set per build with `--dart-define-from-file=env/dev.json` or
/// `env/prod.json`; the fallback only suits `flutter run` against a local api/ on the same machine.
const apiBaseUrl = String.fromEnvironment('TL_API_URL', defaultValue: 'http://localhost:8000');

/// Why [url] must not ship in a release build, or null if it is fine. Release builds carry health
/// data, so plain HTTP, a loopback or private address, or the placeholder in env/prod.json all fail.
/// The Android Gradle build applies the same rules before it signs anything.
String? releaseUrlProblem(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) return 'TL_API_URL "$url" is not a URL';
  if (uri.scheme != 'https') return 'TL_API_URL must use https in a release build, got "$url"';
  final host = uri.host.toLowerCase();
  const local = ['localhost', '127.0.0.1', '0.0.0.0', '10.0.2.2', '::1'];
  if (local.contains(host) || host.endsWith('.local') || _privateIp(host)) {
    return 'TL_API_URL points at a local address in a release build: "$url"';
  }
  if (host.endsWith('.example') || host.contains('example.com')) {
    return 'TL_API_URL is still the placeholder in env/prod.json: "$url"';
  }
  return null;
}

bool _privateIp(String host) {
  final parts = host.split('.').map(int.tryParse).toList();
  if (parts.length != 4 || parts.contains(null)) return false;
  final a = parts[0]!, b = parts[1]!;
  return a == 10 || (a == 192 && b == 168) || (a == 172 && b >= 16 && b <= 31);
}
