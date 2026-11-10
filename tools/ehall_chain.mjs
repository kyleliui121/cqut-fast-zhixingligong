// 用浏览器导出的 cookie 快照，跑通 ehall token 链并抓真实数据。
// 用法: node tools/ehall_chain.mjs capture/ehall-token.json
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';

const cfgPath = process.argv[2] ?? 'capture/ehall-token.json';
const cfg = JSON.parse(readFileSync(cfgPath, 'utf8'));
const base = 'https://ehall.cqut.edu.cn';
const UA =
  'Mozilla/5.0 (Linux; Android 13; Pixel 6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36';

mkdirSync('capture/responses', { recursive: true });

const ck = new Map();
for (const part of String(cfg.ck ?? '').split(';')) {
  const s = part.trim();
  const i = s.indexOf('=');
  if (i > 0) ck.set(s.slice(0, i), s.slice(i + 1));
}
const cookieHeader = [...ck].map(([k, v]) => `${k}=${v}`).join('; ');
const token = ck.get('_yh_office_token');
if (!token) {
  console.error('快照里没有 _yh_office_token cookie');
  process.exit(1);
}
console.log('office token:', token);

const nonce = () => Math.random().toString(36).slice(2, 10);

function commonParams() {
  return new URLSearchParams({
    'uap-web-key': 'uap-web-key',
    timestamp: String(Date.now()),
    nonce: nonce(),
    clientCategory: 'PC',
    appVersion: '1.0.0',
  });
}

async function call(method, path, { micToken, body, withParams = true } = {}) {
  const url = new URL(base + path);
  if (withParams) {
    for (const [k, v] of commonParams()) url.searchParams.set(k, v);
  }
  const headers = {
    'User-Agent': UA,
    Accept: 'application/json, text/plain, */*',
    Referer: 'https://ehall.cqut.edu.cn/new_office_hall/',
  };
  if (cookieHeader) headers.Cookie = cookieHeader;
  if (token) headers.token = token;
  if (micToken) headers.micToken = micToken;
  const opts = { method, headers, signal: AbortSignal.timeout(20000) };
  if (body !== undefined) {
    opts.body = typeof body === 'string' ? body : JSON.stringify(body);
    headers['Content-Type'] = 'application/json';
  }
  const r = await fetch(url, opts);
  const text = await r.text();
  let json = null;
  try { json = JSON.parse(text); } catch {}
  console.log(`${method} ${path} -> ${r.status} ${text.slice(0, 200)}`);
  return { status: r.status, text, json };
}

const save = (name, v) => writeFileSync(`capture/responses/${name}.json`, JSON.stringify(v, null, 2));

(async () => {
  // 1. 用户信息
  const info = await call('POST', '/ump/user/front/info', { body: '' });
  save('user-info', info.json);

  // 2. office token -> 应用 ticket
  const app = await call('GET', '/ump/officeHall/getApplicationUrl?applicationCode=UIVx60');
  save('app-url', app.json);
  const ticket = app.json?.content?.ticket;
  if (!ticket) {
    console.log('没拿到 ticket，结束');
    return;
  }
  console.log('ticket:', String(ticket).slice(0, 48));

  // 3. ticket -> micToken
  const auth = await call('GET', `/normalservice/auth/userInfo/${encodeURIComponent(ticket)}`, {
    withParams: false,
  });
  save('auth-userinfo', auth.json);
  const micToken = auth.json?.content?.token;
  if (!micToken) {
    console.log('没拿到 micToken，结束');
    return;
  }
  console.log('micToken:', micToken);

  // 4. 课程接口
  const week = await call('GET', '/normalservice/course/getCurrentWeek', { micToken, withParams: false });
  save('current-week', week.json);

  const today = await call('POST', '/normalservice/course/selectTodayCourse', {
    micToken,
    withParams: false,
    body: {},
  });
  save('today-course', today.json);

  const courses = await call('POST', '/normalservice/course/selectCourse', {
    micToken,
    withParams: false,
    body: {},
  });
  save('courses', courses.json);

  // 5. 通知
  const notices = await call('POST', '/ump/message/listMessageToRead', { body: { pageNum: 1, pageSize: 10 } });
  save('notices', notices.json);

  save('summary', {
    hasToken: true,
    hasMicToken: true,
    currentWeek: week.json,
    today: today.json?.content,
  });
  console.log('\n完成，见 capture/responses/');
})();
