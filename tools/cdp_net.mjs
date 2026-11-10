// 记录页面加载过程中所有 Script / XHR 响应，便于静态分析前端接口
import { spawn } from 'node:child_process';
import { mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const url = process.argv[2];
const outFile = process.argv[3];
const edge = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';
const port = 9337;
const profile = join(tmpdir(), 'edge-net-' + Date.now());
mkdirSync(profile, { recursive: true });

const MOBILE_UA =
  'Mozilla/5.0 (Linux; Android 13; Pixel 6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36';

const child = spawn(edge, [
  `--remote-debugging-port=${port}`,
  `--user-data-dir=${profile}`,
  '--headless=new',
  '--disable-gpu',
  '--no-first-run',
  '--window-size=390,844',
  'about:blank',
], { stdio: 'ignore' });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function getWsUrl() {
  for (let i = 0; i < 40; i++) {
    try {
      const r = await fetch(`http://127.0.0.1:${port}/json/list`);
      const list = await r.json();
      const page = list.find((t) => t.type === 'page');
      if (page?.webSocketDebuggerUrl) return page.webSocketDebuggerUrl;
    } catch {}
    await sleep(250);
  }
  throw new Error('devtools not ready');
}

const ws = new WebSocket(await getWsUrl());
await new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej; });
let id = 0;
const pending = new Map();
const seen = [];
ws.onmessage = (ev) => {
  const m = JSON.parse(ev.data);
  if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); return; }
  if (m.method === 'Network.responseReceived') {
    const { response, type } = m.params;
    if (['Script', 'XHR', 'Fetch', 'Document', 'Stylesheet'].includes(type)) {
      seen.push({ type, status: response.status, url: response.url, mime: response.mimeType });
    }
  }
};
const send = (method, params = {}) => {
  const mid = ++id;
  ws.send(JSON.stringify({ id: mid, method, params }));
  return new Promise((res) => pending.set(mid, res));
};

await send('Page.enable');
await send('Runtime.enable');
await send('Network.enable');
await send('Emulation.setUserAgentOverride', { userAgent: MOBILE_UA, platform: 'Android' });
await send('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 2, mobile: true });
await send('Page.navigate', { url });
await sleep(7000);
await send('Page.reload', { ignoreCache: true });
await sleep(9000);

const uniq = [];
const keys = new Set();
for (const s of seen) {
  const k = s.type + ' ' + s.url;
  if (keys.has(k)) continue;
  keys.add(k);
  uniq.push(s);
}
for (const s of uniq) console.log(`${s.status}\t${s.type}\t${s.url}`);
if (outFile) {
  writeFileSync(outFile, JSON.stringify(uniq, null, 2));
  console.log('saved', outFile);
}

ws.close();
child.kill();
await sleep(300);
try { rmSync(profile, { recursive: true, force: true }); } catch {}
