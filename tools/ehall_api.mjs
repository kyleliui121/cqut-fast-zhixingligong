// ehall light-app API client.
// sign = MD5(path + "?" + sorted(k=v&) + "appSecret=undefined").toUpperCase()
// usage: node tools/ehall_api.mjs capture/ehall-token.json
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { createHash } from 'node:crypto';

const cfgPath = process.argv[2] ?? 'capture/ehall-token.json';
const cfg = JSON.parse(readFileSync(cfgPath, 'utf8'));
const UA =
  'Mozilla/5.0 (Linux; Android 13; Pixel 6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36';
const HOST = 'https://ehall.cqut.edu.cn';
const APP_KEY = '9b5e431b1a154e20a93357c9c0b732e4';
const UNIVERSITY_ID = '100005';
const APP_SECRET = 'undefined';

mkdirSync('capture/responses', { recursive: true });

const ck = new Map();
for (const part of String(cfg.ck ?? '').split(';')) {
  const s = part.trim();
  const i = s.indexOf('=');
  if (i > 0) ck.set(s.slice(0, i), s.slice(i + 1));
}
const cookieHeader = [...ck].map(([k, v]) => `${k}=${v}`).join('; ');
const officeToken = ck.get('_yh_office_token');
if (!officeToken) throw new Error('snapshot missing _yh_office_token');

const md5 = (s) => createHash('md5').update(s, 'utf8').digest('hex').toUpperCase();

function sign(path, params) {
  const keys = Object.keys(params).sort();
  let s = path + '?';
  for (const k of keys) {
    const v = params[k];
    s += k + '=' + (v !== null && typeof v === 'object' ? JSON.stringify(v) : v) + '&';
  }
  s += 'appSecret=' + APP_SECRET;
  return md5(s);
}

let operatorId = null;
let micToken = null;

function baseParams(extra = {}) {
  return {
    operatorId: operatorId ?? '0',
    universityId: UNIVERSITY_ID,
    appKey: APP_KEY,
    timestamp: String(Date.now()),
    nonce: String(Math.floor(Math.random() * 1e14)).padStart(14, '0'),
    clientCategory: 'PC',
    ...extra,
  };
}

async function call(method, path, extra = {}, { withOfficeToken = false } = {}) {
  const params = baseParams(extra);
  params.sign = sign(path, params);
  const qs = new URLSearchParams(params).toString();
  const headers = {
    'User-Agent': UA,
    Accept: 'application/json, text/plain, */*',
    Referer: HOST + '/lightapp/pcapp.html',
    Cookie: cookieHeader,
  };
  if (withOfficeToken) headers.token = officeToken;
  if (micToken) headers.micToken = micToken;
  const url = `${HOST}${path}${method === 'GET' ? '?' + qs : ''}`;
  const opts = { method, headers, signal: AbortSignal.timeout(20000) };
  if (method !== 'GET') {
    headers['Content-Type'] = 'application/x-www-form-urlencoded';
    opts.body = qs;
  }
  const r = await fetch(url, opts);
  const text = await r.text();
  let json = null;
  try {
    json = JSON.parse(text);
  } catch {}
  console.log(`${method} ${path} -> ${json?.code ?? r.status} ${String(json?.message ?? text).slice(0, 60)}`);
  return { status: r.status, text, json };
}

const save = (name, v) => writeFileSync(`capture/responses/${name}.json`, JSON.stringify(v, null, 2));

async function getTicket() {
  const params = {
    'uap-web-key': 'uap-web-key',
    timestamp: String(Date.now()),
    nonce: String(Math.floor(Math.random() * 1e10)),
    clientCategory: 'PC',
    appVersion: '1.0.0',
  };
  const r = await fetch(
    `${HOST}/ump/officeHall/getApplicationUrl?applicationCode=UIVx60&` + new URLSearchParams(params),
    { headers: { 'User-Agent': UA, Accept: 'application/json', Cookie: cookieHeader, token: officeToken } },
  );
  const j = await r.json();
  return j?.content?.ticket;
}

const ticket = await getTicket();
if (!ticket) throw new Error('no ticket');
console.log('ticket:', ticket);

const info = await call('GET', `/normalservice/auth/userInfo/${encodeURIComponent(ticket)}`);
save('user-info', info.json);
operatorId = String(info.json?.content?.operatorId ?? info.json?.content?.staffCode ?? '');
micToken = info.json?.content?.token ?? null;
console.log('operatorId:', operatorId, 'name:', info.json?.content?.userName, 'micToken:', micToken ? 'ok' : 'missing');

const years = await call('GET', '/normalservice/course/getCourseYearAndTerm', {
  mybatisSqlId: 'listYearAndTerm',
  params: JSON.stringify({ XGH: operatorId }),
  pageNum: 0,
  pageSize: 0,
});
save('year-term', years.json);

const week = await call('POST', '/normalservice/course/getCurrentWeek', {
  schoolYear: '2026-2027',
  term: '1',
});
save('current-week', week.json);

const courses = await call('GET', '/normalservice/course/selectCourse', {
  schoolYear: '2026-2027',
  term: '1',
  week: '11',
  isWeek: 'YES',
  userType: 'STUDENT',
});
save('courses', courses.json);
const content = courses.json?.content;
console.log('courses:', Array.isArray(content) ? content.length : typeof content);

const grades = await call('GET', '/normalservice/normalSql/listdata', {
  pageNum: 1,
  pageSize: 100,
  mybatisSqlId: 'listScoreByXnxq',
  params: JSON.stringify({ XH: operatorId, XNXQ: '2026-2027-1' }),
});
save('grades', grades.json);
console.log('grades:', grades.json?.content?.total);
