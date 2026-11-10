# ehall / 轻应用 API（已实测打通）

> 2026-11-10 用真实账号（刘乾李 / 12504120424）验证通过。
> 所有请求只需要 cookie 里的 `_yh_office_token`，**不需要浏览器、不需要过瑞数**。

## 0. 基础信息

| 项 | 值 |
| --- | --- |
| API 主机 | `https://ehall.cqut.edu.cn`（`app-yh.cqut.edu.cn` 同接口但有瑞数，别用） |
| 轻应用 appKey | `9b5e431b1a154e20a93357c9c0b732e4` |
| universityId | `100005` |
| 课程应用 code | `UIVx60` |
| 签名密钥 | `undefined`（学校没配 appSecret，字面量 undefined） |

## 1. 签名算法

前端 `pcapp.js` 的拦截器：

```js
sign = MD5(path + "?" + 按 key 升序拼接的 k=v& + "appSecret=undefined").toUpperCase()
```

注意：
- `path` 是接口路径（不含域名），如 `/normalservice/course/selectCourse`
- 每个参数后面都带 `&`，包括最后一个
- 对象值用 `JSON.stringify`
- 结果转大写

Node 实现：

```js
function sign(path, params) {
  let s = path + '?';
  for (const k of Object.keys(params).sort()) {
    const v = params[k];
    s += k + '=' + (v !== null && typeof v === 'object' ? JSON.stringify(v) : v) + '&';
  }
  return md5(s + 'appSecret=undefined').toUpperCase();
}
```

## 2. 公共参数

每个 `/normalservice/*` 请求都要带：

```
operatorId=学号        // 登录后才知道
universityId=100005
appKey=9b5e431b1a154e20a93357c9c0b732e4
timestamp=毫秒
nonce=随机数
clientCategory=PC
sign=上面算的
```

请求头：`micToken: <token>`（课程类接口必需）。

## 3. token 链

```bash
# ① office token（cookie 里）换应用 ticket
GET /ump/officeHall/getApplicationUrl?applicationCode=UIVx60
    额外 query: uap-web-key=uap-web-key&timestamp=&nonce=&clientCategory=PC&appVersion=1.0.0
    header: token: <_yh_office_token>
    → { content: { ticket, redirectUrl } }

# ② ticket 换 micToken + 用户信息
GET /normalservice/auth/userInfo/{ticket}?<公共参数>
    → { content: { operatorId, staffCode, userName, userType, token } }
      token 就是 micToken（JWT，有效期约 3 个月）
```

## 4. 已打通的接口

### 4.1 当前周

```
POST /normalservice/course/getCurrentWeek
body: schoolYear=2026-2027&term=1
→ { content: { nowWeek: 11 } }
```

### 4.2 整学期课表

```
GET /normalservice/course/selectCourse
query: schoolYear=2026-2027&term=1&week=1&isWeek=NO&userType=STUDENT
→ { content: { maxWeek: "21", startDay, endDay, list: [...] } }
```

`isWeek=NO` 时返回整个学期（32 条）；`isWeek=YES&week=11` 只返回该周。
`week` 即使 `isWeek=NO` 也必须给值（随便给 1）。

单条课程：

```json
{
  "id": "6362",
  "courseName": "人工智能概论",
  "week": "11,12,14",
  "teacherName": "彭科",
  "classroomName": "4教0313",
  "weekDay": "2",
  "startTime": "1",
  "endTime": "2",
  "isCustom": "NO"
}
```

### 4.3 今日课程

```
POST /normalservice/course/selectTodayCourse
body: {}
→ { content: { currentWeek: "11", currentDay: "2", list: [...] } }
```

### 4.4 学年学期列表

```
GET /normalservice/normalSql/listdata
query: pageNum=1&pageSize=50&mybatisSqlId=listYearAndTerm
       &params={"XH":"12504120424"}       // 注意 params 是 JSON 字符串
→ { content: { list: [{ XN: "2026-2027", XQ: "1", CHECKED: "true" }] } }
```

### 4.5 成绩（接口正常，但这个账号查不到数据）

```
GET /normalservice/normalSql/listdata
query: mybatisSqlId=listScoreByXnxq
       &params={"XH":"12504120424","XNXQ":"2026-2027-1"}
→ { code: "40001", content: { total: 0, list: [] } }
```

结论（2026-11-10 实测）：

- 接口本身没问题，`40001` 且返回空列表。
- 用浏览器里页面自己的组件切到 `2025-2026-1` 再查，同样返回 `total: 0`，
  说明**不是参数问题，是这个账号在轻应用数据源里没有成绩记录**。
- 默认选中的是 `2026-2027-2`（学年列表第一条），本来就还没修课，所以默认是空的。

成绩应该在**教务系统**（不是 ehall 轻应用）里，需要另找入口。

## 5. 还没找到的

| 功能 | 状态 |
| --- | --- |
| 成绩 | SQL 报 10001，待换入口 |
| 考试安排 | 未找到对应轻应用/接口 |
| 空教室 | 未找到 |
| 通知公告 | ehall 有 `/ump/news/list`，未验证 |
| 自动登录 | CAS → office token 这一步未验证 |

## 6. 复现脚本

```powershell
# 需要 capture/ehall-token.json（浏览器里导出的 cookie 快照）
node tools/ehall_api.mjs capture/ehall-token.json
# 产物在 capture/responses/
```

## 7. 安全

- `capture/` 里有 cookie 和 token，已 gitignore，别提交。
- micToken 是 JWT，有效期到 2027-02，泄露等于账号被接管。
- 抓取频率控制在 30 秒以上。
