import '../models.dart';

/// 抓取层抛出的异常，[needLogin] 为 true 时界面会退回登录页。
class SchoolException implements Exception {
  final String message;
  final bool needLogin;

  const SchoolException(this.message, {this.needLogin = false});

  @override
  String toString() => message;
}

/// 所有数据源统一接口。换学校 / 换系统只实现这个接口。
abstract class SchoolApi {
  /// 展示用名称，例如「重理工教务」。
  String get displayName;

  /// 登录，失败抛 [SchoolException]。
  Future<void> login(String username, String password);

  /// 当前学期信息（用于算周次）。
  Future<TermInfo> fetchTerm();

  Future<List<Course>> fetchCourses();

  Future<List<Exam>> fetchExams();

  Future<List<Grade>> fetchGrades();

  Future<List<Notice>> fetchNotices();

  /// 某天某节课区间内的空教室。
  Future<List<RoomSlot>> fetchRooms({
    required DateTime date,
    required int startSection,
    required int endSection,
    String? building,
  });

  /// 空教室查询可选的教学楼。
  List<String> get buildings;

  void dispose();
}
