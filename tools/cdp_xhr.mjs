// 娉ㄥ叆 cookie 鎵撳紑椤甸潰锛岃褰曟墍鏈?XHR 鐨?URL 涓庤姹備綋
// 鐢ㄦ硶: node tools/cdp_xhr.mjs <url> <cookies-json-file>
import { spawn } from 'node:child_process';
import { mkdirSync, rmSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const url = process.argv[2];
const cookieFile = process.argv[3];
const edge = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';
const port = 9339;
const profile = join(tmpdir(), 'edge-xhr-' + Date.now());
mkdirSync(profile, { recursive: true });

const cfg = JSON.parse(readFileSync(cookieFile, 'utf8'));
const cookies = String(cfg.ck ?? '')
  .split(';')
  .map((s) => s.trim())
  .filter(Boolean)
  .map((s) => {
    const i = s.indexOf('=');
    return { name: s.slice(0, i).trim(), value: s.slice(i + 1).trim() };
  })
  .filter((c) => c.name && c.value);

const MOBILE_UA =
  'Mozilla/5.0 (Linux; Android 13; Pixel 6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36';

const child = spawn(edge, [
  `--remote-debugging-port=${port}`,
  `--user-data-dir=${profile}`,
  '--headless=new',
  '--disable-gpu',
  '--no-first-run',
  '--window-size=390,900',
  'about:blank',
], { stdio: 'ignore' });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function wsUrl() {
  for (let i = 0; i < 40; i++) {
    try {
      const r = await fetch(`http://127.0.0.1:${port}/json/list`);
      const l = await r.json();
      const p = l.find((t) => t.type === 'page');
      if (p?.webSocketDebuggerUrl) return p.webSocketDebuggerUrl;
    } catch {}
    await sleep(250);
  }
  throw new Error('devtools not ready');
}

const ws = new WebSocket(await wsUrl());
await new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej; });
let id = 0;
const pending = new Map();
const xhrs = [];
ws.onmessage = (ev) => {
  const m = JSON.parse(ev.data);
  if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); return; }
  if (m.method === 'Network.requestWillBeSent') {
    const { request, type } = m.params;
    if (type === 'XHR' || type === 'Fetch') {
      xhrs.push({ url: request.url, method: request.method, postData: request.postData ?? null });
    }
  }
};
const send = (method, params = {}) => {
  const mid = ++id;
  ws.send(JSON.stringify({ id: mid, method, params }));
  return new Promise((res) => pending.set(mid, res));
};

await send('Page.enable');
await send('Network.enable');
await send('Emulation.setUserAgentOverride', { userAgent: MOBILE_UA, platform: 'Android' });
for (const c of cookies) {
  for (const domain of ['.cqut.edu.cn', 'ehall.cqut.edu.cn', 'app-yh.cqut.edu.cn']) {
    await send('Network.setCookie', { name: c.name, value: c.value, domain, path: '/' });
  }
}
await send('Page.navigate', { url });
await sleep(25000);

const uniq = [];
const seen = new Set();
for (const x of xhrs) {
  const base = x.url.split('?')[0];
  const m = x.url.match(/mybatisSqlId=([^&]+)/);
  const key = x.method + ' ' + base + (m ? ' ' + m[1] : '') + (x.postData ?? '');
  if (seen.has(key)) continue;
  seen.add(key);
  uniq.push(x);
}
for (const x of uniq) {
  console.log(`${x.method} ${x.url}`);
  if (x.postData) console.log('   BODY: ' + x.postData.slice(0, 500));
}
writeFileSync('capture/responses/xhr-dump.json', JSON.stringify(uniq, null, 2));

ws.close();
child.kill();
await sleep(300);
try { rmSync(profile, { recursive: true, force: true }); } catch {}

