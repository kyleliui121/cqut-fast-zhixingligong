import 'dart:convert';

import '../models.dart';
import '../net/http_session.dart';
import 'school_api.dart';
import 'timetable_parser.dart';

/// Native client for the school's timetable-cfc service. CAS login happens
/// only on the school website; only the timetable-domain cookies are reused.
class TimetableSchool implements SchoolApi {
  final Uri _endpoint;
  TimetableSchool({Uri? endpoint}) : _endpoint = endpoint ?? Uri.parse(
    'https://timetable-cfc.cqut.edu.cn/api/courseSchedule/listWeekEvents',
  );

  final HttpSession _http = HttpSession();
  String _studentId = '';
  String? _yearTerm;
  Map<String, dynamic>? _initial;
  TermInfo? _term;
  int _currentWeek = 1;

  /// Fast first paint: the authenticated current week is available immediately.
  List<Course> get initialCourses => _initial == null
      ? const <Course>[]
      : TimetableParser.parseWeek(_initial!, _currentWeek);

  @override
  String get displayName => '重庆理工大学课表系统';

  @override
  Future<void> login(String username, String password) async {
    throw const SchoolException('请在学校官方登录页面输入账号密码', needLogin: true);
  }

  Future<void> loginWithCookies(
    String studentId,
    Map<String, String> cookies,
  ) async {
    if (studentId.trim().isEmpty) {
      throw const SchoolException('请先填写学号', needLogin: true);
    }
    if (cookies.isEmpty) {
      throw const SchoolException('没有检测到课表服务登录会话', needLogin: true);
    }
    _studentId = studentId.trim();
    _http.cookies.clear();
    for (final cookie in cookies.entries) {
      if (cookie.key.isNotEmpty && cookie.value.isNotEmpty) {
        _http.cookies.set(cookie.key, cookie.value);
      }
    }
    final response = await _fetchWeek();
    _initial = response;
    _yearTerm = TimetableParser.schoolTerm(response);
    _currentWeek = TimetableParser.currentWeek(response);
    _term = TimetableParser.termInfo(response);
  }

  Future<Map<String, dynamic>> _fetchWeek({int? week}) async {
    final request = <String, dynamic>{'userID': _studentId};
    if (week != null) request['weekNum'] = week.toString();
    if (_yearTerm != null) request['yearTerm'] = _yearTerm;

    final response = await _http.send(
      'POST',
      _endpoint,
      follow: false, // Never forward timetable session cookies to CAS redirects.
      headers: const {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
      },
      body: jsonEncode(request),
    );
    if (response.status == 301 || response.status == 302 ||
        response.status == 303 || response.status == 307 ||
        response.status == 308) {
      throw const SchoolException(
        '课表服务重定向至登录页，请重新登录',
        needLogin: true,
      );
    }
    if (response.status == 401 || response.status == 403) {
      throw const SchoolException(
        '课表登录会话已失效，请重新通过学校网页登录',
        needLogin: true,
      );
    }
    if (!response.ok) {
      throw SchoolException('课表接口 HTTP ${response.status}');
    }
    final parsed = response.tryJson();
    if (parsed is! Map<String, dynamic>) {
      throw const SchoolException('课表服务未返回 JSON 数据，可能需要重新登录');
    }
    if (parsed['eventList'] is! List) {
      // CQUT Helper's response model allows eventList == null on empty weeks.
      // The timetable metadata distinguishes that from a {code,msg} auth error.
      if (parsed.containsKey('yearTerm') || parsed.containsKey('weekDayList')) {
        return {...parsed, 'eventList': <dynamic>[]};
      }
      final code = parsed['code']?.toString();
      throw SchoolException(
        code == null
            ? '未获取到课程事件数组，请确认学校网页登录已完成'
            : '课表认证失败（业务代码：$code），请重新网页登录',
        needLogin: code != null,
      );
    }
    return parsed;
  }

  @override
  Future<TermInfo> fetchTerm() async {
    final term = _term;
    if (term == null) {
      throw const SchoolException('尚未连接课表服务', needLogin: true);
    }
    return term;
  }

  @override
  Future<List<Course>> fetchCourses() async {
    final initial = _initial;
    final term = _term;
    if (initial == null || term == null) {
      throw const SchoolException('尚未连接课表服务', needLogin: true);
    }
    // Read all teaching weeks without guessing recurrence from one week.
    // Cap concurrency to three API calls.
    final total = term.totalWeeks.clamp(1, 24);
    final all = <List<Course>>[];
    for (var first = 1; first <= total; first += 3) {
      final batch = <int>[];
      for (var week = first; week <= total && week < first + 3; week++) {
        batch.add(week);
      }
      final parsedWeeks = await Future.wait(batch.map((week) async {
        final response = week == _currentWeek
            ? initial
            : await _fetchWeek(week: week);
        return TimetableParser.parseWeek(response, week);
      }));
      all.addAll(parsedWeeks);
    }
    return TimetableParser.mergeWeeks(all);
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
  }) async => const <RoomSlot>[];
  @override
  List<String> get buildings => const <String>[];
  @override
  void dispose() => _http.close();
}
