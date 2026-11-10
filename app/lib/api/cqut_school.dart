import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

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
    final code = loginBody?['code'];
    if (code != 200) {
      final msg = loginBody?['msg']?.toString() ?? '登录失败（$code）';
      throw SchoolException(msg, needLogin: true);
    }

    // 3. 重新访问登录页，跟随 CAS 跳转拿 oauth 票据
    final landing = await _http.get(loginPage);
    final oauthTicket = _oauthTicket(landing.uri);
    if (oauthTicket == null) {
      throw const SchoolException('登录成功，但没有拿到跳转票据', needLogin: true);
    }

    // 4. 票据换 office token
    final info = await _signedGet(
      '/normalservice/auth/userInfo/${Uri.encodeComponent(oauthTicket)}',
      extra: const {'equipmentName': ''},
    );
    final infoBody = _asMap(info.body);
    final infoContent = infoBody?['content'] as Map<String, dynamic>?;
    final token = infoContent?['token']?.toString();
    if (token == null || token.isEmpty) {
      throw SchoolException(
        infoBody?['message']?.toString() ?? '换取登录凭证失败',
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
    if (appTicket != null) {
      final appInfo = await _signedGet(
        '/normalservice/auth/userInfo/${Uri.encodeComponent(appTicket)}',
        extra: const {'equipmentName': ''},
      );
      final content = _asMap(appInfo.body)?['content'] as Map<String, dynamic>?;
      _micToken = content?['token']?.toString();
      _operatorId = content?['staffCode']?.toString() ?? _operatorId;
    }

    if (_micToken == null) {
      throw const SchoolException('没有拿到课程服务凭证', needLogin: true);
    }

    await _loadTerm();
  }

  Future<String?> _appTicket() async {
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
    final content = _asMap(resp.body)?['content'] as Map<String, dynamic>?;
    return content?['ticket']?.toString();
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

    final weekResp = await _signedPost('/normalservice/course/getCurrentWeek', {
      'schoolYear': _schoolYear,
      'term': _term,
    });
    final weekContent =
        (_asMap(weekResp.body)?['content'] as Map<String, dynamic>?)?['nowWeek'];
    _currentWeek = int.tryParse(weekContent?.toString() ?? '') ?? 1;

    final weekCourses = await _signedGet('/normalservice/course/selectCourse', extra: {
      'schoolYear': _schoolYear,
      'term': _term,
      'week': '$_currentWeek',
      'isWeek': 'YES',
      'userType': 'STUDENT',
    });
    final content = _asMap(weekCourses.body)?['content'] as Map<String, dynamic>?;
    final startDay = content?['startDay']?.toString();
    final maxWeek = int.tryParse(content?['maxWeek']?.toString() ?? '');
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
    if (body?['code'] != '40001') {
      throw SchoolException(body?['message']?.toString() ?? '获取课表失败');
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

  Future<FetchResult> _signedPost(String path, Map<String, String> extra) async {
    final params = _baseParams(extra);
    params['sign'] = _sign(path, params);
    final uri = Uri.parse('$_ehall$path').replace(queryParameters: params);
    return _http.send('POST', uri, headers: _authHeaders());
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

  static String? _oauthTicket(Uri uri) {
    final fragment = uri.fragment;
    if (fragment.isEmpty) return null;
    final query = fragment.contains('?') ? fragment.split('?').last : fragment;
    final params = Uri.splitQueryString(query);
    return params['ticket'];
  }

  String _ts() => DateTime.now().millisecondsSinceEpoch.toString();

  String _nonce(int digits) {
    final max = math.pow(10, digits).toInt();
    return (_random.nextInt(max ~/ 10) + max ~/ 10).toString();
  }
}
