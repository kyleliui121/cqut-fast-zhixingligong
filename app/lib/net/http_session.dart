import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 一次 HTTP 请求的结果。
class FetchResult {
  final int status;
  final String body;
  final Uri uri;
  final Map<String, String> headers;
  /// Redirect targets can contain authorization tickets. Never log them.
  final List<Uri> redirectHistory;

  const FetchResult(this.status, this.body, this.uri, this.headers,
      {this.redirectHistory = const []});

  bool get ok => status >= 200 && status < 300;

  String header(String name) => headers[name.toLowerCase()] ?? '';

  String get contentType => header('content-type');

  /// 尝试把响应体当成 JSON 解析。
  Object? tryJson() {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }
}

/// 极简 cookie 罐：只保留 name=value，够应付教务系统的 JSESSIONID / CAS ticket。
class CookieJar {
  final Map<String, String> _items = <String, String>{};

  Map<String, String> get items => Map.unmodifiable(_items);

  bool get isEmpty => _items.isEmpty;

  String get header =>
      _items.entries.map((e) => '${e.key}=${e.value}').join('; ');

  void absorb(String setCookie) {
    final first = setCookie.split(';').first.trim();
    final eq = first.indexOf('=');
    if (eq <= 0) return;
    final name = first.substring(0, eq).trim();
    final value = first.substring(eq + 1).trim();
    if (name.isEmpty) return;
    if (value.isEmpty || value.toLowerCase() == 'null' || value == '""') {
      _items.remove(name);
      return;
    }
    _items[name] = value;
  }

  /// 手动写入 cookie（例如把登录拿到的 token 同步成 cookie）
  void set(String name, String value) {
    if (name.isEmpty || value.isEmpty) return;
    _items[name] = value;
  }

  void clear() => _items.clear();
}

/// 手动处理重定向和 cookie 的 HTTP 会话。
///
/// 用 [HttpClient] 而不是 dio/http，是为了让重定向链路中的 Set-Cookie 都
/// 能被捕获（CAS 登录必须依赖这个），同时少一个第三方依赖。
class HttpSession {
  final HttpClient _client = HttpClient();
  final CookieJar cookies = CookieJar();

  String userAgent;
  Duration timeout;

  HttpSession({
    String? userAgent,
    Duration? timeout,
  })  : userAgent = userAgent ??
            'Mozilla/5.0 (Linux; Android 13; Pixel 6) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
        timeout = timeout ?? const Duration(seconds: 20) {
    _client.connectionTimeout = const Duration(seconds: 15);
    _client.idleTimeout = const Duration(seconds: 5);
  }

  void close() => _client.close(force: true);

  Future<FetchResult> send(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    String? body,
    bool follow = true,
    int maxRedirects = 8,
  }) async {
    var currentUri = uri;
    var currentMethod = method;
    var currentBody = body;
    final redirectHistory = <Uri>[];

    for (var hop = 0; hop <= maxRedirects; hop++) {
      final request = await _client.openUrl(currentMethod, currentUri).timeout(timeout);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.userAgentHeader, userAgent);
      request.headers.set(
        HttpHeaders.acceptHeader,
        'text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8',
      );
      request.headers.set(HttpHeaders.acceptLanguageHeader, 'zh-CN,zh;q=0.9,en;q=0.6');
      if (!cookies.isEmpty) {
        request.headers.set(HttpHeaders.cookieHeader, cookies.header);
      }
      if (headers != null) {
        headers.forEach((key, value) => request.headers.set(key, value));
      }
      if (currentBody != null) {
        final bytes = utf8.encode(currentBody);
        // Respect the caller's JSON Content-Type; use form encoding only by default.
        request.headers.contentType ??=
            ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
        request.contentLength = bytes.length;
        request.add(bytes);
      }

      final response = await request.close().timeout(timeout);

      response.headers.forEach((name, values) {
        if (name.toLowerCase() == HttpHeaders.setCookieHeader) {
          for (final value in values) {
            cookies.absorb(value);
          }
        }
      });

      final status = response.statusCode;
      if (follow && (status == 301 || status == 302 || status == 303 || status == 307 || status == 308)) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        await response.drain<void>();
        if (location == null || location.isEmpty) {
          return FetchResult(status, '', currentUri, const <String, String>{},
              redirectHistory: List<Uri>.unmodifiable(redirectHistory));
        }
        currentUri = currentUri.resolve(location);
        redirectHistory.add(currentUri);
        if (status == 303 || status == 301 || (status == 302 && currentMethod == 'POST')) {
          currentMethod = 'GET';
          currentBody = null;
        }
        continue;
      }

      final bytes = await response.fold<List<int>>(
        <int>[],
        (previous, chunk) => previous..addAll(chunk),
      );
      final charset = response.headers.contentType?.charset ?? 'utf-8';
      final text = _decode(bytes, charset);
      final headerMap = <String, String>{};
      response.headers.forEach((name, values) {
        headerMap[name.toLowerCase()] = values.join(', ');
      });
      return FetchResult(status, text, currentUri, headerMap,
          redirectHistory: List<Uri>.unmodifiable(redirectHistory));
    }

    throw HttpException('重定向次数过多', uri: uri);
  }

  Future<FetchResult> get(
    Uri uri, {
    Map<String, String>? headers,
    bool follow = true,
  }) =>
      send('GET', uri, headers: headers, follow: follow);

  Future<FetchResult> post(
    Uri uri, {
    Map<String, String>? form,
    Map<String, String>? headers,
    bool follow = true,
  }) =>
      send(
        'POST',
        uri,
        headers: headers,
        follow: follow,
        body: form?.entries
            .map((e) =>
                '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
            .join('&'),
      );

  static String _decode(List<int> bytes, String charset) {
    final cs = charset.toLowerCase();
    if (cs.contains('gbk') || cs.contains('gb2312') || cs.contains('gb18030')) {
      // Dart 没有内置 GBK，教务系统若仍用 GBK，需要在此接入映射表。
      // 当前按 UTF-8 宽松解码，至少不会抛异常。
      return utf8.decode(bytes, allowMalformed: true);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }
}
