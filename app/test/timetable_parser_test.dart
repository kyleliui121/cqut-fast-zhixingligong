import 'package:flutter_test/flutter_test.dart';
import 'package:zhixing_flash/api/timetable_parser.dart';

void main() {
  test('parses week 11 and treats sessionLast as duration', () {
    final response = <String, dynamic>{
      'yearTerm': '2026-2027-1',
      'weekNum': '11',
      'weekDayList': [
        {'weekDate': '2026-11-09'},
      ],
      'eventList': [
        {
          'eventName': '工程数学',
          'memberName': '教师',
          'address': '教学楼402',
          'weekDay': '2',
          'sessionStart': '3',
          'sessionLast': '2',
        },
      ],
    };
    final term = TimetableParser.termInfo(
      response,
      today: DateTime(2026, 11, 10),
    );
    expect(term.start, DateTime(2026, 8, 31));
    final parsed = TimetableParser.parseWeek(response, 11);
    expect(parsed, hasLength(1));
    expect(parsed.single.startSection, 3);
    expect(parsed.single.endSection, 4);
    expect(parsed.single.weeks, [11]);
  });

  test('merges only weeks in which an event actually occurs', () {
    final event = {
      'eventName': '概率论',
      'weekDay': '4',
      'sessionList': ['5', '6'],
    };
    final one = TimetableParser.parseWeek({'eventList': [event]}, 11);
    final two = TimetableParser.parseWeek({'eventList': [event]}, 13);
    final merged = TimetableParser.mergeWeeks([one, two]);
    expect(merged, hasLength(1));
    expect(merged.single.endSection, 6);
    expect(merged.single.weeks, [11, 13]);
    expect(merged.single.activeIn(12), isFalse);
  });

  test('rejects an auth error rather than clearing all cached classes', () {
    expect(
      () => TimetableParser.parseWeek({'code': 401}, 11),
      throwsFormatException,
    );
  });
}
