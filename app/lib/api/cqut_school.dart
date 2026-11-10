import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

import '../core/nonce.dart';
import '../models.dart';
import '../net/http_session.dart';
import 'school_api.dart';

/// 重庆理工大学「网上办事大厅」(ehall) 数据源。
///
/// 登录链路（全部纯 HTTP，不需要 WebView）：
///   1. GET  CAS 登录页（种 cookie）
///   2. POST /sso/doLogin（密码 RSA 分段加密）
///   3. GET  CAS 登录页 → 302 → authSourceAuth → 302 → ehall?ticket=xxx-oauth
///   4. GET  /normalservice/auth/userInfo/{oauth} → office token
///   5. GET  /ump/officeHall/getApplicationUrl → 应用 ticket
///   6. GET  /normalservice/auth/userInfo/{ticket} → micToken（JWT）
///   7. 课程接口带 micToken
class CqutSchool implements SchoolApi {
  static const String _ehall = 'https://ehall.cqut.edu.cn';
  static const String _cas = 'https://uis.cqut.edu.cn/center-auth-server';
  static const String _casService =
      'https://uis.cqut.edu.cn/ump/common/login/authSourceAuth/auth';
  static const String _appKey = '9b5e431b1a154e20a93357c9c0b732e4';
  static const String _universityId = '100005';
  static const String _appSecret = 'undefined';

  /// RSA 模数（1024 位，来自统一认证登录页的 jsencrypt 公钥）
  static final BigInt _modulus = BigInt.parse(
    'c00b03c3c58c9c74288d79b9596bd2e3bc3cdb899535bdcf60291706fe91a367'
    'f0c9908e079a8504dabfe8e927c1e5acf7b3e1f9243ce638c550eb7843ecb650'
    '191e24de26169c283752941991912d16d5c15ec4078ca549a82884b4afa0b71c'
    'f85a7ae20e37fe7bf0b127b383d377bbb32e4d63f6a456660db6084a673cfa8f',
    radix: 16,
  );
  static final BigInt _exponent = BigInt.from(65537);

  final HttpSession _http = HttpSession();
  final math.Random _random = math.Random.secure();

  String? _officeToken;
  String? _micToken;
  String _operatorId = '0';
  String _schoolYear = '';
  String _term = '1';
  int _currentWeek = 1;
  int _totalWeeks = 20;
  DateTime _termStart = DateTime.now();

  @override
  String get displayName => '网上办事大厅';

  // ---------------------------------------------------------------- 登录

  @override
  Future<void> login(String username, String password) async {
    final loginPage = Uri.parse(
      '$_cas/officeHallApplicationCode/cas/login?service=${Uri.encodeComponent(_casService)}',
    );

    // 1. 种 cookie
    await _http.get(loginPage);

    // 2. 提交账号密码
    final resp = await _http.send(
      'POST',
      Uri.parse('$_cas/sso/doLogin'),
      body: jsonEncode({
        'name': username,
        'pwd': _secretParam(password),
        'verifyCode': '',
        'universityId': _universityId,
      }),
      headers: {
        'Content-Type': 'application/json;charset=UTF-8',
        'Accept': 'application/json',
      },
    );
    final loginBody = _asMap(resp.body);
    // CAS may send success code as a string instead of an integer.
    if (!resp.ok || loginBody?['code']?.toString() != '200') {
      throw SchoolException(
        _responseError('统一认证提交', resp, loginBody),
        needLogin: true,
      );
    }

    // 3. 重新访问登录页，跟随 CAS 跳转拿 oauth 票据
    final landing = await _http.get(loginPage);
    String? oauthTicket;
    // Preserve the ticket from an intermediate redirect if the final landing is WAF-protected.
    for (final target in <Uri>[landing.uri, ...landing.redirectHistory.reversed]) {
      oauthTicket = _oauthTicket(target);
      if (oauthTicket != null && oauthTicket.isNotEmpty) break;
    }
    if (oauthTicket == null || oauthTicket.isEmpty) {
      throw SchoolException(
        '统一认证跳转失败：未找到 ticket（HTTP ${landing.status}，'
        '跳转 ${landing.redirectHistory.length} 次）',
        needLogin: true,
      );
    }

    // 4. 票据换 office token
    final info = await _signedGet(
      '/normalservice/auth/userInfo/${Uri.encodeComponent(oauthTicket)}',
      extra: const {'equipmentName': ''},
    );
    final infoBody = _asMap(info.body);
    final infoContent = infoBody?['content'] as Map<String, dynamic>?;
    final token = infoContent?['token']?.toString();
    if (!info.ok || token == null || token.isEmpty) {
      throw SchoolException(
        _responseError('兑换门户令牌', info, infoBody),
        needLogin: true,
      );
    }
    _officeToken = token;
    _operatorId = infoContent?['staffCode']?.toString() ?? username;

    // 服务端 API 还要求 token 同时以 cookie 形式存在
    _http.cookies.set('_yh_office_token', token);
    _http.cookies.set('_yh_office_ticket', oauthTicket);
    _http.cookies.set('ump_token_pc-officeHall', token);

    // 5-6. 换应用凭据 + micToken
    final appTicket = await _appTicket();
    final appInfo = await _signedGet(
      '/normalservice/auth/userInfo/${Uri.encodeComponent(appTicket)}',
      extra: const {'equipmentName': ''},
    );
    final appBody = _asMap(appInfo.body);
    final content = appBody?['content'] as Map<String, dynamic>?;
    _micToken = content?['token']?.toString();
    _operatorId = content?['staffCode']?.toString() ?? _operatorId;
    if (!appInfo.ok || _micToken == null || _micToken!.isEmpty) {
      throw SchoolException(
        _responseError('兑换课程服务令牌', appInfo, appBody),
        needLogin: true,
      );
    }

    await _loadTerm();
  }

