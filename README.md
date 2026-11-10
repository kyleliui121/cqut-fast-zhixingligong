# 知行闪课（zhixing_flash）

重庆理工大学「知行理工」的轻量替代客户端：只做**课表、考试、成绩、空教室、校历、通知**，
数据缓存在手机本地，打开即用。**仅首次登录和会话失效时使用 WebView 完成官方认证；课程数据由原生 Dart 网络层获取。**

> **当前状态**
> - 页面与离线缓存已经实现；当前主数据源为 `CqutSchool`，`MockSchool` 仅供测试。
> - 已新增官方 WebView 登录与门户 Token → 应用 Ticket → micToken 连接流程。
> - **该新版尚未经过真实账号登录及 APK 编译验证**；学校 Token 字段和部分接口仍需实机确认。
> - 考试、成绩、通知、空教室的真实数据接口尚未实现，暂时返回空数据。
> - 查看 [`docs/CRAWLER.md`](docs/CRAWLER.md) 了解接口探查结果。

## 已实现

| 页面 | 能力 |
| --- | --- |
| 今日 | 今日课程时间轴、下一节课倒计时、近期考试、新成绩提醒 |
| 课表 | 第 1–20 周切换、7 天网格、当前天高亮、点课程看详情 |
| 考试 | 倒计时排序、考场 / 座位、已结束折叠 |
| 成绩 | 平均绩点 / 学分统计、按学期筛选、新成绩标记 |
| 空教室 | 按日期 + 节次 + 教学楼查询 |
| 校历 | 开学日期、当前周次、每周起止日期 |
| 通知 | 列表 + 详情弹窗 |
| 设置 | 账号、开学日期、立即同步、清缓存、退出登录 |

离线可用：所有数据写本地 JSON，断网也能看；下拉才联网刷新。

## 安装包

本次修改尚未生成 APK。请从最新源码运行构建命令，生成
`app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`，
再使用 `adb install -r` 安装到手机。

> 当前 Release 配置仍使用 debug 签名，仅用于个人测试。

## 目录

```
app/                      Flutter 工程
  lib/
    main.dart             入口 + 主题
    app_state.dart        全局状态、登录、刷新、落盘
    models.dart           课程/考试/成绩/通知/空教室模型
    core/format.dart      周次、节次、时间格式化
    core/store.dart       JSON 本地存储
    net/http_session.dart Cookie 会话（手动处理重定向）
    ui/portal_login_page.dart 学校网页认证、Token 读取、Cookie 交接
    api/school_api.dart   数据源接口（换学校只改这里）
    api/mock_school.dart  演示数据源
    ui/                   页面
  test/screens_test.dart  页面 golden 测试
  test/account_storage_test.dart 账号隐私回归测试
dist/                     已编译的 APK
tools/                    下载器、SDK 安装、HAR 分析、图标生成
docs/CRAWLER.md           接口与抓包说明
```

## 构建

需要 Flutter（建议 3.47+，Dart 3.10+）与 Android SDK（compileSdk 36）。本轮新增的 WebView Cookie API 要求 Dart 3.10+。

```powershell
git pull origin main
cd app
flutter pub get
flutter test test/account_storage_test.dart test/http_session_test.dart test/nonce_test.dart
flutter build apk --release --split-per-abi
```

本项目构建时用到的环境变量（工具链装在 `.toolchain/`，可随时删除）：

```powershell
$env:JAVA_HOME=".toolchain\jdk\jdk-17.0.21+9"
$env:ANDROID_HOME=".toolchain\android-sdk"
$env:PUB_CACHE=".toolchain\pub-cache"
$env:GRADLE_USER_HOME=".toolchain\gradle-home"
$env:FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
```

国内网络下 Gradle 依赖走阿里云镜像，配置在
`.toolchain/gradle-home/init.d/mirrors.gradle`（不进版本库）。

## 数据流

```
官方 WebView 登录 → 读取门户 Token 和 Cookie → 获取应用 Ticket / micToken
    → Dart 请求课程接口 → 解析模型 → 写本地 JSON → UI 读取本地缓存
```

`SchoolApi` 是唯一接口。日常启动时优先读取本地缓存，按需联网同步；
Token 过期后通过「设置 → 重新通过学校网页登录」更新会话。
官方门户登录不再要求用户在 App 自行填写账号密码。

## 隐私

- 学号密码只在校方 WebView 页面输入，App 不读取或存储密码。
- 门户 Token 与相关会话 Cookie 存在 `flutter_secure_storage`（Android Keystore 支持的加密存储）。
- `account.json` 仅保存学号展示信息；发现旧版本明文密码字段时会清除。
- 不要将 HAR、Cookie、Token 或账号密码提交到仓库或分享到聊天中。
