# 接入真实数据：ehall 探查结果

> 结论先行：**页面被瑞数 WAF 保护，但 API 没有**。数据接口只认 token，
> 所以纯 Dart 抓数据是可行的，唯一缺的是「CAS 登录后怎么换到 office token」。

## 一、已经确认的事实（2026-11 实测）

### 1. ehall 页面层：瑞数信息 WAF

```
GET https://ehall.cqut.edu.cn/new_office_hall/   → 202 + JS 挑战
```

- 响应里是 `$_ts`、`nsd`、`cd` 和动态 cookie（`ZXniXLfxkjSbO` 这种随机名），
  典型瑞数五代特征。
- **cookie 复用无效**，必须执行混淆 JS 才能拿到下一阶段凭证。
- 静态资源（`/static/js/*.js`、favicon）**不受保护**，可以直接下载。
- 真实浏览器（Edge headless + 移动 UA）能过，需要 reload 一次：

```
202 → (JS 执行) → reload → 200 → /h5/pages/login/login
       → uis.cqut.edu.cn 统一身份认证
```

### 2. uis 统一认证：**没有 WAF，可以编程访问**

```
GET  https://uis.cqut.edu.cn/...cas/login?service=...
     (Accept: text/html)  → 200，Vue2 登录页
POST https://uis.cqut.edu.cn/<baseUrl>/sso/doLogin
     { "name": "学号", "pwd": "<RSA 分段加密>", "verifyCode": "", "universityId": "?" }
     → {"code":200} 成功
```

密码加密方式（`jsencrypt.js`，1024 位）：

- 公钥 `MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDACwPDxYycdCiNeblZa9LjvDzb...`
- 把密码按 **每 30 字** 切段，逐段 RSA 加密，得到数组
- 数组 `JSON.stringify` → `encodeURIComponent` → 作为 `pwd`/`secretParam`

登录成功码：200 成功；16300 需要二次验证；601 多身份；10029 密码过期。

### 3. ehall API：不需要瑞数，只需要 token

```bash
# 课程微服务：缺 micToken
GET /normalservice/course/getCurrentWeek
→ {"code":"TOKEN_NOT_EXIST","message":"head或query的micToken不存在"}

# 主服务：缺 token
POST /ump/user/front/info
→ {"code":"10032","message":"请求头缺失token参数"}
```

已从 `index.js` / `app.js` 里挖到的接口：

| 用途 | 接口 |
| --- | --- |
| 今日课程 | `/normalservice/course/selectTodayCourse` |
| 整学期课表 | `/normalservice/course/selectCourse` |
| 当前周次 | `/normalservice/course/getCurrentWeek` |
| 通用 SQL 查询 | `/normalservice/normalSql/listdata` |
| 用户信息 | `/normalservice/auth/userInfo/{ticket}` |
| 用户资料 | `/ump/user/front/info` |
| 应用列表 | `/ump/user/front/listPlatformApplication` |
| 应用入口 | `/ump/officeHall/getApplicationUrl` |
| 消息 | `/ump/message/listMessageToRead` 等 |
| 新闻/通知 | `/ump/news/list` |

### 4. token 链（已从源码还原）

```js
// 1. 用 office token 换应用 ticket
GET /ump/officeHall/getApplicationUrl?applicationCode=UIVx60
    header: token: <office token>
    → { content: { ticket } }

// 2. 用 ticket 换微服务 token（micToken）
GET /normalservice/auth/userInfo/{ticket}
    → { content: { token } }   // 这就是 micToken

// 3. 之后所有课程接口
GET /normalservice/course/selectTodayCourse
    header: micToken: <micToken>
```

`micToken` 缓存在前端 state 里，`office token` 存在
`localStorage["<appCode>_token"]`（如 `new_office_hall_token`），
另有 `_yh_office_token` / `_yh_office_ticket` / `_yh_sys_token` 几个 key。

## 二、还缺的一环

CAS 登录成功后，浏览器被重定向回：

```
https://uis.cqut.edu.cn/ump/common/login/authSourceAuth/auth
  → 302 → https://ehall.cqut.edu.cn/h5/pages/login/login?ticket=...
```

这一步要落到 ehall 的 HTML 页面上（被瑞数拦），而页面里再调
`POST /ump/common/login/getLoginTicket`（参数要 `secretParam` 加密）换 token。
**没有真实登录过，无法确定 token 到底在哪一步、以什么字段返回。**

## 三、两条可行路线

### 路线 A：WebView 登录 + 原生取数（推荐）

1. App 内嵌一个 WebView，加载 ehall 登录页，用户正常登录（瑞数在真浏览器里自动过）。
2. 登录后从 WebView 读 `localStorage`，拿到 office token。
3. 之后全部用 Dart 调 API（API 没有瑞数），速度快、可缓存、可离线。

WebView 只在首次登录和 token 过期时出现，日常使用完全是原生界面。

### 路线 B：纯 Dart 登录

自己实现 RSA 分段加密 + `/sso/doLogin` + 跟随 CAS 重定向拿 ticket，
再模拟 `getLoginTicket`。难点是要精确复刻 `secretParam` 的参数集合，
而且每次平台升级都可能失效。

## 四、需要你提供的东西

任选一种，我就能把解析器写完：

1. **登录后的 HAR**（最完整）：Chrome 登录 ehall → F12 → Network →
   勾选 Preserve log → 点开课表/考试/成绩 → Save all as HAR with content。
2. **token 快照**：登录后在 Console 执行
   ```js
   copy(JSON.stringify({ls: {...localStorage}, ss: {...sessionStorage}, ck: document.cookie}))
   ```
   把复制到的内容发我。token 有时效，但足够我摸清接口。
3. **录一次接口**：登录后在 Console 跑
   ```js
   await (await fetch('/normalservice/course/selectCourse', {
     headers: { micToken: '<你的 micToken>' }
   })).text()
   ```

## 五、抓包注意事项

- HAR 里有 Cookie 和 token，别提交到公开仓库（`capture/` 已 gitignore）。
- 只抓自己账号的数据，刷新间隔 ≥ 30 秒。
- 账号密码目前明文存在应用私有目录，后续建议换 `flutter_secure_storage`。

## 六、附：2018 年的老系统（已废弃）

学校早期是正方 ZFsoft（`i.cqut.edu.cn/zfca/login`，GBK 页面，`__VIEWSTATE`），
有三方库 [Happy-Friday/zf-cqut](https://github.com/Happy-Friday/zf-cqut)。
现在公网访问 `i.cqut.edu.cn` 已 ECONNRESET，`jwc.cqut.edu.cn` 也是 202 挑战页，
**不要按老接口实现**。

## 七、探查工具

```powershell
# 抓页面真实渲染结果（过瑞数），输出标题/URL/cookie/截图
node tools/cdp_probe.mjs https://ehall.cqut.edu.cn/new_office_hall/ out.png

# 记录页面加载的所有 JS / XHR 地址
node tools/cdp_net.mjs https://ehall.cqut.edu.cn/new_office_hall/ net.json

# HAR 分析（拿到 HAR 之后）
node tools/analyze_har.mjs capture/xxx.har docs/har-report.md
```
