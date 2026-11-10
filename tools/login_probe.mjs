// uis 统一认证登录探针：验证 RSA 加密 + 登录 + CAS 跳转链
// 用法: node tools/login_probe.mjs [学号] [密码]
// 不给参数会提示输入。密码只在本地使用，不会写入任何文件。
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { createInterface } from 'node:readline/promises';
import { stdin, stdout } from 'node:process';
import { publicEncrypt, constants } from 'node:crypto';

const UA =
  'Mozilla/5.0 (Linux; Android 13; Pixel 6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36';
const SERVER = 'https://uis.cqut.edu.cn/center-auth-server';
const UNIVERSITY_ID = '100005';
const PUBLIC_KEY = `-----BEGIN PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDACwPDxYycdCiNeblZa9LjvDzb
iZU1vc9gKRcG/pGjZ/DJkI4HmoUE2r/o6SfB5az3s+H5JDzmOMVQ63hD7LZQGR4k
3iYWnCg3UpQZkZEtFtXBXsQHjKVJqCiEtK+gtxz4WnriDjf+e/CxJ7OD03e7sy5N
Y/akVmYNtghKZzz6jwIDAQAB
-----END PUBLIC KEY-----`;

function encryptSecret(plain) {
  const chunks = [];
  for (let i = 0; i < plain.length; i += 30) {
    const part = plain.slice(i, i + 30);
    const buf = publicEncrypt(
      { key: PUBLIC_KEY, padding: constants.RSA_PKCS1_PADDING },
      Buffer.from(part, 'utf8'),
    );
    chunks.push(encodeURI(buf.toString('base64')));
  }
  return encodeURIComponent(JSON.stringify(chunks));
}

const jar = new Map();
function cookieHeader() {
  return [...jar].map(([k, v]) => `${k}=${v}`).join('; ');
}
function absorb(response) {
  const list = response.headers.getSetCookie ? response.headers.getSetCookie() : [];
  for (const sc of list) {
    const [pair] = sc.split(';');
    const i = pair.indexOf('=');
    if (i > 0) jar.set(pair.slice(0, i).trim(), pair.slice(i + 1).trim());
  }
}

async function req(url, opts = {}) {
  const headers = {
    'User-Agent': UA,
    Accept: 'text/html,application/json,*/*',
    'Accept-Language': 'zh-CN,zh;q=0.9',
    ...(opts.headers ?? {}),
  };
  if (jar.size) headers.Cookie = cookieHeader();
  const r = await fetch(url, {
    ...opts,
    headers,
    redirect: 'manual',
    signal: AbortSignal.timeout(20000),
  });
  absorb(r);
  return r;
}

let username = process.argv[2];
let password = process.argv[3];
if (!username || !password) {
  const rl = createInterface({ input: stdin, output: stdout });
  username = username ?? (await rl.question('学号: '));
  password = password ?? (await rl.question('密码（明文显示）: '));
  rl.close();
}

console.log('1) 取登录页 cookie');
const loginUrl =
  `${SERVER}/officeHallApplicationCode/cas/login?` +
  'service=' + encodeURIComponent('https://uis.cqut.edu.cn/ump/common/login/authSourceAuth/auth');
const page = await req(loginUrl);
console.log('   status', page.status, 'cookies', [...jar.keys()].join(',') || '(none)');

console.log('2) POST /sso/doLogin');
const body = JSON.stringify({
  name: username,
  pwd: encryptSecret(password),
  verifyCode: '',
  universityId: UNIVERSITY_ID,
});
const login = await req(`${SERVER}/sso/doLogin`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json;charset=UTF-8', Accept: 'application/json' },
  body,
});
const text = await login.text();
console.log('   status', login.status, text.slice(0, 300));

let parsed = null;
try {
  parsed = JSON.parse(text);
} catch {}

function maskUrl(u) {
  try {
    const url = new URL(u);
    for (const k of [...url.searchParams.keys()]) url.searchParams.set(k, '***');
    return url.toString();
  } catch {
    return u;
  }
}

console.log('3) 重新访问 CAS 登录地址（带 ticket 跳转）');
let cur = loginUrl;
for (let hop = 0; hop < 8; hop++) {
  const r = await req(cur);
  const loc = r.headers.get('location') || '';
  console.log(`   ${hop}: ${r.status} ${maskUrl(cur)}`);
  if (loc) console.log(`      -> ${maskUrl(new URL(loc, cur).toString())}`);
  const setC = r.headers.getSetCookie ? r.headers.getSetCookie() : [];
  for (const c of setC) {
    const name = c.split('=')[0];
    const domain = (c.match(/domain=([^;]+)/i) || [])[1] || '(host-only)';
    console.log(`      set-cookie: ${name}  domain=${domain}`);
  }
  if (r.status >= 300 && r.status < 400 && loc) {
    cur = new URL(loc, cur).toString();
    continue;
  }
  break;
}

mkdirSync('capture', { recursive: true });
writeFileSync(
  'capture/login-result.json',
  JSON.stringify(
    {
      time: new Date().toISOString(),
      loginCode: parsed?.code,
      loginMsg: parsed?.msg ?? parsed?.message,
      cookies: Object.fromEntries(jar),
      finalUrl: cur,
    },
    null,
    2,
  ),
);
console.log('\n结果已写入 capture/login-result.json（不含密码）');
