import 'dart:convert';

// ---------- 宽松类型转换 ----------

int asInt(Object? v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString().trim()) ?? fallback;
}

double? asDouble(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().trim().replaceAll('%', ''));
}

String asString(Object? v, [String fallback = '']) =>
    v == null ? fallback : v.toString().trim();

List<int> asIntList(Object? v) {
  if (v is List) {
    return v.map((e) => asInt(e)).where((e) => e > 0).toList();
  }
  if (v is String) {
    return v
        .split(RegExp(r'[,\s，、]+'))
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toList();
  }
  return const <int>[];
}

/// 把 "1-8周,10-16周" 这类写法展开成周次数组；空字符串视为"每周"。
List<int> parseWeeks(String raw) {
  final text = raw.replaceAll('周', '').trim();
  if (text.isEmpty) return const <int>[];
  final result = <int>{};
  for (final part in text.split(RegExp(r'[,，、;；\s]+'))) {
    if (part.isEmpty) continue;
    final range = part.split(RegExp(r'[-~－—]'));
    if (range.length == 2) {
      final a = int.tryParse(range[0].trim());
      final b = int.tryParse(range[1].trim());
      if (a != null && b != null && a <= b && b - a < 40) {
        for (var i = a; i <= b; i++) {
          result.add(i);
        }
        continue;
      }
    }
    final single = int.tryParse(part.trim());
    if (single != null && single > 0) result.add(single);
  }
  final list = result.where((w) => w > 0).toList()..sort();
  return list;
}

// ---------- 学期 ----------

class TermInfo {
  final String name;
  final DateTime start; // 第 1 周星期一
  final int totalWeeks;

  const TermInfo({
    required this.name,
    required this.start,
    this.totalWeeks = 20,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'start': start.toIso8601String(),
        'totalWeeks': totalWeeks,
      };

  factory TermInfo.fromJson(Map<String, dynamic> j) => TermInfo(
        name: asString(j['name']),
        start: DateTime.tryParse(asString(j['start'])) ?? DateTime.now(),
        totalWeeks: asInt(j['totalWeeks'], 20),
      );
}

// ---------- 课程 ----------

class Course {
  final String id;
  final String name;
  final String teacher;
  final String location;
  final int weekday; // 1 = 周一
  final int startSection; // 从 1 开始
  final int endSection;
  final List<int> weeks; // 空 = 每周
  final String note;

  const Course({
    required this.id,
    required this.name,
    this.teacher = '',
    this.location = '',
    required this.weekday,
    required this.startSection,
    required this.endSection,
    this.weeks = const <int>[],
    this.note = '',
  });

  bool activeIn(int week) => weeks.isEmpty || weeks.contains(week);

  int get sectionCount => endSection - startSection + 1;

  String get sectionLabel =>
      startSection == endSection ? '第$startSection节' : '$startSection-$endSection节';

  /// 课表上显示的周次说明
  String get weeksLabel => weeks.isEmpty ? '每周' : '${weeks.first}-${weeks.last}周';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'teacher': teacher,
        'location': location,
        'weekday': weekday,
        'startSection': startSection,
        'endSection': endSection,
        'weeks': weeks,
        'note': note,
      };

  factory Course.fromJson(Map<String, dynamic> j) => Course(
        id: asString(j['id']),
        name: asString(j['name']),
        teacher: asString(j['teacher']),
        location: asString(j['location']),
        weekday: asInt(j['weekday'], 1),
        startSection: asInt(j['startSection'], 1),
        endSection: asInt(j['endSection'], 1),
        weeks: asIntList(j['weeks']),
        note: asString(j['note']),
      );
}

// ---------- 考试 ----------

class Exam {
  final String id;
  final String name;
  final DateTime start;
  final DateTime? end;
  final String location;
  final String seat;
  final String note;