  Future<String> _appTicket() async {
    final uri = Uri.parse('$_ehall/ump/officeHall/getApplicationUrl').replace(
      queryParameters: {
        'applicationCode': 'UIVx60',
        'uap-web-key': 'uap-web-key',
        'timestamp': _ts(),
        'nonce': _nonce(10),
        'clientCategory': 'PC',
        'appVersion': '1.0.0',
      },
    );
    final resp = await _http.get(uri, headers: {'token': _officeToken ?? ''});
    final body = _asMap(resp.body);
    final content = body?['content'] as Map<String, dynamic>?;
    final ticket = content?['ticket']?.toString();
    if (!resp.ok || ticket == null || ticket.isEmpty) {
      throw SchoolException(
        _responseError('获取课程应用票据', resp, body),
        needLogin: true,
      );
    }
    return ticket;
  }

  /// 学年学期 + 当前周 + 开学日期
  Future<void> _loadTerm() async {
    try {
      final years = await _signedGet(
        '/normalservice/course/getCourseYearAndTerm',
        extra: {
          'mybatisSqlId': 'listYearAndTerm',
          'params': jsonEncode({'XGH': _operatorId}),
          'pageNum': '0',
          'pageSize': '0',
        },
      );
      final list = (_asMap(years.body)?['content'] as Map<String, dynamic>?)?['list'];
      if (list is List) {
        for (final item in list) {
          if (item is Map && item['CHECKED']?.toString() == 'true') {
            _schoolYear = item['XN']?.toString() ?? '';
            _term = item['XQ']?.toString() ?? '1';
            break;
          }
        }
      }
    } catch (_) {
      // 用默认学年兜底
    }
    if (_schoolYear.isEmpty) {
      final now = DateTime.now();
      final startYear = now.month >= 8 ? now.year : now.year - 1;
      _schoolYear = '$startYear-${startYear + 1}';
    }

    // The captured school endpoint uses GET for getCurrentWeek.
    final weekResp = await _signedGet(
      '/normalservice/course/getCurrentWeek',
      extra: {
        'schoolYear': _schoolYear,
        'term': _term,
      },
    );
    final weekBody = _asMap(weekResp.body);
    final weekContent = (weekBody?['content'] as Map<String, dynamic>?)?['nowWeek'];
    final parsedWeek = int.tryParse(weekContent?.toString() ?? '');
    if (!weekResp.ok || parsedWeek == null) {
      throw SchoolException(_responseError('查询当前教学周', weekResp, weekBody));
    }
    _currentWeek = math.max(1, parsedWeek);

    final weekCourses = await _signedGet('/normalservice/course/selectCourse', extra: {
      'schoolYear': _schoolYear,
      'term': _term,
      'week': '$_currentWeek',
      'isWeek': 'YES',
      'userType': 'STUDENT',
    });
    final coursesBody = _asMap(weekCourses.body);
    final content = coursesBody?['content'] as Map<String, dynamic>?;
    if (!weekCourses.ok || content == null) {
      throw SchoolException(_responseError('查询教学周课表', weekCourses, coursesBody));
    }
    final startDay = content['startDay']?.toString();
    final maxWeek = int.tryParse(content['maxWeek']?.toString() ?? '');
    _totalWeeks = maxWeek ?? 20;
    final parsedStart = startDay == null ? null : DateTime.tryParse(startDay);
    if (parsedStart != null) {
      _termStart = parsedStart.subtract(Duration(days: (_currentWeek - 1) * 7));
    }
  }

  // ---------------------------------------------------------------- 数据

  @override
  Future<TermInfo> fetchTerm() async {
    return TermInfo(
      name: '$_schoolYear 学年 第 $_term 学期',
      start: _termStart,
      totalWeeks: _totalWeeks,
    );
  }

