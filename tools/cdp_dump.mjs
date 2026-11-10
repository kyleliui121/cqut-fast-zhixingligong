// 打开页面，导出 script 列表、localStorage、cookie
import { spawn } from 'node:child_process';
import { mkdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const url = process.argv[2];
const edge = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';
const port = 9336;
const profile = join(tmpdir(), 'edge-dump-' + Date.now());
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
ws.onmessage = (ev) => {
  const m = JSON.parse(ev.data);
  if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); }
};
const send = (method, params = {}) => {
  const mid = ++id;
  ws.send(JSON.stringify({ id: mid, method, params }));
  return new Promise((res) => pending.set(mid, res));
};
const evalJs = async (expr) => {
  const r = await send('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true });
  return r.result?.result?.value;
};

await send('Page.enable');
await send('Runtime.enable');
await send('Emulation.setUserAgentOverride', { userAgent: MOBILE_UA, platform: 'Android' });
await send('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 2, mobile: true });
await send('Page.navigate', { url });
await sleep(6000);
await send('Page.reload', { ignoreCache: true });
await sleep(8000);

const out = await evalJs(`JSON.stringify({
  href: location.href,
  scripts: performance.getEntriesByType('resource').map(e => e.name).filter(n => /\\.js(\\?|$)/.test(n)).slice(0, 60),
  ls: Object.keys(localStorage).reduce((a,k)=>{a[k]=String(localStorage.getItem(k)).slice(0,200);return a;},{}),
  ss: Object.keys(sessionStorage).reduce((a,k)=>{a[k]=String(sessionStorage.getItem(k)).slice(0,200);return a;},{}),
  cookie: document.cookie,
  html: document.documentElement.outerHTML.length
})`);
console.log(out);

ws.close();
child.kill();
await sleep(300);
try { rmSync(profile, { recursive: true, force: true }); } catch {}
