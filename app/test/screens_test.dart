import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhixing_flash/app_state.dart';
import 'package:zhixing_flash/api/mock_school.dart';
import 'package:zhixing_flash/core/store.dart';
import 'package:zhixing_flash/main.dart';

Future<void> _loadFont(String family, String path) async {
  final file = File(path);
  if (!file.existsSync()) {
    // ignore: avoid_print
    print('font not found: $path');
    return;
  }
  final bytes = file.readAsBytesSync();
  final loader = FontLoader(family)
    ..addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

void main() {
  setUpAll(() async {
    // 测试环境的默认字体没有中文字形，这里把系统中文字体注册成 Roboto，
    // 让 Material 默认排版用上它，截图才不是方块。
    await _loadFont('Roboto', r'C:\Windows\Fonts\simhei.ttf');
    await _loadFont('SimHei', r'C:\Windows\Fonts\simhei.ttf');
    await _loadFont(
      'MaterialIcons',
      r'D:\work\zhixingligongflash\.toolchain\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
    );
  });

  testWidgets('capture main screens', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final dir = Directory.systemTemp.createTempSync('zxf_test');
    final store = LocalStore.at(dir);
    final state = AppState(store, apiFactory: MockSchool.new);

    await tester.runAsync(() async {
      await state.init();
    });

    await tester.pumpWidget(ZhixingApp(state: state));
    await tester.pumpAndSettle();

    // The login entry has switched to the official WebView flow.
    // Keep this assertion independent of the previous password-form screenshot.
    expect(find.text('前往学校官方登录'), findsOneWidget);
    // ignore: avoid_print
    print('captured login');

    await tester.runAsync(() async {
      final ok = await state.login('2026001', '123456');
      expect(ok, isTrue);
    });
    // 固定同步时间，否则「更多」页的时间戳每次都会让 golden 失败
    state.lastSync = DateTime(2026, 11, 10, 20, 0);
    await tester.pumpAndSettle();
    // ignore: avoid_print
    print('logged in');

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/02_today.png'),
    );
    // ignore: avoid_print
    print('captured today');

    for (final entry in <String, String>{
      '课表': '03_timetable',
      '考试': '04_exam',
      '成绩': '05_grade',
      '更多': '06_more',
    }.entries) {
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/${entry.value}.png'),
      );
      // ignore: avoid_print
      print('captured ${entry.value}');
    }
  });
}
