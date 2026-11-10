import '../models.dart';

/// Converts timetable-cfc weekly occurrences into cached Course records.
class TimetableParser {
  static int? positiveInt(Object? raw) {
    final n = int.tryParse(raw?.toString().trim() ?? '');
    return n != null && n > 0 ? n : null;
  }

  static int currentWeek(Map<String, dynamic> response) =>
      positiveInt(response['weekNum']) ?? 1;

  static String? schoolTerm(Map<String, dynamic> response) {
    final term = response['yearTerm']?.toString().trim();
    return term == null || term.isEmpty ? null : term;
  }

  static TermInfo termInfo(Map<String, dynamic> response, {DateTime? today}) {
    final now = today ?? DateTime.now();
    final week = currentWeek(response);
    DateTime? monday;
    final days = response['weekDayList'];
    if (days is List) {
      for (final item in days) {
        if (item is! Map) continue;
        final date = DateTime.tryParse(item['weekDate']?.toString() ?? '');
        if (date == null) continue;
        monday = DateTime(date.year, date.month, date.day)
            .subtract(Duration(days: date.weekday - 1));
        break;
      }
    }
    monday ??= DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final start = monday.subtract(Duration(days: (week - 1) * 7));
    var total = 20;
    final weeks = response['weekList'];
    if (weeks is List) {
      for (final value in weeks) {
        for (final match in RegExp(r'\d+').allMatches(value.toString())) {
          final n = positiveInt(match.group(0));
          if (n != null && n <= 30 && n > total) total = n;
        }
      }
    }
    if (week > total) total = week;
    return TermInfo(
      name: schoolTerm(response) ?? '当前学期',
      start: start,
      totalWeeks: total,
    );
  }

  static List<Course> parseWeek(Map<String, dynamic> response, int week) {
    final events = response['eventList'];
    if (events is! List) {
      throw const FormatException('课表响应缺少 eventList');
    }
    final result = <Course>[];
    for (final event in events) {
      if (event is! Map) continue;
      final name = event['eventName']?.toString().trim() ?? '';
      final day = positiveInt(event['weekDay']);
      if (name.isEmpty || day == null || day > 7) continue;
      final sectionList = <int>[];
      if (event['sessionList'] is List) {
        for (final raw in event['sessionList'] as List) {
          final n = positiveInt(raw);
          if (n != null) sectionList.add(n);
        }
      }
      sectionList.sort();
      final start = sectionList.isNotEmpty
          ? sectionList.first
          : positiveInt(event['sessionStart']);
      if (start == null || start > 30) continue;
      // "sessionLast" denotes session count, not the ending section.
      final end = sectionList.isNotEmpty
          ? sectionList.last
          : start + (positiveInt(event['sessionLast']) ?? 1) - 1;
      if (end < start || end > 30) continue;
      final teacher = event['memberName']?.toString().trim() ?? '';
      final location = event['address']?.toString().trim() ?? '';
      final id = [event['eventID'] ?? name, day, start, end, location].join('-');
      result.add(Course(
        id: id,
        name: name,
        teacher: teacher,
        location: location,
        weekday: day,
        startSection: start,
        endSection: end,
        weeks: [week],
      ));
    }
    return result;
  }

  static List<Course> mergeWeeks(Iterable<List<Course>> weekly) {
    final map = <String, Course>{};
    for (final list in weekly) {
      for (final course in list) {
        final key = [
          course.name, course.teacher, course.location, course.weekday,
          course.startSection, course.endSection,
        ].join('|');
        final previous = map[key];
        final active = <int>{...?previous?.weeks, ...course.weeks}.toList()
          ..sort();
        map[key] = Course(
          id: previous?.id ?? course.id,
          name: course.name,
          teacher: course.teacher,
          location: course.location,
          weekday: course.weekday,
          startSection: course.startSection,
          endSection: course.endSection,
          weeks: active,
        );
      }
    }
    return map.values.toList()
      ..sort((a, b) {
        final day = a.weekday.compareTo(b.weekday);
        return day != 0 ? day : a.startSection.compareTo(b.startSection);
      });
  }
}
