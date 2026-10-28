import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/core/network/http_api_client.dart';
import 'package:tokigo/core/network/network_status.dart';

void main() {
  test('a successful response clears the offline status', () async {
    final HttpServer server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final HttpClient httpClient = HttpClient();
    server.listen((HttpRequest request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write('[]');
      await request.response.close();
    });
    addTearDown(() async {
      httpClient.close(force: true);
      await server.close(force: true);
      NetworkStatus.instance.reportOnline();
    });

    NetworkStatus.instance.reportOffline();
    final HttpApiClient client = HttpApiClient(
      client: httpClient,
      baseUrlOverride: 'http://127.0.0.1:${server.port}',
    );
    final result = await client.get<List<dynamic>>('/home/sections');

    expect(result.isSuccess, isTrue);
    expect(NetworkStatus.instance.online, isTrue);
  });
}
