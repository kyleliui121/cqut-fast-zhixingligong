import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api/cqut_school.dart';
import 'api/school_api.dart';
import 'core/format.dart';
import 'core/store.dart';
import 'models.dart';

/// 全局状态：账号、缓存数据、刷新逻辑。
class AppState extends ChangeNotifier {
  static const String _portalSessionKey = 'cqut_portal_session_v1';
  final LocalStore store;
  final SchoolApi Function()? _apiFactory;
  final FlutterSecureStorage _secureStorage;

  AppState(this.store, {
    SchoolApi Function()? apiFactory,
    FlutterSecureStorage secureStorage = const FlutterSecureStorage(),
  })  : _apiFactory = apiFactory,
        _secureStorage = secureStorage;

  Account? account;
  SchoolApi? api;

  bool busy = false;
  bool initializing = true;
  String? error;
  DateTime? lastSync;

  TermInfo? term;
  List<Course> courses = <Course>[];
  List<Exam> exams = <Exam>[];
  List<Grade> grades = <Grade>[];
  List<Notice> notices = <Notice>[];

  Set<String> _seenGrades = <String>{};
  bool _hasSynced = false;
  bool _authenticated = false;

  bool get loggedIn => account != null;

  int get newGradeCount => grades.where((g) => g.isNew).length;

  int get currentWeek {
    final t = term;
    if (t == null) return 1;
    return weekIndex(DateTime.now(), t.start);
  }

  DateTime get termStart => term?.start ?? DateTime(2026, 9, 7);

  List<Course> coursesOf(int week, int weekday) {
    final list = courses
        .where((c) => c.weekday == weekday && c.activeIn(week))
        .toList()
      ..sort((a, b) => a.startSection.compareTo(b.startSection));
    return list;
  }

  List<Course> get todayCourses {
    final now = DateTime.now();
    return coursesOf(currentWeek, now.weekday);
  }

  /// 今天还没结束的最近一节课。
  Course? get nextCourse {
    final now = DateTime.now();
    final list = todayCourses;
    for (final c in list) {
      final section = sectionAt(c.endSection);
      if (section == null) continue;
      final parts = section.end.split(':');
      final end = DateTime(now.year, now.month, now.day,
          int.parse(parts[0]), int.parse(parts[1]));
      if (end.isAfter(now)) return c;
    }
    return null;
  }

  List<Exam> get upcomingExams {
    final now = DateTime.now();
    final list = exams.where((e) => e.start.isAfter(now.subtract(const Duration(hours: 3)))).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return list;
  }

  /// 下次考试剩余天数（向上取整），没有则返回 null。
  int? get daysToNextExam {
    final list = upcomingExams;
    if (list.isEmpty) return null;
    final diff = list.first.start.difference(DateTime.now());
    if (diff.isNegative) return null;
    return (diff.inHours / 24).ceil();
  }

