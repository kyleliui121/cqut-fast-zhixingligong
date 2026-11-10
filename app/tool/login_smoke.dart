import 'package:zhixing_flash/api/cqut_school.dart';
import 'package:zhixing_flash/api/school_api.dart';

/// 桌面冒烟测试：验证 RSA 加密 + 登录请求格式。
/// 用法: dart run tool/login_smoke.dart <学号> <密码>
Future<void> main(List<String> args) async {
  if (args.length < 2) {
    print('usage: dart run tool/login_smoke.dart <user> <pass>');
    return;
  }
  final api = CqutSchool();
  final sw = Stopwatch()..start();
  try {
    await api.login(args[0], args[1]);
    print('LOGIN OK in ${sw.elapsedMilliseconds}ms');
  } on SchoolException catch (e) {
    print('SchoolException(needLogin=${e.needLogin}): ${e.message}');
  } catch (e) {
    print('UNEXPECTED ${e.runtimeType}: $e');
  } finally {
    api.dispose();
  }
}