  @override
  Future<List<Course>> fetchCourses() async {
    final resp = await _signedGet('/normalservice/course/selectCourse', extra: {
      'schoolYear': _schoolYear,
      'term': _term,
      'week': '1',
      'isWeek': 'NO',
      'userType': 'STUDENT',
    });
    final body = _asMap(resp.body);
    if (!resp.ok || body?['code']?.toString() != '40001') {
      throw SchoolException(_responseError('同步课表', resp, body));
    }
    final content = body?['content'] as Map<String, dynamic>?;
    final list = (content?['list'] as List?) ?? const [];
    final courses = <Course>[];
    for (final item in list) {
      if (item is! Map) continue;
      final weekday = int.tryParse(item['weekDay']?.toString() ?? '') ?? 0;
      final start = int.tryParse(item['startTime']?.toString() ?? '') ?? 0;
      final end = int.tryParse(item['endTime']?.toString() ?? '') ?? 0;
      if (weekday < 1 || weekday > 7 || start < 1 || end < start) continue;
      courses.add(Course(
        id: '${item['id']}',
        name: item['courseName']?.toString() ?? '',
        teacher: item['teacherName']?.toString() ?? '',
        location: item['classroomName']?.toString() ?? '',
        weekday: weekday,
        startSection: start,
        endSection: end,
        weeks: parseWeeks(item['week']?.toString() ?? ''),
      ));
    }
    return courses;
  }

  @override
  Future<List<Exam>> fetchExams() async => const <Exam>[];

  @override
  Future<List<Grade>> fetchGrades() async => const <Grade>[];

  @override
  Future<List<Notice>> fetchNotices() async => const <Notice>[];

  @override
  Future<List<RoomSlot>> fetchRooms({
    required DateTime date,
    required int startSection,
    required int endSection,
    String? building,
  }) async =>
      const <RoomSlot>[];

  @override
  List<String> get buildings => const <String>[];

  @override
  void dispose() => _http.close();

  // ---------------------------------------------------------------- 签名

  static String _sign(String path, Map<String, String> params) {
    final keys = params.keys.toList()..sort();
    final buffer = StringBuffer('$path?');
    for (final key in keys) {
      buffer.write('$key=${params[key]}&');
    }
    buffer.write('appSecret=$_appSecret');
    return md5.convert(utf8.encode(buffer.toString())).toString().toUpperCase();
  }

  Future<FetchResult> _signedGet(
    String path, {
    Map<String, String> extra = const {},
    bool signed = true,
  }) async {
    final params = _baseParams(extra);
    if (signed) params['sign'] = _sign(path, params);
    final uri = Uri.parse('$_ehall$path').replace(queryParameters: params);
    return _http.get(uri, headers: _authHeaders());
  }

  Map<String, String> _baseParams(Map<String, String> extra) => {
        'operatorId': _operatorId,
        'universityId': _universityId,
        'appKey': _appKey,
        'timestamp': _ts(),
        'nonce': _nonce(14),
        'clientCategory': 'PC',
        ...extra,
      };

  Map<String, String> _authHeaders() {
    final headers = <String, String>{};
    if (_micToken != null) headers['micToken'] = _micToken!;
    if (_officeToken != null) headers['token'] = _officeToken!;
    return headers;
  }

  // ---------------------------------------------------------------- 加密

  String _secretParam(String password) {
    final chunks = <String>[];
    for (var i = 0; i < password.length; i += 30) {
      final end = math.min(i + 30, password.length);
      chunks.add(base64Encode(_rsa(password.substring(i, end))));
    }
    return Uri.encodeComponent(jsonEncode(chunks));
  }

  Uint8List _rsa(String plain) {
    final key = RSAPublicKey(_modulus, _exponent);
    final cipher = PKCS1Encoding(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(key));
    return cipher.process(Uint8List.fromList(utf8.encode(plain)));
  }

  // ---------------------------------------------------------------- 工具

  static Map<String, dynamic>? _asMap(String text) {
    try {
      final decoded = jsonDecode(text);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Supports ?ticket=..., #/route?ticket=..., and #ticket=...
  static String? _oauthTicket(Uri uri) {
    final direct = uri.queryParameters['ticket'];
    if (direct != null && direct.isNotEmpty) return direct;
    final fragment = uri.fragment;
    if (fragment.isEmpty) return null;
    final pos = fragment.lastIndexOf('?');
    final query = pos >= 0 ? fragment.substring(pos + 1) : fragment;
    try {
      final ticket = Uri.splitQueryString(query)['ticket'];
      return ticket == null || ticket.isEmpty ? null : ticket;
    } on FormatException {
      return null;
    }
  }

  /// Include the failing stage and response code, not credentials or tickets.
  static String _responseError(
    String step,
    FetchResult response,
    Map<String, dynamic>? data,
  ) {
    final raw = (data?['message'] ?? data?['msg'])?.toString().trim();
    final summary = raw == null || raw.isEmpty
        ? '响应缺少预期数据'
        : raw.replaceAll('\n', ' ').replaceAll('\r', ' ');
    final brief = summary.length > 100 ? '${summary.substring(0, 100)}…' : summary;
    final code = data?['code']?.toString();
    final extra = code == null ? '' : '，code=$code';
    return '$step失败：$brief（HTTP ${response.status}$extra）';
  }

  String _ts() => DateTime.now().millisecondsSinceEpoch.toString();

  String _nonce(int digits) => numericNonce(_random, digits);
}
