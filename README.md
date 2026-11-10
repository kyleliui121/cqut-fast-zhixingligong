# 知行闪课（zhixing_flash）

重庆理工大学个人使用的 Flutter 轻量课表客户端。目标是 **学校官方认证、真实课表、缓存秒开、按需刷新**。

## 当前开发状态（0.4.0 试验版）

- 课表数据源已切换为学校的 `timetable-cfc.cqut.edu.cn`（独立于 `ehall` 门户接口）。
- 登录时通过官方 CAS WebView 输入密码；App 只读取课表服务域名的会话 Cookie，密码不会进入 Flutter 表单。
- 首次认证成功后立即显示当前周，后台按最多 3 个并发请求补齐其他周，保留调课与停课的实际周次。
- 课程按本机 JSON 缓存，重新启动直接展示已同步课程；会话信息通过 `flutter_secure_storage` 保存。
- **CQUT Helper 已由用户于 2026-11-10 实机验证正常显示课表，但本仓库的新实现尚未实机验证，且未完成 Flutter 编译验证。**
- 考试、成绩、通知、空教室的真实接口仍未接通；这些页面目前可能为空。

## 主要文件

- `app/lib/ui/portal_login_page.dart`：官方 CAS 登录、读取课表域名 Cookie。
- `app/lib/api/timetable_school.dart`：POST `/api/courseSchedule/listWeekEvents` 获取当前周和完整学期数据。
- `app/lib/api/timetable_parser.dart`：处理日期、节次及调课周次。
- `app/lib/app_state.dart`：缓存与加密会话恢复；网络故障不清除旧课程。
- `app/test/timetable_school_test.dart`：本地模拟服务器的认证与全学期查询测试。
- `app/test/timetable_parser_test.dart`：课程数据解析回归测试。
- `app/lib/api/cqut_school.dart`：旧 ehall 尝试代码，保留参考，但不再是默认数据源。

## 从开发分支构建

```powershell
git fetch origin
git switch feat/timetable-cfc-schedule
git pull origin feat/timetable-cfc-schedule
cd app
flutter pub get
flutter analyze
flutter test test/timetable_parser_test.dart test/timetable_school_test.dart test/account_storage_test.dart
flutter build apk --release --split-per-abi
```

ARM64 APK 输出路径：`app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`。

## 课表数据流

```text
输入学号（只用于确定课表所属账号）
  → 官方 CAS WebView 登录（学校网页填写密码）
  → timetable-cfc 的登录 Cookie
  → POST /api/courseSchedule/listWeekEvents
  → 本周课程立即展示
  → 其他周事件合并、写入本地缓存
  → 下次打开直接读取缓存
```

真实登录尚需 APK 测试。若学校的 CAS 跳转或 Cookie 范围变化，需依据实际错误提示调整；请勿公开账号密码、HAR、Token 或 Cookie。

代码参考： [CQUT Helper](https://github.com/lhgr/CQUT-Helper)（Apache-2.0）及 [cqut-timetable-skill](https://github.com/Lee-Hilex/cqut-timetable-skill)。本项目只参考接口行为与数据结构，未直接复制其实现代码。
