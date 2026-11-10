// 用 Edge + CDP 打开受瑞数 WAF 保护的页面：伪装 UA、等挑战、必要时 reload，再输出状态/截图。
// 用法: node tools/cdp_probe.mjs <url> [screenshot.png]
import { spawn } from 'node:child_process';
import { mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const url = process.argv[2];
const shot = process.argv[3];
const edge = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';
const port = 9334;
const profile = join(tmpdir(), 'edge-cdp-profile-' + Date.now());
mkdirSync(profile, { recursive: true });

const MOBILE_UA =
  'Mozilla/5.0 (Linux; Android 13; Pixel 6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36';

const child = spawn(edge, [
  `--remote-debugging-port=${port}`,
  `--user-data-dir=${profile}`,
  '--headless=new',
  '--disable-gpu',
  '--no-first-run',
  '--no-default-browser-check',
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
const responses = [];
ws.onmessage = (ev) => {
  const msg = JSON.parse(ev.data);
  if (msg.id && pending.has(msg.id)) {
    pending.get(msg.id)(msg);
    pending.delete(msg.id);
  } else if (msg.method === 'Network.responseReceived') {
    const { response, type } = msg.params;
    if (type === 'Document' || type === 'XHR' || type === 'Fetch') {
      responses.push(`${response.status} ${type} ${response.url.slice(0, 140)}`);
    }
  }
};

function send(method, params = {}) {
  const mid = ++id;
  ws.send(JSON.stringify({ id: mid, method, params }));
  return new Promise((res) => pending.set(mid, res));
}

const evalJs = async (expr) => {
  const r = await send('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true });
  if (r.result?.exceptionDetails) return { error: r.result.exceptionDetails.text };
  return r.result?.result?.value;
};

await send('Page.enable');
await send('Runtime.enable');
await send('Network.enable');
await send('Emulation.setUserAgentOverride', { userAgent: MOBILE_UA, platform: 'Android' });
await send('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 3, mobile: true });
await send('Page.navigate', { url });
await sleep(7000);

const first = await evalJs('JSON.stringify({t:document.title,h:location.href,len:document.documentElement.outerHTML.length})');
console.log('after first load:', first);

// 瑞数通常要求带新 cookie 重新请求一次
await send('Page.reload', { ignoreCache: true });
await sleep(9000);

const info = await evalJs(`JSON.stringify({
  title: document.title,
  href: location.href,
  cookie: document.cookie,
  bodyLen: document.body ? document.body.innerHTML.length : 0,
  text: document.body ? document.body.innerText.slice(0, 600) : ''
})`);
console.log('after reload:', info);
console.log('--- network ---');
responses.forEach((r) => console.log('  ' + r));

if (shot) {
  const r = await send('Page.captureScreenshot', { format: 'png' });
  writeFileSync(shot, Buffer.from(r.result.data, 'base64'));
  console.log('screenshot ->', shot);
}

ws.close();
child.kill();
await sleep(400);
try { rmSync(profile, { recursive: true, force: true }); } catch {}
