import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zhixing_flash/api/school_api.dart';
import 'package:zhixing_flash/api/timetable_school.dart';

void main() {
  test('native timetable client authenticates and merges full term', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requests = 0;
    server.listen((request) async {
      requests++;
      expect(request.headers.value('cookie'), contains('session=demo'));
      expect(request.method, 'POST');
      expect(request.headers.contentType?.mimeType, 'application/json');
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
      expect(body['userID'], 'student-demo');
      final week = int.tryParse(body['weekNum']?.toString() ?? '') ?? 11;
      final events = (week == 11 || week == 13)
          ? [
              {
                'eventName': '车辆工程',
                'weekDay': '2',
                'sessionStart': '3',
                'sessionLast': '2',
                'address': '教学楼401',
              },
            ]
          : <Map<String, String>>[];
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'weekNum': week.toString(),
        'yearTerm': '2026-2027-1',
        'weekDayList': [
          {'weekDate': '2026-11-09'},
        ],
        'weekList': List.generate(20, (i) => (i + 1).toString()),
        'eventList': events,
      }));
      await request.response.close();
    });

    final school = TimetableSchool(
      endpoint: Uri(
        scheme: 'http',
        host: '127.0.0.1',
        port: server.port,
        path: '/api/courseSchedule/listWeekEvents',
      ),
    );
    try {
      await school.loginWithCookies('student-demo', {'session': 'demo'});
      expect(school.initialCourses, hasLength(1));
      final term = await school.fetchTerm();
      expect(term.totalWeeks, 20);
      expect(term.name, '2026-2027-1');
      expect(term.start, DateTime(2026, 8, 31));
      final courses = await school.fetchCourses();
      expect(courses, hasLength(1));
      expect(courses.single.weeks, [11, 13]);
      expect(courses.single.endSection, 4);
      expect(requests, 20); // 1 initial + remaining 19 weeks
    } finally {
      school.dispose();
      await server.close(force: true);
    }
  });

  test('login redirect is rejected instead of forwarding session cookies',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      await request.drain<void>();
      request.response.statusCode = HttpStatus.found;
      request.response.headers.set(
        HttpHeaders.locationHeader,
        'https://uis.cqut.edu.cn/center-auth-server/',
      );
      await request.response.close();
    });
    final school = TimetableSchool(
      endpoint: Uri(scheme: 'http', host: '127.0.0.1', port: server.port),
    );
    try {
      await expectLater(
        school.loginWithCookies('student-demo', {'session': 'demo'}),
        throwsA(
          isA<SchoolException>()
              .having((exception) => exception.needLogin, 'needLogin', true),
        ),
      );
    } finally {
      school.dispose();
      await server.close(force: true);
    }
  });
}
