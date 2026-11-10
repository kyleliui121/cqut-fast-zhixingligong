import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zhixing_flash/net/http_session.dart';

void main() {
  test('POST keeps an explicit application/json Content-Type', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final session = HttpSession();
    try {
      final capture = server.first.then((request) async {
        final type = request.headers.contentType?.mimeType;
        final body = await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.write('{"code":200}');
        await request.response.close();
        return (type, body);
      });

      final result = await session.send(
        'POST',
        Uri(
          scheme: 'http',
          host: '127.0.0.1',
          port: server.port,
          path: '/sso/doLogin',
        ),
        headers: {'Content-Type': 'application/json;charset=UTF-8'},
        body: '{"name":"student"}',
      );
      final received = await capture;

      expect(result.status, HttpStatus.ok);
      expect(received.$1, 'application/json');
      expect(received.$2, '{"name":"student"}');
    } finally {
      session.close();
      await server.close(force: true);
    }
  });

  test('retains a ticket-bearing intermediate redirect URL', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final session = HttpSession();
    server.listen((request) async {
      if (request.uri.path == '/start') {
        request.response.statusCode = HttpStatus.found;
        request.response.headers.set(
          HttpHeaders.locationHeader,
          '/h5/pages/login/login?ticket=example-oauth',
        );
      } else {
        request.response.statusCode = HttpStatus.ok;
        request.response.write('landing');
      }
      await request.response.close();
    });

    try {
      final result = await session.get(
        Uri(scheme: 'http', host: '127.0.0.1', port: server.port, path: '/start'),
      );
      expect(result.status, HttpStatus.ok);
      expect(result.redirectHistory, hasLength(1));
      expect(
        result.redirectHistory.single.queryParameters['ticket'],
        'example-oauth',
      );
    } finally {
      session.close();
      await server.close(force: true);
    }
  });
}
