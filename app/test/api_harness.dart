import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// One reply the fake server gives.
typedef Reply = ({int status, Object? body, Map<String, List<String>> headers});

Reply reply(int status, [Object? body, Map<String, List<String>> headers = const {}]) => (status: status, body: body, headers: headers);

/// Stands in for the network: records every request and answers from [handler].
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final Reply Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final r = handler(options);
    return ResponseBody.fromString(
      r.body == null ? '' : jsonEncode(r.body),
      r.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...r.headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A Dio on the fake network, with the same base URL shape as the app's.
Dio fakeDio(Reply Function(RequestOptions options) handler) =>
    Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = FakeAdapter(handler);

FakeAdapter adapterOf(Dio dio) => dio.httpClientAdapter as FakeAdapter;
