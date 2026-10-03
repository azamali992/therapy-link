import 'dart:math' as math;
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../db/database.dart';
import '../settings/settings.dart';
import 'api_config.dart';
import 'models.dart';
import 'time_zone.dart';

/// The upload for a queued mood row, carrying the row's client id.
MoodPointUpload moodUploadOf(MoodQueueData row) =>
    MoodPointUpload(valence: row.valence, emotion: row.emotion, source: row.source, recordedAt: row.recordedAt, clientId: moodClientId(row.id, row.recordedAt));

/// The server said too many requests (429). [retryAfter] is its Retry-After in seconds, when given.
/// Still a [DioException], so existing handlers keep working.
class RateLimitedException extends DioException {
  RateLimitedException(DioException cause)
    : retryAfter = retryAfterSeconds(cause.response?.headers.value('retry-after')),
      super(requestOptions: cause.requestOptions, response: cause.response, type: cause.type, error: cause.error, stackTrace: cause.stackTrace, message: 'rate limited');

  final int? retryAfter;
}

/// The server, or the part of it asked for, is not available right now (503).
class ServiceUnavailableException extends DioException {
  ServiceUnavailableException(DioException cause)
    : super(
        requestOptions: cause.requestOptions,
        response: cause.response,
        type: cause.type,
        error: cause.error,
        stackTrace: cause.stackTrace,
        message: 'service unavailable',
      );
}

/// Retry-After as whole seconds. The server sends seconds; an HTTP date or junk gives null.
int? retryAfterSeconds(String? header) {
  final n = int.tryParse(header?.trim() ?? '');
  return n == null || n < 0 ? null : n;
}

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(baseUrl: apiBaseUrl, connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 30)));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await ref.read(authRepositoryProvider).idToken();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (err, handler) async {
        if (err.response?.statusCode == 401 && err.requestOptions.extra['retried'] != true) {
          final token = await ref.read(authRepositoryProvider).idToken(forceRefresh: true);
          if (token != null) {
            final opts = err.requestOptions
              ..headers['Authorization'] = 'Bearer $token'
              ..extra['retried'] = true;
            return handler.resolve(await dio.fetch(opts));
          }
        }
        // Busy or down is not a sign-in problem: say which, and leave the session alone.
        handler.next(switch (err.response?.statusCode) {
          429 => RateLimitedException(err),
          503 => ServiceUnavailableException(err),
          _ => err,
        });
      },
    ),
  );
  return dio;
});

class ApiClient {
  /// [timeZone] names the IANA zone sent with day-bucketed requests and [locale] the app language
  /// ('en' or 'ur') sent with assessments; both are read at call time, and tests pin them.
  ApiClient(this._dio, {String Function()? timeZone, String Function()? locale})
    : _timeZone = timeZone ?? deviceTimeZone,
      _locale = locale ?? (() => apiLocale(null));

  final Dio _dio;
  final String Function() _timeZone;
  final String Function() _locale;

  /// The server takes at most this many mood points per request.
  static const moodBatchLimit = 500;

  Future<Me> me() async => Me.fromJson((await _dio.get('/me')).data);

  Future<Me> patchMe({String? displayName, String? locale}) async =>
      Me.fromJson((await _dio.patch('/me', data: {if (displayName != null) 'display_name': displayName, if (locale != null) 'locale': locale})).data);

  /// Deletes the account: every row the server holds for this person and their Firebase sign-in.
  Future<void> deleteMe() => _dio.delete('/me');

  /// Everything the server holds for this account, as the server's own JSON.
  Future<Map<String, dynamic>> exportMe() async => Map<String, dynamic>.from((await _dio.get('/me/export')).data as Map);

  /// Which clinician was shown which parts of my data, and when. Newest first.
  Future<List<AccessLogEntry>> accessLog() async =>
      ((await _dio.get('/me/access-log')).data as List).map((e) => AccessLogEntry.fromJson(e)).toList();

  /// Records which version of the terms and disclaimer the person accepted, and when.
  Future<void> putConsent({required String version, required DateTime acceptedAt}) =>
      _dio.put('/me/consent', data: {'consent_version': version, 'accepted_at': acceptedAt.toUtc().toIso8601String()});

  Future<Me> becomeClinician({required String licenseNo, String? specialty, String? bio}) async =>
      Me.fromJson((await _dio.post('/me/clinician', data: {'license_no': licenseNo, 'specialty': specialty, 'bio': bio})).data);

  /// Sends the app's language with the answers, so a clinician can tell a score from the Roman
  /// Urdu wording, which is not a validated translation, from one in English.
  Future<Assessment> submitAssessment(Instrument instrument, List<int> answers) async => Assessment.fromJson(
    (await _dio.post('/assessments', data: {'instrument': instrument.name, 'answers': answers, 'locale': _locale()})).data,
  );

  Future<List<Assessment>> assessments({Instrument? instrument}) async {
    final r = await _dio.get('/assessments', queryParameters: {if (instrument != null) 'instrument': instrument.name});
    return (r.data as List).map((e) => Assessment.fromJson(e)).toList();
  }

  /// Sends [points] in batches the server accepts and totals its replies. If a later batch fails
  /// the earlier ones are already stored; the caller resends everything, and the client ids let
  /// the server skip what it has.
  Future<MoodUploadResult> uploadMood(List<MoodPointUpload> points) async {
    var accepted = 0, duplicates = 0;
    for (var i = 0; i < points.length; i += moodBatchLimit) {
      final chunk = points.sublist(i, math.min(i + moodBatchLimit, points.length));
      final body = (await _dio.post('/mood/batch', data: [for (final p in chunk) p.toJson()])).data;
      // An older server replied with nothing; count the batch as taken.
      final m = body is Map ? body : const {};
      accepted += (m['accepted'] as num?)?.toInt() ?? chunk.length;
      duplicates += (m['duplicates'] as num?)?.toInt() ?? 0;
    }
    return MoodUploadResult(accepted: accepted, duplicates: duplicates);
  }

