import 'dart:math';

import '../models.dart';
import 'school_api.dart';

/// 演示用数据源：不联网也能把整套界面跑起来。
///
/// 拿到真实接口后，把 [AppState] 里的 `createApi` 换成 CqutSchool 即可。
class MockSchool implements SchoolApi {
  final Random _random = Random(42);

  @override
  String get displayName => '演示数据';

  @override
  Future<void> login(String username, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (username.trim().isEmpty || password.trim().isEmpty) {
      throw const SchoolException('学号或密码不能为空', needLogin: true);
    }
    if (password == 'wrong') {
      throw const SchoolException('学号或密码错误', needLogin: true);
    }
  }

  static final DateTime _termStart = DateTime(2026, 9, 7);

  @override
  Future<TermInfo> fetchTerm() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return TermInfo(name: '2026-2027 学年 第 1 学期', start: _termStart, totalWeeks: 20);
  }

  @override
  Future<List<Course>> fetchCourses() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    const full = <int>[];
    final weeks = List<int>.generate(16, (i) => i + 1);
    final halfWeeks = List<int>.generate(14, (i) => i + 3);

    return [
      Course(
        id: 'c1',
        name: '数据结构',
        teacher: '李伟',
        location: '博学楼 A301',
        weekday: 1,
        startSection: 1,
        endSection: 2,
        weeks: weeks,
      ),
      Course(
        id: 'c2',
        name: '大学英语（三）',
        teacher: 'Sarah Chen',
        location: '明理楼 B204',
        weekday: 1,
        startSection: 3,
        endSection: 4,
        weeks: weeks,
      ),
      Course(
        id: 'c3',
        name: '线性代数',
        teacher: '王红',
        location: '博学楼 A105',
        weekday: 2,
        startSection: 1,
        endSection: 2,
        weeks: weeks,
      ),
      Course(
        id: 'c4',
        name: '操作系统',
        teacher: '张建国',
        location: '知行楼 C402',
        weekday: 2,
        startSection: 5,
        endSection: 6,
        weeks: weeks,
      ),
      Course(
        id: 'c5',
        name: '计算机网络',
        teacher: '陈曦',
        location: '知行楼 C305',
        weekday: 3,
        startSection: 3,
        endSection: 4,
        weeks: weeks,
      ),
      Course(
        id: 'c6',
        name: '数据结构实验',
        teacher: '李伟',
        location: '实验楼 D201',
        weekday: 3,
        startSection: 7,
        endSection: 8,
        weeks: halfWeeks,
      ),
      Course(
        id: 'c7',
        name: '体育（三）',
        teacher: '刘强',
        location: '南区田径场',
        weekday: 4,
        startSection: 3,
        endSection: 4,
        weeks: weeks,
      ),
      Course(
        id: 'c8',
        name: '马克思主义基本原理',
        teacher: '赵敏',
        location: '明理楼 B501',
        weekday: 4,
        startSection: 5,
        endSection: 6,
        weeks: weeks,
      ),
      Course(
        id: 'c9',
        name: '软件工程',
        teacher: '周涛',
        location: '知行楼 C210',
        weekday: 5,
        startSection: 1,
        endSection: 2,
        weeks: weeks,
      ),
      Course(
        id: 'c10',
        name: '编译原理',
        teacher: '孙丽',
        location: '博学楼 A208',
        weekday: 5,
        startSection: 5,
        endSection: 6,
        weeks: weeks,
      ),
      Course(
        id: 'c11',
        name: '人工智能导论（通识）',
        teacher: '何远',
        location: '明理楼 B108',
        weekday: 5,
        startSection: 9,
        endSection: 10,
        weeks: full.isEmpty ? weeks : weeks,
      ),
    ];
  }

  @override
  Future<List<Exam>> fetchExams() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return [
      Exam(
        id: 'e1',
        name: '数据结构',
        start: DateTime(2026, 11, 20, 9, 0),
        end: DateTime(2026, 11, 20, 11, 0),
        location: '博学楼 A301',
        seat: '25',
      ),
      Exam(
        id: 'e2',
        name: '大学英语（三）',
        start: DateTime(2026, 11, 24, 14, 30),
        end: DateTime(2026, 11, 24, 16, 30),
        location: '明理楼 B204',
        seat: '12',
      ),
      Exam(
        id: 'e3',
        name: '线性代数',
        start: DateTime(2026, 11, 27, 9, 0),
        end: DateTime(2026, 11, 27, 11, 0),
        location: '博学楼 A105',
        seat: '08',
      ),
      Exam(
        id: 'e4',
        name: '操作系统',
        start: DateTime(2026, 12, 2, 14, 30),
        end: DateTime(2026, 12, 2, 16, 30),
        location: '知行楼 C402',
        seat: '31',
      ),
    ];
  }

  @override
  Future<List<Grade>> fetchGrades() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return const [
      Grade(
        id: 'g1',
        courseName: '数据结构',
        credit: 4,
        score: '92',
        scoreValue: 92,
        gpa: 4.2,
        term: '2026-2027-1',
        type: '必修',
        college: '计算机科学与工程学院',
      ),
      Grade(
        id: 'g2',
        courseName: '大学英语（三）',
        credit: 3,
        score: '86',
        scoreValue: 86,
        gpa: 3.6,
        term: '2026-2027-1',
        type: '必修',
        college: '外国语学院',
      ),
      Grade(
        id: 'g3',
        courseName: '线性代数',
        credit: 3,
        score: '78',
        scoreValue: 78,
        gpa: 2.8,
        term: '2026-2027-1',
        type: '必修',
        college: '理学院',
      ),
      Grade(
        id: 'g4',
        courseName: '大学物理（二）',
        credit: 3.5,
        score: '88',
        scoreValue: 88,
        gpa: 3.8,
        term: '2025-2026-2',
        type: '必修',
        college: '理学院',
      ),
      Grade(
        id: 'g5',
        courseName: '程序设计基础课程设计',
        credit: 2,
        score: '优秀',
        gpa: 4.5,
        term: '2025-2026-2',
        type: '集中实践',
        college: '计算机科学与工程学院',
      ),
      Grade(
        id: 'g6',
        courseName: '体育（二）',
        credit: 1,
        score: '良好',
        gpa: 3.5,
        term: '2025-2026-2',
        type: '必修',
        college: '体育部',
      ),
    ];
  }

  @override
  Future<List<Notice>> fetchNotices() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return [
      Notice(
        id: 'n1',
        title: '关于 2026-2027 学年第一学期期末考试安排的通知',
        date: DateTime(2026, 11, 8),
        summary: '期末考试将于第 15-16 周进行，请同学们及时查询考试安排，携带学生证参加考试。',
      ),
      Notice(
        id: 'n2',
        title: '2026 年下半年全国大学英语四六级考试报名通知',
        date: DateTime(2026, 11, 5),
        summary: '报名时间 11 月 5 日 - 11 月 12 日，请登录教务系统完成缴费。',
      ),
      Notice(
        id: 'n3',
        title: '关于开展本学期学生评教工作的通知',
        date: DateTime(2026, 11, 1),
        summary: '评教系统开放至 11 月 30 日，未完成评教将影响成绩查询。',
      ),
      Notice(
        id: 'n4',
        title: '图书馆自习室开放时间调整',
        date: DateTime(2026, 10, 28),
        summary: '自 11 月 1 日起，图书馆自习室开放时间延长至 23:00。',
      ),
    ];
  }

  @override
  Future<List<RoomSlot>> fetchRooms({
    required DateTime date,
    required int startSection,
    required int endSection,
    String? building,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final buildings = building == null || building.isEmpty
        ? <String>['博学楼', '明理楼', '知行楼']
        : <String>[building];
    final result = <RoomSlot>[];
    for (final b in buildings) {
      final floors = b == '博学楼' ? 4 : 3;
      for (var floor = 1; floor <= floors; floor++) {
        for (var n = 1; n <= 6; n++) {
          if (_random.nextInt(10) < 4) continue;
          final start = startSection;
          final end = min(endSection, startSection + _random.nextInt(3) + 1);
          result.add(RoomSlot(
            building: b,
            room: '$b A$floor${n.toString().padLeft(2, '0')}',
            seats: 40 + _random.nextInt(60),
            freeSections: List<int>.generate(end - start + 1, (i) => start + i),
          ));
        }
      }
    }
    result.sort((a, b) => a.room.compareTo(b.room));
    return result;
  }

  @override
  List<String> get buildings => const ['博学楼', '明理楼', '知行楼', '实验楼'];

  @override
  void dispose() {}
}