  Future<void> init() async {
    final saved = await store.readMap('account');
    if (saved != null) {
      account = Account.fromJson(saved);
      // Erase passwords stored in account.json by older APK versions.
      if (saved.containsKey('password')) {
        await store.write('account', account!.toJson());
      }
    }
    final termJson = await store.readMap('term');
    if (termJson != null) {
      term = TermInfo.fromJson(termJson);
    }
    final courseJson = await store.readMap('courses');
    if (courseJson != null) {
      courses = (courseJson['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Course.fromJson)
          .toList();
    }
    final examJson = await store.readMap('exams');
    if (examJson != null) {
      exams = (examJson['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Exam.fromJson)
          .toList();
    }
    final gradeJson = await store.readMap('grades');
    if (gradeJson != null) {
      grades = (gradeJson['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Grade.fromJson)
          .toList();
    }
    final noticeJson = await store.readMap('notices');
    if (noticeJson != null) {
      notices = (noticeJson['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Notice.fromJson)
          .toList();
    }
    final meta = await store.readMap('meta');
    if (meta != null) {
      _seenGrades = (meta['seenGrades'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toSet();
      _hasSynced = meta['hasSynced'] == true;
      final synced = meta['lastSync'];
      if (synced is String) lastSync = DateTime.tryParse(synced);
    }
    initializing = false;
    notifyListeners();
  }

  SchoolApi _createApi() => _apiFactory?.call() ?? CqutSchool();

  /// Accept a portal-issued token from the embedded official login page.
  /// Never persist the user's CAS password.
  Future<bool> loginWithPortalToken(
    String token, {
    Map<String, String> cookies = const <String, String>{},
  }) async {
    if (busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    final candidate = CqutSchool();
    try {
      await candidate.loginWithOfficeToken(token, cookies: cookies);
      // Sensitive session data is stored via Android Keystore-backed storage.
      await _secureStorage.write(
        key: _portalSessionKey,
        value: jsonEncode(<String, Object>{
          'token': token,
          'cookies': cookies,
        }),
      );
      api?.dispose();
      api = candidate;
      _authenticated = true;
      account = Account(username: candidate.operatorId);
      await store.write('account', account!.toJson());
      busy = false;
      notifyListeners();
      await refreshAll(silent: true);
      return true;
    } on SchoolException catch (e) {
      candidate.dispose();
      error = e.message;
    } catch (_) {
      candidate.dispose();
      error = '门户会话连接失败，请重新尝试';
    }
    busy = false;
    notifyListeners();
    return false;
  }

  Future<bool> login(String username, String password) async {
    busy = true;
    error = null;
    notifyListeners();
    final candidate = _createApi();
    try {
      await candidate.login(username.trim(), password);
      api?.dispose();
      api = candidate;
      account = Account(username: username.trim());
      _authenticated = true;
      await store.write('account', account!.toJson());
      busy = false;
      notifyListeners();
      await refreshAll(silent: true);
      return true;
    } on SchoolException catch (e) {
      candidate.dispose();
      error = e.message;
      busy = false;
      notifyListeners();
      return false;
    } catch (e) {
      candidate.dispose();
      error = '登录失败：$e';
      busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshAll({bool silent = false}) async {
    var client = api;
    if (client == null && account == null) return;

    // Display cached data immediately; only contact school on manual refresh.
    // Restore an encrypted office session instead of replaying a saved password.
    if (!_authenticated && account != null) {
      final candidate = _createApi();
      try {
        if (candidate is CqutSchool) {
          final encrypted = await _secureStorage.read(key: _portalSessionKey);
          if (encrypted == null || encrypted.isEmpty) {
            throw const SchoolException('需要重新通过学校网页登录', needLogin: true);
          }
          final decoded = jsonDecode(encrypted);
          if (decoded is! Map || decoded['token'] is! String) {
            throw const SchoolException('本地会话无效，请重新登录', needLogin: true);
          }
          final rawCookies = decoded['cookies'];
          final cookies = <String, String>{};
          if (rawCookies is Map) {
            for (final entry in rawCookies.entries) {
              if (entry.key is String && entry.value is String) {
                cookies[entry.key as String] = entry.value as String;
              }
            }
          }
          await candidate.loginWithOfficeToken(
            decoded['token'] as String,
            cookies: cookies,
          );
        } else {
          // MockSchool remains injectable for offline rendering tests.
          await candidate.login(account!.username, account!.password);
        }
        api?.dispose();
        api = candidate;
        client = candidate;
        _authenticated = true;
      } on SchoolException catch (e) {
        candidate.dispose();
        error = e.message;
        busy = false;
        notifyListeners();
        return;
      } catch (_) {
        candidate.dispose();
        error = '连接学校系统失败，请重新网页登录';
        busy = false;
        notifyListeners();
        return;
      }
    }

    if (!silent) {
      busy = true;
      error = null;
      notifyListeners();
    }

    final failures = <String>[];

    Future<void> run(String label, Future<void> Function() action) async {
      try {
        await action();
      } on SchoolException catch (e) {
        failures.add('$label：${e.message}');
        if (e.needLogin) {
          await logout(keepAccount: true);
        }
      } catch (e) {
        failures.add('$label：$e');
      }
    }

    final SchoolApi school = api ?? client!;
    await run('学期', () async {
      term = await school.fetchTerm();
    });
    await run('课表', () async {
      courses = await school.fetchCourses();
    });
    await run('考试', () async {
      exams = await school.fetchExams();
    });
    await run('成绩', () async {
      final fetched = await school.fetchGrades();
      grades = _markNewGrades(fetched);
    });
    await run('通知', () async {
      notices = await school.fetchNotices();
    });

    lastSync = DateTime.now();
    if (failures.isNotEmpty) error = failures.join('\n');
    busy = false;
    await _saveAll();
    notifyListeners();
  }

  List<Grade> _markNewGrades(List<Grade> fetched) {
    final result = <Grade>[];
    for (final g in fetched) {
      final isNew = _hasSynced && !_seenGrades.contains(g.id);
      result.add(g.copyWith(isNew: isNew));
    }
    _seenGrades = fetched.map((g) => g.id).toSet();
    _hasSynced = true;
    return result;
  }

  Future<void> markGradesSeen() async {
    var changed = false;
    final next = <Grade>[];
    for (final g in grades) {
      if (g.isNew) changed = true;
      next.add(g.copyWith(isNew: false));
    }
    if (!changed) return;
    grades = next;
    await _saveAll();
    notifyListeners();
  }

  Future<void> updateTermStart(DateTime start) async {
    final current = term;
    term = TermInfo(
      name: current?.name ?? '当前学期',
      start: startOfDay(start),
      totalWeeks: current?.totalWeeks ?? 20,
    );
    await _saveAll();
    notifyListeners();
  }

  Future<void> logout({bool keepAccount = false}) async {
    api?.dispose();
    api = null;
    _authenticated = false;
    if (!keepAccount) {
      await _secureStorage.delete(key: _portalSessionKey);
      account = null;
      await store.delete('account');
      notifyListeners();
    }
  }

  Future<void> clearCache() async {
    courses = <Course>[];
    exams = <Exam>[];
    grades = <Grade>[];
    notices = <Notice>[];
    term = null;
    lastSync = null;
    _seenGrades = <String>{};
    _hasSynced = false;
    await store.clear();
    if (account != null) {
      await store.write('account', account!.toJson());
    }
    notifyListeners();
  }

  Future<void> _saveAll() async {
    await store.write('term', term?.toJson());
    await store.write('courses', {'items': courses.map((c) => c.toJson()).toList()});
    await store.write('exams', {'items': exams.map((e) => e.toJson()).toList()});
    await store.write('grades', {'items': grades.map((g) => g.toJson()).toList()});
    await store.write('notices', {'items': notices.map((n) => n.toJson()).toList()});
    await store.write('meta', {
      'seenGrades': _seenGrades.toList(),
      'hasSynced': _hasSynced,
      'lastSync': lastSync?.toIso8601String(),
    });
  }

  @override
  void dispose() {
    api?.dispose();
    super.dispose();
  }
}