  Future<List<MoodDay>> moodTrend({int days = 30}) async {
    final r = await _dio.get('/mood/trend', queryParameters: {'days': days, 'tz': _timeZone()});
    return (r.data as List).map((e) => MoodDay.fromJson(e)).toList();
  }

  Future<List<JournalEntry>> journal() async => ((await _dio.get('/journal')).data as List).map((e) => JournalEntry.fromJson(e)).toList();

  Future<JournalEntry> createJournal({String? title, required String body, int? mood}) async =>
      JournalEntry.fromJson((await _dio.post('/journal', data: {'title': title, 'body': body, 'mood': mood})).data);

  Future<JournalEntry> updateJournal(String id, {String? title, required String body, int? mood}) async =>
      JournalEntry.fromJson((await _dio.put('/journal/$id', data: {'title': title, 'body': body, 'mood': mood})).data);

  Future<void> deleteJournal(String id) => _dio.delete('/journal/$id');

  Future<void> shareSummary({required String kind, required String content, DateTime? start, DateTime? end}) => _dio.post(
    '/summaries',
    data: {'kind': kind, 'content': content, 'period_start': start?.toUtc().toIso8601String(), 'period_end': end?.toUtc().toIso8601String()},
  );

  Future<List<CareLink>> careLinks() async => ((await _dio.get('/care/links')).data as List).map((e) => CareLink.fromJson(e)).toList();

  Future<Me> leaveClinician() async => Me.fromJson((await _dio.delete('/me/clinician')).data);

  /// [code] is the clinician's invite code; the server also accepts a pasted uid here.
  Future<CareLink> inviteClinician(String code) async => CareLink.fromJson((await _dio.post('/care/links', data: {'code': code})).data);

  Future<Me> rotateInviteCode() async => Me.fromJson((await _dio.post('/me/clinician/code')).data);

  Future<CareLink> setConsent(String linkId, Map<String, bool> flags) async =>
      CareLink.fromJson((await _dio.patch('/care/links/$linkId/consent', data: flags)).data);

  Future<CareLink> revokeLink(String linkId) async => CareLink.fromJson((await _dio.delete('/care/links/$linkId')).data);

  Future<List<CaseloadRow>> caseload() async =>
      ((await _dio.get('/clinician/patients')).data as List).map((e) => CaseloadRow.fromJson(e)).toList();

  /// Patients waiting for this clinician to accept their link, oldest first.
  Future<List<LinkRequest>> clinicianRequests() async =>
      ((await _dio.get('/clinician/requests')).data as List).map((e) => LinkRequest.fromJson(e)).toList();

  Future<CareLink> acceptRequest(String linkId) async => CareLink.fromJson((await _dio.post('/clinician/requests/$linkId/accept')).data);

  Future<CareLink> declineRequest(String linkId) async => CareLink.fromJson((await _dio.post('/clinician/requests/$linkId/decline')).data);

  Future<PatientOverview> patientOverview(String uid, {int days = 30}) async =>
      PatientOverview.fromJson((await _dio.get('/clinician/patients/$uid', queryParameters: {'days': days, 'tz': _timeZone()})).data);

  /// Calls POST /inference/chat. Returns the full reply (non-streaming fallback).
  Future<String> cloudChat(List<Map<String, String>> messages, {int maxTokens = 450}) async =>
      (await _dio.post('/inference/chat', data: {'messages': messages, 'max_tokens': maxTokens})).data['reply'] as String;

  /// Calls POST /inference/chat with Accept: text/event-stream and yields SSE chunks.
  /// The server may not support streaming; falls back to [cloudChat] if it does not.
  Stream<String> cloudChatStream(List<Map<String, String>> messages, {int maxTokens = 450}) async* {
    try {
      final response = await _dio.post<ResponseBody>(
        '/inference/chat',
        data: {'messages': messages, 'max_tokens': maxTokens, 'stream': true},
        options: Options(responseType: ResponseType.stream, headers: {'Accept': 'text/event-stream'}),
      );
      final stream = response.data!.stream;
      var buf = '';
      await for (final chunk in stream) {
        buf += String.fromCharCodes(chunk);
        // SSE: lines starting with 'data: '
        while (buf.contains('\n')) {
          final idx = buf.indexOf('\n');
          final line = buf.substring(0, idx).trim();
          buf = buf.substring(idx + 1);
          if (line.startsWith('data: ')) {
            final payload = line.substring(6);
            if (payload == '[DONE]') return;
            yield payload;
          }
        }
      }
    } on DioException {
      // Server does not support streaming; fall back to non-streaming path and trickle the words.
      final text = await cloudChat(messages, maxTokens: maxTokens);
      final words = text.split(' ');
      for (var i = 0; i < words.length; i++) {
        yield i == 0 ? words[i] : ' ${words[i]}';
        if (i % 3 == 2) await Future<void>.delayed(const Duration(milliseconds: 35));
      }
    }
  }
}

/// The language code the server takes for [chosen], the language picked in settings (null means
/// follow the phone). The app speaks only English and Roman Urdu, so anything else is English,
/// just as Flutter resolves it.
String apiLocale(Locale? chosen) {
  final code = (chosen ?? PlatformDispatcher.instance.locale).languageCode;
  return code == 'ur' ? 'ur' : 'en';
}

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(dioProvider), locale: () => apiLocale(ref.read(settingsProvider).locale)),
);
