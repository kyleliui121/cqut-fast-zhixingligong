// 注入 cookie 打开页面，抓指定 URL 的响应体
// 用法: node tools/cdp_bodies.mjs <url> <cookies.json> <substr> [outfile]
import { spawn } from 'node:child_process';
import { mkdirSync, rmSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const [url, cookieFile, substr = 'notSensitiveConfig', outFile] = process.argv.slice(2);
const edge = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';
const port = 9341;
const profile = join(tmpdir(), 'edge-body-' + Date.now());
mkdirSync(profile, { recursive: true });

const cfg = JSON.parse(readFileSync(cookieFile, 'utf8'));
const cookies = String(cfg.ck ?? '')
  .split(';')
  .map((s) => s.trim())
  .filter(Boolean)
  .map((s) => {
    const i = s.indexOf('=');
    return { name: s.slice(0, i).trim(), value: s.slice(i + 1).trim() };
  });

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
const wanted = [];
ws.onmessage = (ev) => {
  const m = JSON.parse(ev.data);
  if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); return; }
  if (m.method === 'Network.responseReceived') {
    const { response, requestId, type } = m.params;
    if ((type === 'XHR' || type === 'Fetch') && response.url.includes(substr)) {
      wanted.push({ requestId, url: response.url });
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
await sleep(15000);

for (const w of wanted) {
  const r = await send('Network.getResponseBody', { requestId: w.requestId });
  const body = r.result?.body ?? '';
  console.log('=== ' + w.url.slice(0, 120));
  console.log(body.slice(0, 3000));
  if (outFile) writeFileSync(outFile, body);
}

ws.close();
child.kill();
await sleep(300);
try { rmSync(profile, { recursive: true, force: true }); } catch {}
