import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 极简本地存储：每个模块一个 JSON 文件，放在应用私有目录。
/// 不引数据库，读写都是整文件，数据量在几百条以内完全够用。
class LocalStore {
  final Directory dir;

  LocalStore._(this.dir);

  /// 测试或指定目录时使用。
  factory LocalStore.at(Directory dir) => LocalStore._(dir);

  static Future<LocalStore> open() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/zhixing_flash');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return LocalStore._(dir);
  }

  File _file(String name) => File('${dir.path}/$name.json');

  Future<Map<String, dynamic>?> readMap(String name) async {
    try {
      final file = _file(name);
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<List<dynamic>> readList(String name) async {
    try {
      final file = _file(name);
      if (!await file.exists()) return const <dynamic>[];
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return const <dynamic>[];
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded : const <dynamic>[];
    } catch (_) {
      return const <dynamic>[];
    }
  }

  Future<void> write(String name, Object? value) async {
    final file = _file(name);
    await file.writeAsString(jsonEncode(value), flush: true);
  }

  Future<void> delete(String name) async {
    final file = _file(name);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> clear() async {
    if (await dir.exists()) {
      await for (final entity in dir.list()) {
        if (entity is File) {
          try {
            await entity.delete();
          } catch (_) {
            // 忽略单个文件删除失败
          }
        }
      }
    }
  }
}