  const Exam({
    required this.id,
    required this.name,
    required this.start,
    this.end,
    this.location = '',
    this.seat = '',
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'start': start.toIso8601String(),
        'end': end?.toIso8601String(),
        'location': location,
        'seat': seat,
        'note': note,
      };

  factory Exam.fromJson(Map<String, dynamic> j) => Exam(
        id: asString(j['id']),
        name: asString(j['name']),
        start: DateTime.tryParse(asString(j['start'])) ?? DateTime.now(),
        end: DateTime.tryParse(asString(j['end'])),
        location: asString(j['location']),
        seat: asString(j['seat']),
        note: asString(j['note']),
      );
}

// ---------- 成绩 ----------

class Grade {
  final String id;
  final String courseName;
  final double credit;
  final String score;
  final double? scoreValue;
  final double? gpa;
  final String term;
  final String type;
  final String college;
  final bool isNew;

  const Grade({
    required this.id,
    required this.courseName,
    this.credit = 0,
    this.score = '',
    this.scoreValue,
    this.gpa,
    this.term = '',
    this.type = '',
    this.college = '',
    this.isNew = false,
  });

  Grade copyWith({bool? isNew}) => Grade(
        id: id,
        courseName: courseName,
        credit: credit,
        score: score,
        scoreValue: scoreValue,
        gpa: gpa,
        term: term,
        type: type,
        college: college,
        isNew: isNew ?? this.isNew,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'courseName': courseName,
        'credit': credit,
        'score': score,
        'scoreValue': scoreValue,
        'gpa': gpa,
        'term': term,
        'type': type,
        'college': college,
      };

  factory Grade.fromJson(Map<String, dynamic> j) => Grade(
        id: asString(j['id']),
        courseName: asString(j['courseName']),
        credit: asDouble(j['credit']) ?? 0,
        score: asString(j['score']),
        scoreValue: asDouble(j['scoreValue']),
        gpa: asDouble(j['gpa']),
        term: asString(j['term']),
        type: asString(j['type']),
        college: asString(j['college']),
      );
}

// ---------- 通知 ----------

class Notice {
  final String id;
  final String title;
  final DateTime date;
  final String url;
  final String summary;

  const Notice({
    required this.id,
    required this.title,
    required this.date,
    this.url = '',
    this.summary = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'date': date.toIso8601String(),
        'url': url,
        'summary': summary,
      };

  factory Notice.fromJson(Map<String, dynamic> j) => Notice(
        id: asString(j['id']),
        title: asString(j['title']),
        date: DateTime.tryParse(asString(j['date'])) ?? DateTime.now(),
        url: asString(j['url']),
        summary: asString(j['summary']),
      );
}

// ---------- 空教室 ----------

class RoomSlot {
  final String building;
  final String room;
  final int seats;
  final List<int> freeSections;

  const RoomSlot({
    required this.building,
    required this.room,
    this.seats = 0,
    required this.freeSections,
  });

  Map<String, dynamic> toJson() => {
        'building': building,
        'room': room,
        'seats': seats,
        'freeSections': freeSections,
      };

  factory RoomSlot.fromJson(Map<String, dynamic> j) => RoomSlot(
        building: asString(j['building']),
        room: asString(j['room']),
        seats: asInt(j['seats']),
        freeSections: asIntList(j['freeSections']),
      );
}

// ---------- 账号 ----------

class Account {
  final String username;
  final String displayName;
  final String password;

  const Account({
    required this.username,
    this.displayName = '',
    this.password = '',
  });

  // The password field is kept in-memory for old test doubles only.
  // Never write a school password to account.json.
  Map<String, dynamic> toJson() => {
        'username': username,
        'displayName': displayName,
      };

  factory Account.fromJson(Map<String, dynamic> j) => Account(
        username: asString(j['username']),
        displayName: asString(j['displayName']),
      );
}

String encodeJson(Object? value, {bool pretty = false}) =>
    pretty ? const JsonEncoder.withIndent('  ').convert(value) : jsonEncode(value);
