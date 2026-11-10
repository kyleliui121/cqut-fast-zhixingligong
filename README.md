# 知行闪课（zhixing_flash）

重庆理工大学「知行理工」的轻量替代客户端：只做**课表、考试、成绩、空教室、校历、通知**，
数据全部缓存在手机本地，打开即用，不依赖学校 App 的 WebView。

> **当前状态**
> - 界面、本地缓存、刷新逻辑已完成，APK 已编译通过（arm64 版本 17.3 MB）
> - 数据源仍是内置的 `MockSchool`（演示数据），真实教务接口等 HAR 抓包接入，
>   见 [`docs/CRAWLER.md`](docs/CRAWLER.md)

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

`dist/` 下：

| 文件 | 适用 |
| --- | --- |
| `zhixing-flash-0.1.0-arm64.apk` | 绝大多数安卓手机（首选，17.3 MB） |
| `zhixing-flash-0.1.0-arm32.apk` | 老设备（14.9 MB） |
| `zhixing-flash-0.1.0-universal.apk` | 不确定机型时用（50.2 MB） |

安装：传到手机点击安装，或 `adb install dist\zhixing-flash-0.1.0-arm64.apk`。
首次安装需允许「安装未知来源应用」。

> Release 包目前用 debug 签名，能正常安装使用；上架应用商店需要换成正式签名。

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
    api/school_api.dart   数据源接口（换学校只改这里）
    api/mock_school.dart  演示数据源
    ui/                   页面
  test/screens_test.dart  渲染 6 个主页面为 PNG（golden）
dist/                     已编译的 APK
tools/                    下载器、SDK 安装、HAR 分析、图标生成
docs/CRAWLER.md           接口与抓包说明
```

## 构建

需要 Flutter 3.35+（本项目在 3.47.9 / Dart 3.13 下构建）与 Android SDK（compileSdk 36）。

```powershell
cd app
flutter pub get
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
登录 → Cookie 会话 → 抓 HTML/JSON → 解析成模型 → 写本地 JSON → 界面读内存
```

`SchoolApi` 是唯一接口，`MockSchool` / `CqutSchool` 都实现它，
切换数据源只改 `AppState._createApi()` 一行。

## 隐私

- 学号密码存在应用私有目录
  （`/data/data/com.zhixing.zhixing_flash/app_flutter/zhixing_flash/account.json`），
  不经过任何第三方服务器。
- 后续建议换 `flutter_secure_storage`，用 Android Keystore 加密。
